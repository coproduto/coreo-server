module CoreoClient.VoteList exposing (Model, Msg(FetchList, ResetFetchList, WordUpdate), update, view, init, subscriptions)
{-| Module to generate a list of votes,
consisting of each votable option together
with the number of votes associated with it.

@docs Model

@docs Msg

@docs update

@docs view 

@docs init
-}

import Html as H exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events

import Http
import Task exposing (Task)

import Result exposing (Result)
import Dict exposing (Dict)
import Maybe exposing (Maybe)
import Json.Decode as Decode exposing (Decoder,(:=))
import Json.Encode as Json

import Phoenix.Socket
import Phoenix.Channel
import Phoenix.Push

import Debug

{-| Underlying data for a VoteList-}
type alias Model = 
    { votes : List Votes
    , votedForOption : Maybe Int
    , url : String
{-    , socket : Phoenix.Socket.Socket Msg
    , socketUrl : String-}
    }

{-| Type for messages generated from a voteList.
A message generated by the list always contains a
string identifying which option was voted for. 
-}
type Msg = VoteForOption Int
         | FetchList
         | ResetFetchList
         | UpdateListFail Http.Error
         | UpdateListSucceed (List Votes)
         | UpdateListResetSucceed (List Votes)
         | IncrementFail Http.Error
         | IncrementSucceed Votes
         | DecrementFail Http.Error
         | DecrementSucceed Votes
--         | PhoenixMsg (Phoenix.Socket.Msg Msg)
         | WordUpdate Json.Value
         | NoOp

type alias Votes =
  { id : Int
  , name: String
  , votes: Int 
  }

specialWords : List String
specialWords = 
  [ "Forte"
  , "Leve"
  , "Lento"
  , "Rápido"
  , "Volta"
  , "Pause"
  , "Livre"
  , "Contido"
  ]

wordImages : Dict String String
wordImages = 
  Dict.fromList
    [ ("Forte", "/images/forte.png")
    , ("Leve", "/images/leve.png")
    , ("Rápido", "/images/rapido.png")
    , ("Volta", "/images/volta.png")
    , ("Pausa", "/images/pause.png")
    , ("Fluido", "/images/livre.png")
    , ("Contido", "/images/contido.png")
    , ("Lento", "/images/lento.png")
    ]

{-| Initialize the voteList. It takes a list of strings representing
the possible voting options as a parameter. 
-}
init : String -> (Model, Cmd Msg)
init url {-socketUrl-} = 
  let 
      initModel = 
        { votes = []
        , votedForOption = Nothing
        , url = url
        }

      initCmds =
        Cmd.none
  in
  ( initModel 
  , initCmds
  )

