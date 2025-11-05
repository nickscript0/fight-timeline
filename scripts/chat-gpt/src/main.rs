use select::document::Document;
use select::predicate::{Attr, Name};
use serde::{Serialize, Deserialize};
use std::collections::HashMap;

#[derive(Debug, Serialize, Deserialize)]
struct Event {
    text: String,
    date: String,
    venue: String,
    location: String,
    event_url: String,
    fight_card: Vec<HashMap<String, String>>,
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("Starting chat-gpt-get-ufc-events.rs...");
    let url = "https://en.wikipedia.org/wiki/List_of_UFC_events";

    let resp = reqwest::blocking::get(url)?.text()?;
    let document = Document::from(resp.as_str());

    let mut upcoming_events = Vec::new();
    let mut past_events = Vec::new();

    for table in document.find(Name("table")).take(2) {
        let headers = table.find(Name("th")).map(|th| th.text()).collect::<Vec<_>>();
        let rows = table.find(Name("tr")).skip(1).collect::<Vec<_>>();

        for row in rows {
            let cells = row.find(Name("td")).collect::<Vec<_>>();
            if cells.len() < 5 {
                continue;
            }

            let event_text = cells[0].text();
            let date = cells[1].text();
            let venue = cells[2].text();
            let location = cells[3].text();
            let event_url = cells[0].find(Name("a")).next().unwrap().attr("href").unwrap_or_default();

            let event = Event {
                text: event_text,
                date,
                venue,
                location,
                event_url: format!("https://en.wikipedia.org{}", event_url),
                fight_card: Vec::new(),
            };

            if headers[0].contains("Upcoming") {
                upcoming_events.push(event);
            } else {
                past_events.push(event);
            }
        }
    }

    // for event in &mut upcoming_events {
    //     let resp = reqwest::blocking::get(&event.event_url)?.text()?;
    //     let document = Document::from(resp.as_str());

    //     let fight_card_table = document.find(Attr("class", "toccolours")).next().unwrap();
    //     let rows = fight_card_table.find(Name("tr")).skip(1).collect::<Vec<_>>();

    //     for row in rows {
    //         let cells = row.find(Name("td")).collect::<Vec<_>>();
    //         if cells.len() < 4 {
    //             continue;
    //         }

    //         let winner = cells[0].text();
    //         let loser = cells[2].text();
    //         let result = cells[1].text();
    //         let weight_class = cells[3].text();

    //         let mut fight = HashMap::new();
    //         fight.insert("winner".to_string(), winner);
    //         fight.insert("loser".to_string(), loser);
    //         fight.insert("result".to_string(), result);
    //         fight.insert("weight_class".to_string(), weight_class);

    //         event.fight_card.push(fight);
    //     }
    // }

    // let events = vec![upcoming_events, past_events];
    // let json = serde_json::to_string_pretty(&events)?;
    let json = serde_json::to_string_pretty(&upcoming_events)?;
    println!("{}", json);

    Ok(())
}
