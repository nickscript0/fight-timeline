-- Search functions for Timeline App
module SearchEvents where

import String exposing(contains, toLower)

import Model exposing (FightResult, FightCard, Events, Event)

--- ** Search Logic **
type SearchResult
  = NotFound
  | FightMatch FightResult Bool
  | TextMatch

type alias EventSearchResult =
  { event : Event
  , result : SearchResult
  }

filterWithResult : String -> Event -> EventSearchResult
filterWithResult search event =
  if search == "" then
    EventSearchResult event TextMatch
  else if searchFightCard event.fight_card search then
    case event.fight_card of
      Just card ->
        case (getResultFromCard search card) of
          Just result ->
            EventSearchResult event ((FightMatch result) (isWinner search result))
          Nothing ->
            EventSearchResult event NotFound
      Nothing ->
        EventSearchResult event NotFound
  else if textHasString search event then
    EventSearchResult event TextMatch
  else
    EventSearchResult event NotFound

isWinner : String -> FightResult -> Bool
isWinner search result =
  containsSubstring search result.winner

textHasString : String -> Event -> Bool
textHasString search event =
  (containsSubstring search event.text)

searchFightCard : Maybe FightCard -> String -> Bool
searchFightCard maybe_card search =
  case maybe_card of
    Just card ->
      List.any (fightContainsString search) card
    Nothing ->
      False

getResultFromCard : String -> FightCard -> Maybe FightResult
getResultFromCard search card =
  if search == ""
  then Nothing
  else List.head (List.filter (fightContainsString search) card)


fightContainsString : String -> FightResult -> Bool
fightContainsString search fight =
  containsSubstring search fight.winner
  || containsSubstring search fight.loser
  || containsSubstring search fight.result
  || containsSubstring search fight.weight_class


containsSubstring : String -> String -> Bool
containsSubstring sub text =
  contains (toLower sub) (toLower text)
