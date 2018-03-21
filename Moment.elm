-- Time manipulation library modeled off Moment.js


module Moment exposing (..)

import Date exposing (..)
import Time
import String


-- Public Functions


diffTime : Maybe Time.Time -> Maybe Time.Time -> String
diffTime maybe_a maybe_b =
    case ( maybe_a, maybe_b ) of
        ( Just a, Just b ) ->
            Time.inSeconds a
                - Time.inSeconds b
                |> round
                |> relText

        _ ->
            "Error: One of the dates did not exist"


isBefore : Maybe Time.Time -> Maybe Time.Time -> Bool
isBefore maybe_a maybe_b =
    case ( maybe_a, maybe_b ) of
        ( Just a, Just b ) ->
            a <= b

        _ ->
            False



-- Helpers


relText : Int -> String
relText seconds =
    if seconds > 0 then
        "in " ++ rel seconds
    else if seconds < 0 then
        rel seconds ++ " ago"
    else
        "now"


rel : Int -> String
rel seconds =
    let
        maybe_tuple =
            [ ( 3600 * 24 * 30 * 12, "year" )
            , ( 3600 * 24 * 30, "month" )
            , ( 3600 * 24, "day" )
            , ( 3600, "hour" )
            , ( 60, "minute" )
            , ( 1, "second" )
            ]
                |> List.map (\x -> ( seconds // fst x |> abs, snd x ))
                |> List.filter (\x -> fst x /= 0)
                |> List.head
    in
        case maybe_tuple of
            Just tuple ->
                toString (fst tuple)
                    ++ " "
                    ++ snd tuple
                    ++ if (fst tuple) > 1 then
                        "s"
                       else
                        ""

            Nothing ->
                "Error: unable to calculate dates"


epochSecondsToTime: String -> Maybe Time.Time
epochSecondsToTime epochSeconds =
    let
        res = String.toFloat epochSeconds
    in 
        case res of
            Ok value ->
                Just value
            Err error ->
                Nothing


-- This should be added to the official Date library or in its own module


monthNum : Month -> String
monthNum month =
    let
        maybe_month =
            [ Jan, Feb, Mar, Apr, May, Jun, Jul, Aug, Sep, Oct, Nov, Dec ]
                |> List.indexedMap (\i el -> (,) i (el == month))
                |> List.filter (\x -> snd x)
                |> List.map (\x -> fst x)
                |> List.map (\x -> x + 1)
                |> List.head
    in
        case maybe_month of
            Just month_num ->
                toString month_num

            Nothing ->
                "Invalid Month passed to monthNum"
