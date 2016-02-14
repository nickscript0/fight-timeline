module Timeline where
-- given a JSON input of events, show a simple visual timeline of text events

-- import Signal.Address
import Signal exposing (Address)

import Http
import Json.Decode as Json exposing ((:=))
import Task exposing (..)
import Effects exposing(..)
import Time
import Date


import Html exposing (div, text, h1, input, button, form, fieldset, address, a)
import Html.Attributes exposing (class, id, type', placeholder, href, style, autofocus)
import Html.Events exposing (onClick, on, targetValue)
import Html.Lazy exposing (lazy, lazy2)

import StartApp
import TaskTutorial

import Model exposing (FightResult, FightCard, Event, Events, Timeline, Model)
import SearchEvents exposing (filterWithResult, SearchResult(..), EventSearchResult)
import Moment

-- *** main ***
app : { html : Signal Html.Html, model : Signal Model, tasks : Signal (Task Never ()) }
app =
  StartApp.start
    { init = init
    , update = update
    , view = view
    , inputs = []
    }

main : Signal Html.Html
main =
  app.html

-- This port is needed as part of the StartApp pattern
port tasks : Signal (Task.Task Never ())
port tasks =
  app.tasks


-- *** Model ***
-- See model.elm
init : (Model, Effects Action)
init =
  ( msgModel "Loading..."
  , Effects.batch [ getTimelineJson "data/all_events.json"
                  , getTime
                  ]
  )

-- Repurpose the model as a message to the user (TODO: do this properly by having view code to display messages)
msgModel : String -> Model
msgModel msg =
  Model (Timeline "Message" [Event Nothing msg "" Nothing "" Nothing]) "" Nothing

-- *** View ***
view : Address Action -> Model -> Html.Html
view address model =
  model.timeline.events
    |> List.map (filterWithResult model.search_value)
    |> List.filter (\x -> x.result /= NotFound)
    |> view_content address model

view_content : Address Action -> Model -> List EventSearchResult -> Html.Html
view_content address model search_results =
  div [ class "content" ]
      [ h1 [] [text model.timeline.title]
      , view_today_date model.current_time
      , lazy2 view_inputSearch address (List.length search_results)
      , lazy2 view_timeline search_results model.current_time
      ]

view_today_date : Maybe Time.Time -> Html.Html
view_today_date maybe_time =
  case maybe_time of
    Just time ->
      let t = Date.fromTime time
      in
          div []
              [ "Raw time: " ++ toString (Time.inSeconds time) ++ " - " ++
                "Date: " ++ toString (Date.year t) ++
                "-" ++ Moment.monthNum (Date.month t) ++
                "-" ++ toString (Date.day t) ++
                " " ++ toString (Date.hour t) ++
                ":" ++ toString (Date.minute t) ++
                ":" ++ toString (Date.second t)
                  |> text
              ]
    Nothing ->
      text ""

view_timeline : List EventSearchResult -> Maybe Time.Time -> Html.Html
view_timeline search_results current_time =
  div [ class "vert-line" ]
      ( List.map (view_event current_time) search_results)

view_event : Maybe Time.Time -> EventSearchResult -> Html.Html
view_event current_time esr =
  div [ ]
      [ div [ class "horizontal-timeline" ]
            [ text esr.event.date
            , div_rel_time_tag esr.event.time_type current_time
            , div_future_tag esr.event.time_type current_time
            ]
      , div
          [ class "event-block" ]
          [ if esr.event.url /= "" then view_link esr.event else text esr.event.text
          , div_event_result esr.result
          ]
      ]

div_rel_time_tag : Maybe Time.Time -> Maybe Time.Time -> Html.Html
div_rel_time_tag event_t now_t =
  div [ ("label "
        ++ (if (Moment.isBefore event_t now_t)
            then "label-default"
            else "label-warning")
        ++ " tag-inline")
          |> class
      ]
      [ Moment.diffTime event_t now_t |> text ]

div_future_tag : Maybe Time.Time -> Maybe Time.Time -> Html.Html
div_future_tag event_date current_time =
  if Moment.isBefore current_time event_date
  then div [ class "label label-info tag-inline" ] [text "Future"]
  else div [] []

div_event_result : SearchResult -> Html.Html
div_event_result result =
  case result of
    FightMatch result is_winner ->
      div [ class "fight-result" ]
          [ div_win_loss is_winner
          , div_vs result
          ]
    TextMatch -> div [] []
    NotFound -> div [] []

div_vs : FightResult -> Html.Html
div_vs result =
  div [class "win-loss-value"]
      [ div [class "bold"] [text result.winner]
      , text " defeated "
      , div [class "bold"] [text result.loser]
      , text " by "
      , div [class "inline"] [text result.result]
      ]

div_win_loss : Bool -> Html.Html
div_win_loss is_winner =
  div [class ("win-loss-label label " ++ (if is_winner then "label-success" else "label-danger")) ]
      [text (if is_winner then "Win" else "Loss")]

view_link : Event -> Html.Html
view_link event =
  a [ href event.url ]
    [ text event.text ]

view_inputSearch : Address Action -> Int -> Html.Html
view_inputSearch address result_count =
  div [ class "search-box" ]
      [
        div [ class "result-count" ]
            [ ("Search (" ++ toString result_count ++ " matches)") |> text  ]
      , input
        [ class "search-input"
        , type' "search"
        , placeholder ""
        , autofocus True
        , on "input" targetValue (Signal.message address << SearchInput)
        ]
        []
      ]

-- *** Update ***
type Action = NoOp
            | NewTimeline (Result Http.Error Timeline)
            | SearchInput String
            | CurrentTime Time.Time

update : Action -> Model -> (Model, Effects Action)
update action model =
  case action of
    NoOp ->
      ( msgModel "NoOp"
      , Effects.none
      )
    NewTimeline resultTimeline ->
      case resultTimeline of
        Ok timeline ->
          ( { model | timeline = timeline }
          , Effects.none
          )
        Err error ->
          ( msgModel (toString error)
          , Effects.none
          )
    SearchInput search ->
      ( { model | search_value = search }
      , Effects.none
      )
    CurrentTime time ->
      ( { model | current_time = (Just time) }
      , Effects.none
      )


-- *** Effects ***
getTime : Effects Action
getTime =
  TaskTutorial.getCurrentTime
    |> Task.map CurrentTime
    |> Effects.task

getTimelineJson : String -> Effects Action
getTimelineJson query =
    Http.get jsonModel (query)
      |> Task.toResult
      |> Task.map NewTimeline
      |> Effects.task

-- *** JSON Decoders ***
jsonModel : Json.Decoder Timeline
jsonModel =
  rootDecoder (Json.oneOf [eventDecoder, eventDecoderWithoutNumber])

rootDecoder : Json.Decoder Event -> Json.Decoder Timeline
rootDecoder event =
  Json.object2 (\t e -> Timeline t e)
    ("title" := Json.string)
    ("events" := (Json.list event))

eventDecoder : Json.Decoder Event
eventDecoder =
  Json.object5 (\t d url card number -> Event number t d (strToTime d) url card)
     ("text" := Json.string)
     ("date" := Json.string)
     ("event_url" := Json.oneOf [Json.string, Json.null ""])
     ("fight_card" :=  cardDecoder) -- Json.oneOf [Json.list cardDecoder , Json.null ""])
     ("number" := Json.maybe Json.int)

eventDecoderWithoutNumber : Json.Decoder Event
eventDecoderWithoutNumber =
  Json.object4 (\t d url card -> Event Nothing t d (strToTime d) url card)
     ("text" := Json.string)
     ("date" := Json.string)
     ("event_url" := Json.oneOf [Json.string, Json.null ""])
     ("fight_card" :=  cardDecoder) -- Json.oneOf [Json.list cardDecoder , Json.null ""])

strToTime : String -> Maybe Time.Time
strToTime date_str =
  let date_result = Date.fromString date_str
  in  case date_result of
    Ok date -> Just (Date.toTime date)
    Err error -> Nothing

cardDecoder : Json.Decoder (Maybe FightCard)
cardDecoder =
    Json.oneOf
    [ Json.null Nothing
    , Json.map Just (Json.list fightResultDecoder)
    ]

fightResultDecoder : Json.Decoder FightResult
fightResultDecoder =
  Json.object4 (\w l result weight_class -> FightResult w l result weight_class)
     ("winner" := Json.string)
     ("loser" := Json.string)
     ("result" := Json.string)
     ("weight_class" := Json.string)