{-| Step the vote list whenever we get a new vote 
-}
update : Msg -> Model -> (Model, Cmd Msg)
update message model =
  case message of
    FetchList ->
      ( model
      , Task.perform UpdateListFail UpdateListSucceed 
              (Http.get decodeVoteList model.url)
      )

    ResetFetchList ->
      ( { model | votedForOption = Nothing }
      , Task.perform UpdateListFail UpdateListResetSucceed 
              (Http.get decodeVoteList model.url)
      )

    VoteForOption id ->
      case model.votedForOption of
        Just voted ->
          if voted == id then
            ( model
            , Task.perform DecrementFail DecrementSucceed 
               (Http.post decodeVoteResponse 
                  (model.url++"decrement/"++(toString id)) Http.empty)
            )
          else
            (model, Cmd.none)

        Nothing ->
          ( model 
          , Task.perform IncrementFail IncrementSucceed
              (Http.post decodeVoteResponse 
                 (model.url++"increment/"++(toString id)) Http.empty)
          )

    UpdateListFail err ->
      (Debug.log ("got err " ++ (toString err)) model
      , Cmd.none
      )

    UpdateListSucceed vList ->
      (Debug.log ("got vList " ++ (toString vList))
       { model | votes = vList 
       }
       , Cmd.none
      )

    UpdateListResetSucceed vList ->
      (Debug.log ("got vList " ++ (toString vList))
       { model | votes = vList
               , votedForOption = Nothing
       }
       , Cmd.none
      )

    IncrementFail err ->
      (Debug.log ("got err " ++ (toString err)) model
      , Cmd.none
      )

    IncrementSucceed vote ->
      ({-Debug.log ("got vote " ++ (toString vote))-}
         { model | votes = dispatchAction increment vote.id model.votes 
         , votedForOption = Just vote.id
         }
       , Cmd.none
      )

    DecrementFail err ->
      (Debug.log ("got err " ++ (toString err)) model
      , Cmd.none
      )

    DecrementSucceed vote ->
      ({-Debug.log ("got vote " ++ (toString vote))-}
         { model | votes = dispatchAction decrement vote.id model.votes 
         , votedForOption = Nothing
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

    WordUpdate json ->
      let data = Decode.decodeValue decodeVote json
      in case data of
           Ok newVote ->
             ( { model | votes = dispatchAction (always newVote.votes) newVote.id model.votes }
             , Cmd.none
             )
           Err err ->
             ( (Debug.log ("got err " ++ err) model)
             , Cmd.none
             )

    NoOp ->
      (model, Cmd.none)


{-| The voteList gets shown as an HTML `ul` element with
the name of the option, the number of votes, and a voting
button. -} 
view : Model -> Html Msg
view model = 
  H.div []
     [ voteList model (List.sortWith listOrder model.votes) ]

subscriptions : Model -> Sub Msg
subscriptions model =
--  Phoenix.Socket.listen model.socket PhoenixMsg
    Sub.none
      
--helper functions
voteList : Model -> List Votes -> Html Msg
voteList model vList =
  let list =
    List.map (listElem model) vList
  in H.ul 
       [ Attr.class "list-group row vote-list" ] 
       list

listElem : Model -> Votes -> Html Msg
listElem model vote =
  let hasVotedForThis = case model.votedForOption of
                          Just id ->
                            (id == vote.id)
                          Nothing ->
                            False

      hasVoted = case model.votedForOption of
                   Just _  -> True
                   Nothing -> False

      wordImg = Maybe.withDefault "" <| Dict.get vote.name wordImages

  in if not <| vote.name `List.member` specialWords
    then
       H.li 
          [ Attr.class "list-group-item clearfix vote-item col-xs-6 col-sm-4" ]
            [ H.text vote.name
            , H.span 
                [ Attr.class "pull-right" ]
                [ H.button
                    [ (if hasVotedForThis then
                         Attr.class "btn btn-primary voted"
                       else 
                         if (not hasVoted) then
                           Attr.class "btn btn-primary"
                         else
                           Attr.class "btn btn-primary disabled"
                      )
                    , Attr.type' "button"
                    , Events.onClick (VoteForOption vote.id) 
                    ]
                    (if hasVotedForThis then
                       [ H.text "Desfazer voto" ]
                     else
                       [ H.text "Vote" ]
                    )
                ]
            ]
    else
      H.li
         [ Attr.class "list-group-item vote-item col-xs-6 col-sm-4" ]
         [ H.button 
             [ (if hasVotedForThis then
                  Attr.class "btn btn-primary-outline voted"
                else 
                  if (not hasVoted) then
                    Attr.class "btn btn-primary-outline"
                  else
                    Attr.class "btn btn-primary-outline disabled"
               )
             , Attr.type' "button"
             , Events.onClick (VoteForOption vote.id) 
             ]
             [ H.img 
                 [ Attr.src wordImg
                 , Attr.alt vote.name
                 , Attr.class "img-responsive"
                 ] []
             ]
         ]


dispatchAction : (Int -> Int) -> Int -> List Votes -> List Votes
dispatchAction action target list =
  case list of
    (vote :: rest) ->
      if vote.id == target then { vote | votes = action (vote.votes) } :: rest
      else vote :: (dispatchAction action target rest)

    [] -> []

increment x = x + 1

decrement x = x - 1
--

listOrder : Votes -> Votes -> Order
listOrder a b =
  if a.name `List.member` specialWords then
    if b.name `List.member` specialWords then
      compare a.name b.name
    else
      GT
  else
    if b.name `List.member` specialWords then
      LT
    else
      compare a.name b.name


--decoders for JSON data

decodeVoteList : Decoder (List Votes)
decodeVoteList = 
  let vList = decodeVote |> Decode.list
  in ("data" := vList)

decodeVote : Decoder Votes
decodeVote =
 Decode.object3 Votes 
   ("id"    := Decode.int)
   ("name"  := Decode.string) 
   ("votes" := Decode.int) 
         
decodeVoteResponse : Decoder Votes
decodeVoteResponse =
  ("data" := decodeVote)
