module CoreoClient.NewWordList exposing (Model, Msg(FetchList, NewWordUpdate), update, view, init, subscriptions)
{-| Module allowing users to vote for a new word to be added 
to the voting list. Functions quite similarly to the voting
list itself.

@docs Model

@docs Msg

@docs update

n@docs view

@docs init 
-} 

import Html as H exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events

import Http
import Task exposing (Task)

import Result exposing (Result)
import Json.Decode as Decode exposing (Decoder,(:=))
import Json.Encode as Json

import Phoenix.Socket
import Phoenix.Channel
import Phoenix.Push

import Debug

{- TODO: Connect to server -}

{-| Underlying data for the NewWordList-} 
type alias Model = 
  { votes : List NewWordVotes
  , fieldContent : String 
  , url : String
{-  , socket : Phoenix.Socket.Socket Msg
  , socketUrl : String-}
  }

{-| Type for messages generated from a voteList.
A message can either represent a vote for a given option
or it can represent the creation of a new option.
-}
type Msg 
  = VoteForOption Int
  | FetchList
  | CreateOption String
  | NewContent String
  | UpdateListFail Http.Error
  | UpdateListSucceed (List NewWordVotes)
  | DecrementFail Http.Error
  | DecrementSucceed NewWordVotes
  | IncrementFail Http.Error
  | IncrementSucceed NewWordVotes
--  | PhoenixMsg (Phoenix.Socket.Msg Msg)
  | NewWordUpdate Json.Value
  | NoOp

type alias NewWordVotes =
  { id : Int
  , name : String
  , votes : Int
  , voted : Bool
  }

type alias IncompleteVotes =
  { id : Int
  , name : String
  , votes : Int
  }

{-| The newWordList is always initialized as empty.
-}
init : String -> (Model, Cmd Msg)
init url {-socketUrl-} = 
  let
{-    initSocket = Phoenix.Socket.init socketUrl
      |> Phoenix.Socket.withDebug
      |> Phoenix.Socket.on "update:new_word" "updates:lobby" NewWordUpdate-}

    initModel =
      { votes = []
      , fieldContent = ""
      , url = url
{-      , socket = socket
      , socketUrl = socketUrl-}
      }

    initCmds = 
      Cmd.none
  in
  ( initModel
  , initCmds -- 
  )

{-| We step the list whenever we get a new vote or a new option is created.
-}
update : Msg -> Model -> (Model, Cmd Msg)
update message model =
  case message of
    FetchList ->
      ( model
      , Task.perform UpdateListFail UpdateListSucceed 
          (Http.get (decodeNewWordList []) model.url)
      )

    VoteForOption id ->
      let vote = getTarget id model.votes
      in case vote of
           Just v ->
             if v.voted then
               ( model
               , Task.perform DecrementFail DecrementSucceed
                   (Http.post (decodeNewWordResponse model.votes)
                      (model.url++"decrement/"++(toString id)) Http.empty)
               )
             else
               ( model
               , Task.perform IncrementFail IncrementSucceed
                   (Http.post (decodeNewWordResponse model.votes)
                      (model.url++"increment/"++(toString id)) Http.empty)
               )

           Nothing ->
             (model, Cmd.none)

    CreateOption str ->
      let options = List.map .name model.votes
      in if str `List.member` options then
           ( model
           , Cmd.none)
         else 
           ({ model | votes = (NewWordVotes 99 str 1 True)  :: model.votes 
                    , fieldContent = ""
            }, Cmd.none)

    NewContent str ->
      ({ model | fieldContent = str }, Cmd.none)

    UpdateListFail err ->
      (Debug.log ("got err " ++ (toString err)) model
      , Cmd.none
      )

    UpdateListSucceed nwList ->
      (Debug.log ("got nwList " ++ (toString nwList))
       { model | votes = nwList
       }
       , Cmd.none
      )


    IncrementFail err ->
      (Debug.log ("got err " ++ (toString err)) model
      , Cmd.none
      )

    IncrementSucceed vote ->
      (Debug.log ("got vote " ++ (toString vote))
         { model | votes = dispatchAction toggleAndModify vote.id model.votes 
         }
       , Cmd.none
      )

    DecrementFail err ->
      (Debug.log ("got err " ++ (toString err)) model
      , Cmd.none
      )

    DecrementSucceed vote ->
      (Debug.log ("got vote " ++ (toString vote))
         { model | votes = dispatchAction toggleAndModify vote.id model.votes 
         }
       , Cmd.none
      )

