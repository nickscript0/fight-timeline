import requests
from bs4 import BeautifulSoup
import json

# Make a GET request to the Wikipedia page
response = requests.get('https://en.wikipedia.org/wiki/List_of_UFC_events')

# Parse the HTML content using BeautifulSoup
soup = BeautifulSoup(response.text, 'html.parser')

# Find the scheduled events table
scheduled_events_table = soup.find('table', {'class': 'wikitable'}).tbody

# Extract the data from the table rows
scheduled_events_data = []
for row in scheduled_events_table.find_all('tr')[1:]:
    cols = row.find_all('td')
    cols = [col.text.strip() for col in cols]
    event_name = cols[0]
    event_date = cols[1]
    event_venue = cols[2]
    event_location = cols[3]
    event_url = row.find_all('a')[0]['href']
    
    # Make a request to the event page
    event_response = requests.get('https://en.wikipedia.org' + event_url)
    event_soup = BeautifulSoup(event_response.text, 'html.parser')
    
    # Find the fight card table
    fight_card_table = event_soup.find('table', {'class': 'toccolours'}).tbody
    
    # Extract the data from the table rows
    fight_card_data = []
    for fight in fight_card_table.find_all('tr')[1:]:
        fighters = fight.find_all('td')
        fighters = [f.text.strip() for f in fighters]
        winner = fighters[0]
        loser = fighters[1]
        result = fighters[2]
        weight_class = fighters[3]
        fight_card_data.append({
            'winner': winner,
            'loser': loser,
            'result': result,
            'weight_class': weight_class
        })
    
    # Create a dictionary object to hold the extracted data for the event
    event_data = {
        'text': event_name,
        'date': event_date,
        'venue': event_venue,
        'location': event_location,
        'event_url': 'https://en.wikipedia.org' + event_url,
        'fight_card': fight_card_data
    }
    
    # Add the event data to the list of scheduled events
    scheduled_events_data.append(event_data)

# Find the past events table
past_events_table = soup.find_all('table', {'class': 'wikitable'})[1].tbody

# Extract the data from the table rows
past_events_data = []
for row in past_events_table.find_all('tr')[1:]:
    cols = row.find_all('td')
    cols = [col.text.strip() for col in cols]
    event_name = cols[0]
    event_date = cols[1]
    event_venue = cols[2]
    event_location = cols[3]
    event_url = row.find_all('a')[0]['href']
    
    # Make a request to the event page
    event_response = requests.get('https://en.wikipedia.org' + event_url)
    event_soup = BeautifulSoup(event_response.text, 'html.parser')
    
    # Find the fight card table
    fight_card_table = event_soup.find('table', {'class': 'toccolours'}).tbody
    
    # Extract the data from the table rows
    fight_card_data = []
    for fight in fight_card_table.find_all('tr')[1:]:
        fighters = fight.find_all
