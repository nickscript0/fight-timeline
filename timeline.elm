-- given a JSON input of events, show a simple visual timeline of text events


module Timeline exposing (..)

import Http
import Json.Decode as Json exposing ((:=))
import Task exposing (..)
import Time
import Date
import Html exposing (div, text, h1, input, button, form, fieldset, address, a)
import Html.Attributes exposing (class, id, type', placeholder, href, style, autofocus, title)
import Html.Events exposing (onClick, on, targetValue)
import Html.Lazy exposing (lazy, lazy2)
import Html.App
import Model exposing (FightResult, FightCard, Event, Events, Timeline, Model)
import SearchEvents exposing (filterWithResult, SearchResult(..), EventSearchResult)
import Moment


-- *** main ***


main : Program Never
main =
    Html.App.program
        { init = init, update = update, view = view, subscriptions = \_ -> Sub.none }



-- *** Model ***
-- See model.elm


init : ( Model, Cmd Msg )
init =
    ( msgModel "Loading..."
    , Cmd.batch
        [ getTimelineJson "all_events.json"
        , getTime
        ]
    )



-- Repurpose the model as a message to the user (TODO: do this properly by having view code to display messages)


msgModel : String -> Model
msgModel msg =
    Model (Timeline "Message" [ Event Nothing msg "" Nothing "" Nothing ] "") "" Nothing



-- *** View ***


view : Model -> Html.Html Msg
view model =
    model.timeline.events
        |> List.map (filterWithResult model.search_value)
        |> List.filter (\x -> x.result /= NotFound)
        |> view_content model


view_content : Model -> List EventSearchResult -> Html.Html Msg
view_content model search_results =
    div [ class "content" ]
        [ h1 [] [ text model.timeline.title ]
        , view_today_date model.current_time (Moment.epochSecondsToTime model.timeline.last_updated)
        , lazy view_inputSearch (List.length search_results)
        , lazy2 view_timeline search_results model.current_time
        ]


view_today_date : Maybe Time.Time -> Maybe Time.Time -> Html.Html Msg
view_today_date maybe_time maybe_last_updated =
    case maybe_time of
        Just time ->
            let
                t =
                    Date.fromTime time
            in
                div [ class "timestamp" ]
                    [ "Generated on "
                        ++ toString (Date.year t)
                        ++ "-"
                        ++ Moment.monthNum (Date.month t)
                        ++ "-"
                        ++ toString (Date.day t)
                        ++ " "
                        ++ toString (Date.hour t)
                        ++ ":"
                        ++ toString (Date.minute t)
                        ++ ":"
                        ++ toString (Date.second t)
                        ++ " | "
                        ++ "Database updated: "
                        ++ Moment.diffTime maybe_last_updated maybe_time
                        |> text
                    ]

        Nothing ->
            text ""


view_timeline : List EventSearchResult -> Maybe Time.Time -> Html.Html Msg
view_timeline search_results current_time =
    div [ class "vert-line" ]
        (List.map (view_event current_time) search_results)


view_event : Maybe Time.Time -> EventSearchResult -> Html.Html Msg
view_event current_time esr =
    div []
        [ div [ class "horizontal-timeline" ]
            [ if esr.event.url /= "" then
                view_link esr.event
              else
                text esr.event.text
            , div_rel_time_tag esr.event current_time
            ]
        , div
            [ class "event-block" ]
            [ div_event_result esr.result (Moment.isBefore current_time esr.event.time_type)
            ]
        ]


div_rel_time_tag : Event -> Maybe Time.Time -> Html.Html Msg
div_rel_time_tag event now_t =
    div
        [ ("label "
            ++ (if (Moment.isBefore event.time_type now_t) then
                    "label-default"
                else
                    "label-warning"
               )
            ++ " tag-inline"
          )
            |> class
        , title event.date
        ]
        [ Moment.diffTime event.time_type now_t |> text ]


div_event_result : SearchResult -> Bool -> Html.Html Msg
div_event_result result is_future =
    case result of
        FightMatch result is_winner ->
            div [ class "fight-result" ]
                [ div_win_loss is_winner is_future
                , div_vs result is_future
                ]

        TextMatch ->
            div [] []

        NotFound ->
            div [] []


div_vs : FightResult -> Bool -> Html.Html Msg
div_vs result is_future =
    div [ class "win-loss-value" ]
        [ div [ class "bold" ] [ text result.winner ]
        , text
            (if is_future then
                " fights "
             else
                " defeated "
            )
        , div [ class "bold" ] [ text result.loser ]
        , text
            (if is_future then
                ""
             else
                " by "
            )
        , div [ class "inline" ] [ text result.result ]
        ]


div_win_loss : Bool -> Bool -> Html.Html Msg
div_win_loss is_winner is_future =
    if is_future then
        div [ class "win-loss-label label label-info" ]
            [ text "Upcoming" ]
    else if is_winner then
        div [ class "win-loss-label label label-success" ]
            [ text "Win" ]
    else
        div [ class "win-loss-label label label-danger" ]
            [ text "Loss" ]


view_link : Event -> Html.Html Msg
view_link event =
    a [ href event.url ]
        [ text event.text ]


view_inputSearch : Int -> Html.Html Msg
view_inputSearch result_count =
    div [ class "search-box" ]
        [ div [ class "result-count" ]
            [ ("Search (" ++ toString result_count ++ " matches)") |> text ]
        , input
            [ class "search-input"
            , type' "search"
            , placeholder ""
            , autofocus True
            , Html.Events.onInput (\s -> SearchInput s)
            ]
            []
        ]



-- *** Update ***


type Msg
    = NoOp
    | NewTimeline (Result Http.Error Timeline)
    | SearchInput String
    | CurrentTime Time.Time
    | GeneralError String


update : Msg -> Model -> ( Model, Cmd Msg )
update action model =
    case action of
        NoOp ->
            ( msgModel "NoOp"
            , Cmd.none
            )

        NewTimeline resultTimeline ->
            case resultTimeline of
                Ok timeline ->
                    ( { model | timeline = timeline }
                    , Cmd.none
                    )

                Err error ->
                    ( msgModel (toString error)
                    , Cmd.none
                    )

        SearchInput search ->
            ( { model | search_value = search }
            , Cmd.none
            )

        CurrentTime time ->
            ( { model | current_time = (Just time) }
            , Cmd.none
            )

        GeneralError s ->
            ( msgModel s
            , Cmd.none
            )



-- *** Effects ***


getTime : Cmd Msg
getTime =
    Time.now
        |> Task.perform
            (\x -> GeneralError "Error getting current time")
            (\a -> CurrentTime a)


getTimelineJson : String -> Cmd Msg
getTimelineJson query =
    Http.get jsonModel (query)
        |> Task.toResult
        |> Task.perform
            (\x -> GeneralError "Error retrieving timeline.json")
            (\a -> NewTimeline a)



-- *** JSON Decoders ***


jsonModel : Json.Decoder Timeline
jsonModel =
    rootDecoder (Json.oneOf [ eventDecoder, eventDecoderWithoutNumber ])


rootDecoder : Json.Decoder Event -> Json.Decoder Timeline
rootDecoder event =
    Json.object3 (\t e lu -> Timeline t e lu)
        ("title" := Json.string)
        ("events" := (Json.list event))
        ("last_updated" := Json.string)


eventDecoder : Json.Decoder Event
eventDecoder =
    Json.object5 (\t d url card number -> Event number t d (strToTime d) url card)
        ("text" := Json.string)
        ("date" := Json.string)
        ("event_url" := Json.oneOf [ Json.string, Json.null "" ])
        ("fight_card" := cardDecoder)
        -- Json.oneOf [Json.list cardDecoder , Json.null ""])
        ("number" := Json.maybe Json.int)


eventDecoderWithoutNumber : Json.Decoder Event
eventDecoderWithoutNumber =
    Json.object4 (\t d url card -> Event Nothing t d (strToTime d) url card)
        ("text" := Json.string)
        ("date" := Json.string)
        ("event_url" := Json.oneOf [ Json.string, Json.null "" ])
        ("fight_card" := cardDecoder)



-- Json.oneOf [Json.list cardDecoder , Json.null ""])


strToTime : String -> Maybe Time.Time
strToTime date_str =
    let
        date_result =
            Date.fromString date_str
    in
        case date_result of
            Ok date ->
                Just (Date.toTime date)

            Err error ->
                Nothing


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
