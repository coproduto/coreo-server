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
import Html.Attributes as Attr
import Html.App as App

import Time

--url for the words API
wordsUrl : String
wordsUrl = "https://salty-sierra-37096.herokuapp.com/api/v1/words/"

newWordsUrl : String
newWordsUrl = "https://salty-sierra-37096.herokuapp.com/api/v1/new_words/"

socketUrl : String
socketUrl = "wss://salty-sierra-37096.herokuapp.com/socket/websocket"

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
    , videoUrl : Maybe String
    }

type Msg 
    = VoteMsg VoteList.Msg
    | NewWordMsg NewWordList.Msg
    | WordUpdate Json.Value
    | NewWordUpdate Json.Value
    | FetchLists Json.Value
    | FetchNewWords Json.Value
    | ResetFetchNewWords Json.Value
    | FetchWords Json.Value
    | ResetFetchWords Json.Value
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
                 |> Phoenix.Socket.on "update:invalidate_words" "updates:lobby" FetchWords
                 |> Phoenix.Socket.on "update:invalidate_words_votes" "updates:lobby" ResetFetchWords
                 |> Phoenix.Socket.on "update:invalidate_new_words" "updates:lobby" FetchNewWords
                 |> Phoenix.Socket.on "update:invalidate_new_words_votes" "updates:lobby" ResetFetchNewWords

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
       , videoUrl = Nothing
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

    FetchNewWords _ ->
      let (newWordList, wordListCmd) = NewWordList.update NewWordList.FetchList model.newWordList
      in 
        ( { model | newWordList = newWordList 
          }
        , Cmd.batch
            [ Cmd.map NewWordMsg wordListCmd
            ]
        )

    FetchWords _ ->
      let (newVoteList, voteListCmd) = VoteList.update VoteList.FetchList model.voteList
      in 
        ( { model | voteList = newVoteList
          }
        , Cmd.batch
            [ Cmd.map VoteMsg voteListCmd
            ]
        )

    ResetFetchNewWords _ ->
      let (newWordList, wordListCmd) = NewWordList.update NewWordList.ResetFetchList model.newWordList
      in 
        ( { model | newWordList = newWordList 
          }
        , Cmd.batch
            [ Cmd.map NewWordMsg wordListCmd
            ]
        )

    ResetFetchWords _ ->
      let (newVoteList, voteListCmd) = VoteList.update VoteList.ResetFetchList model.voteList
      in 
        ( { model | voteList = newVoteList 
          }
        , Cmd.batch
            [ Cmd.map VoteMsg voteListCmd
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
         [ case model.videoUrl of
             Just url ->
               videoFrame url
             Nothing ->
               placeholderView 
         , App.map VoteMsg <| VoteList.view model.voteList
         , H.hr [] []
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

videoFrame : String -> Html Msg
videoFrame src =
  H.div
    [ Attr.class "embed-responsive embed-responsive-16by9" ]
    [ H.iframe
        [ Attr.class "embed-responsive-item"
        , Attr.src ("http://youtube-nocookie.com/embed/"++src)
        ] 
        []
    ]

placeholderView : Html Msg
placeholderView =
  H.div 
    [ Attr.class "row" ]
    [ H.div
        [ Attr.class "col-sm-12 col-sm-offset-0 col-xs-10 col-xs-offset-1" ]
        [ H.img
            [ Attr.src "/images/placeholder.png" 
            , Attr.alt "Ämämä Mämäm"
            , Attr.class "img-responsive center-block"
            ] 
            []
        ]
    ]
