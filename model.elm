-- Model for Timeline App
module Model exposing (..)

import Time

type alias FightResult =
  { winner : String
  , loser  : String
  , result : String
  , weight_class : String
  }

type alias FightCard = List FightResult

type alias Event =
  { number : Maybe Int
  , text : String
  , date : String
  , time_type : Maybe Time.Time
  , url : String
  , fight_card : Maybe FightCard
  }

type alias Events = List Event

type alias Timeline =
  { title : String
  , events : Events
  }

type alias Model =
  { timeline : Timeline
  , search_value : String
  , current_time : Maybe Time.Time
  }
