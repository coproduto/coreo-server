module CoreoClient exposing (..)
{-| This is the top-level Elm module for a web client interface created for
Brazilian dancer André Aguiar's multimedia choreography <name here>.

For usage details, check main.js.

@docs main 
-}

import CoreoClient.VoteList as VoteList
import CoreoClient.NewWordList as NewWordList

import Phoenix.Socket
import Phoenix.Channel
import Phoenix.Push

import Json.Encode as Json

import Html as H exposing (Html)
import Html.App as App

import Time

--url for the words API
wordsUrl : String
wordsUrl = "http://localhost:4000/api/v1/words/"

newWordsUrl : String
newWordsUrl = "http://localhost:4000/api/v1/new_words/"

socketUrl : String
socketUrl = "ws://localhost:4000/socket/websocket"

{-| main: Start the client.
-}
main : Program Never
main = 
    App.program 
         { init = init
         , view = view
         , update = update
         , subscriptions = subscriptions
         }
      
type alias Model =
    { voteList : VoteList.Model
    , newWordList : NewWordList.Model
    , socket : Phoenix.Socket.Socket Msg
    , socketUrl : String
    , updatesChannel : Phoenix.Channel.Channel Msg
    }

type Msg 
    = VoteMsg VoteList.Msg
    | NewWordMsg NewWordList.Msg
    | WordUpdate Json.Value
    | NewWordUpdate Json.Value
    | FetchLists Json.Value
    | PhoenixMsg (Phoenix.Socket.Msg Msg)
    | RejoinChannel Json.Value
    | Ping

init : (Model, Cmd Msg)
init = 
  let (newVoteList, voteListCmd) = VoteList.init wordsUrl

      (newWordList, wordListCmd) = NewWordList.init newWordsUrl

      initSocket = Phoenix.Socket.init socketUrl
                 |> Phoenix.Socket.withDebug
                 |> Phoenix.Socket.on "update:word" "updates:lobby" WordUpdate
                 |> Phoenix.Socket.on "update:new_word" "updates:lobby" NewWordUpdate
                 |> Phoenix.Socket.on "update:invalidate_all" "updates:lobby" FetchLists

      channel = Phoenix.Channel.init "updates:lobby"
              |> Phoenix.Channel.withPayload (Json.string "")
              |> Phoenix.Channel.onJoin FetchLists
              |> Phoenix.Channel.onClose RejoinChannel

      (socket, phxCmd) = Phoenix.Socket.join channel initSocket

  in ( { voteList = newVoteList
       , newWordList = newWordList
       , socket = socket
       , socketUrl = socketUrl
       , updatesChannel = channel
       }
     , Cmd.batch
         [ Cmd.map VoteMsg voteListCmd
         , Cmd.map NewWordMsg wordListCmd
         , Cmd.map PhoenixMsg phxCmd
         ]
     )


update : Msg -> Model -> (Model, Cmd Msg)
update message model = 
  case message of
    VoteMsg msg ->
      let (newVoteList, voteListCmd) = VoteList.update msg model.voteList
      in ({ model | voteList = newVoteList }, Cmd.map VoteMsg voteListCmd)

    NewWordMsg msg ->
      let (newWordList, wordListCmd) = NewWordList.update msg model.newWordList
      in ({ model | newWordList = newWordList }, Cmd.map NewWordMsg wordListCmd)

    FetchLists _ ->
      let (newVoteList, voteListCmd) = VoteList.update VoteList.FetchList model.voteList
          (newWordList, wordListCmd) = NewWordList.update NewWordList.FetchList model.newWordList
      in 
        ( { model | voteList = newVoteList
                  , newWordList = newWordList 
          }
        , Cmd.batch
            [ Cmd.map VoteMsg voteListCmd
            , Cmd.map NewWordMsg wordListCmd
            ]
        )

    WordUpdate json ->
      let (newVoteList, voteListCmd) = VoteList.update (VoteList.WordUpdate json) model.voteList
      in 
        ( { model | voteList = newVoteList }, Cmd.map VoteMsg voteListCmd )

    NewWordUpdate json ->
      let (newWordList, wordListCmd) = NewWordList.update (NewWordList.NewWordUpdate json) model.newWordList
      in
        ( { model | newWordList = newWordList }, Cmd.map NewWordMsg wordListCmd )

    PhoenixMsg msg ->
      let
        (phxSocket, phxCmd) = Phoenix.Socket.update msg model.socket
      in
        ( { model | socket = phxSocket }
        , Cmd.map PhoenixMsg phxCmd
        )

    RejoinChannel _ ->
      let (socket, phxCmd) = Phoenix.Socket.join model.updatesChannel model.socket
      in ( { model | socket = socket }
         , Cmd.map PhoenixMsg phxCmd
         )

    Ping -> 
      let ping = Phoenix.Push.init "ping" "updates:lobby"
               |> Phoenix.Push.withPayload (Json.string "ping-response")
          (socket, phxCmd) = Phoenix.Socket.push ping model.socket
      in ( { model | socket = socket }
         , Cmd.map PhoenixMsg phxCmd
         )      
    

view : Model -> Html Msg
view model = 
    H.div []
         [ App.map VoteMsg <| VoteList.view model.voteList
         , App.map NewWordMsg <| NewWordList.view model.newWordList
         ]


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
         [ Sub.map VoteMsg <| VoteList.subscriptions model.voteList
         , Sub.map NewWordMsg <| NewWordList.subscriptions model.newWordList
         , Phoenix.Socket.listen model.socket PhoenixMsg
         , Time.every (5 * Time.second) (\_ -> Ping)
         ]