{-    PhoenixMsg msg ->
      let
        (phxSocket, phxCmd) = Phoenix.Socket.update msg model.socket
      in
        ( { model | socket = phxSocket }
        , Cmd.map PhoenixMsg phxCmd
        )-}

    NewWordUpdate json ->
      let data = Decode.decodeValue decodeIncompleteVote json
      in case data of
           Ok incVote ->
             ( { model | votes = dispatchAction 
                                   (always <| completeSingleVote model.votes incVote)
                                   incVote.id
                                   model.votes
               }
             , Cmd.none
             )
                   
           Err err ->
             ( (Debug.log("got err " ++ err) model)
             , Cmd.none
             )

    NoOp ->
      (model, Cmd.none)

{-| Show the NewWordList -}
view : Model -> Html Msg
view model =
  H.div []
   [ voteList model.votes 
   , H.input 
       [ Attr.placeholder "Crie uma opção"
       , Events.onInput NewContent
       , Attr.value model.fieldContent
       ] []
   , H.button 
      [ Attr.type' "button"
      , Events.onClick (CreateOption model.fieldContent) 
      ]
      [ H.text "Confirmar opção" ]
   ]

subscriptions : Model -> Sub Msg
subscriptions _ =
  Sub.none

--helper functions
dispatchAction : (NewWordVotes -> NewWordVotes) -> Int -> List NewWordVotes -> List NewWordVotes
dispatchAction action target list =
  case list of
    (vote :: rest) ->
      if vote.id == target then 
        (action vote) :: rest

      else vote :: (dispatchAction action target rest)

    [] -> []

getTarget : Int -> List NewWordVotes -> Maybe NewWordVotes
getTarget target list =
  case list of
    (vote :: rest) ->
      if vote.id == target then Just vote
      else getTarget target rest

    [] -> Nothing

toggleAndModify : NewWordVotes -> NewWordVotes
toggleAndModify vote =
  if vote.voted then { vote | votes = vote.votes+1 
                            , voted = not vote.voted 
                     }

  else { vote | votes = vote.votes-1
              , voted = not vote.voted
       }


voteList : List NewWordVotes -> Html Msg
voteList nvList =
  H.ul [] (List.map listElem nvList)

listElem : NewWordVotes -> Html Msg
listElem vote =
  let voteText = if vote.voted then "+1"
                 else "0"
  in 
    H.li []
       [ H.text (vote.name ++ ":" ++ voteText)
       , H.button
          [ Events.onClick (VoteForOption vote.id) ]
          [ H.text "Vote" ]
       ]

--decoders for JSON data
hasVoted : List NewWordVotes -> Int -> Bool
hasVoted list id =
  case getTarget id list of
    Just v -> v.voted
    Nothing -> False

completeNewList : List NewWordVotes -> List IncompleteVotes -> List NewWordVotes
completeNewList oldList newList =
  let voteList = List.map (.id >> (hasVoted oldList)) newList
      pairList = List.map2 (,) newList voteList
  in List.map (\ (elem, voted) -> 
                 { id = elem.id
                 , name = elem.name
                 , votes = elem.votes
                 , voted = voted
                 })
              pairList

completeSingleVote : List NewWordVotes -> IncompleteVotes -> NewWordVotes
completeSingleVote oldList incomplete =
  NewWordVotes incomplete.id incomplete.name incomplete.votes 
                 <| hasVoted oldList incomplete.id

decodeIncompleteVoteList : Decoder (List IncompleteVotes)
decodeIncompleteVoteList = 
  let nwList = decodeIncompleteVote |> Decode.list
  in ("data" := nwList)

decodeIncompleteVote : Decoder IncompleteVotes
decodeIncompleteVote =
  Decode.object3 IncompleteVotes
    ("id"    := Decode.int)
    ("name"  := Decode.string)
    ("votes" := Decode.int)

decodeNewWordList : List NewWordVotes -> Decoder (List NewWordVotes)
decodeNewWordList oldList =
  Decode.object1 (completeNewList oldList) decodeIncompleteVoteList

decodeNewWordResponse : List NewWordVotes -> Decoder NewWordVotes
decodeNewWordResponse oldList =
  Decode.object1 (completeSingleVote oldList) ("data" := decodeIncompleteVote)
