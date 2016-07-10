module CoreoClient.NewWordList exposing (Model, Msg(FetchList, ResetFetchList, NewWordUpdate), update, view, init, subscriptions)
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

import String
import Result exposing (Result)
import Json.Decode as Decode exposing (Decoder,(:=))
import Json.Encode as Json

import Phoenix.Socket
import Phoenix.Channel
import Phoenix.Push

import Debug

strMax : Int
strMax = 30

{-| Underlying data for the NewWordList-} 
type alias Model = 
  { votes : List NewWordVotes
  , fieldContent : String 
  , url : String
--, visible : Bool
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
  | ResetFetchList
  | CreateOption String
  | CreateOptionFail Http.Error
  | CreateOptionSucceed NewWordVotes
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
--    , visible = False
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
          (Http.get (decodeNewWordList model.votes) model.url)
      )

    ResetFetchList ->
      ( { model | votes = List.map (\x -> { x | voted = False }) model.votes }
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

          payload = Json.encode 1
                     <| Json.object
                          [ ("new_word"
                            , Json.object
                                 [ ("name",  (Json.string str))
                                 , ("votes", (Json.int 0))
                                 ]
                            )
                          ]
      in if (str `List.member` options) || ((String.length str) == 0) then
           ( model
           , Cmd.none)
         else 
           let httpRequest = Http.send Http.defaultSettings
                             { verb = "POST"
                             , headers = [("Accept", "application/json")
                                         ,("Content-Type", "application/json")
                                         ]
                             , url = model.url
                             , body = Http.string payload
                             }

           in 
             ( model
             , Task.perform CreateOptionFail CreateOptionSucceed 
                 (Http.fromJson (decodeNewWordResponse []) httpRequest)
             )
                                  

    CreateOptionFail err ->
      (Debug.log ("got err " ++ (toString err)) model
      , Cmd.none
      )

    CreateOptionSucceed newOption ->
      ({ model | votes = newOption :: model.votes
               , fieldContent = ""
       }
      , Cmd.none
      )

    NewContent str ->
      if String.length str <= strMax then
        ({ model | fieldContent = str }, Cmd.none)
      else
        ( model, Cmd.none )

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
   [ H.div 
       [ Attr.class "center-block" ]
       [ H.form
           [ Attr.class "form-inline" ]
           [ H.div 
               [ Attr.class "form-group" ]
               [ H.input 
                   [ Attr.placeholder "Crie uma opção"
                   , Events.onInput NewContent
                   , Attr.value model.fieldContent
                   ] []
               , H.button 
                   [ Attr.type' "button"
                   , Attr.class "btn btn-secondary"
                   , Events.onClick (CreateOption model.fieldContent) 
                   ]
                   [ H.text "Confirmar opção" ]
               ]
           ]
       ]
   , voteList model.votes 
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
  let list = List.map listElem nvList
  in H.ul 
       [ Attr.class "list-group row vote-list" ]
       list

listElem : NewWordVotes -> Html Msg
listElem vote =
  let voteText = if vote.voted then "+1"
                 else "0"
  in 
    H.li 
       [ Attr.class "list-group-item clearfix vote-item col-xs-6" ]
       [ H.text (vote.name ++ ":" ++ voteText)
       , H.span
          [ Attr.class "pull-right" ]
          [ H.button
              [ Attr.class "btn btn-primary"
              , Attr.type' "button"
              , Events.onClick (VoteForOption vote.id) 
              ]
              (if vote.voted then
                 [ H.text "Desfazer voto" ]
               else
                 [ H.text "Vote" ]
              )
          ]
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
