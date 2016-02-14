"""
Retrieve timeline of UFC events from wikipedia and output as json.

TODO: sanitize inputs (e.g. could be vulnerable to XSS)
"""
# pip install bs4
from bs4 import BeautifulSoup
import json
import sys
import shelve
import logging
from collections import OrderedDict

from async_request import async_urlopen

logging.getLogger('async_request').addHandler(logging.StreamHandler())
logging.getLogger('async_request').setLevel(logging.DEBUG)

EVENTS_URL = 'https://en.wikipedia.org/wiki/List_of_UFC_events'
BASE_URL = 'https://en.wikipedia.org'
NUM_PARALLEL_REQUESTS = 20


def main():
    output = OrderedDict((
        ('title', 'UFC Events'),
        ('events', get_events())
    ))
    print(json.dumps(output, indent=2))


def get_events():
    request = RequestCache()
    event_list_page = request.getOne(EVENTS_URL)

    future_events = EventsListPage.getFutureEvents(event_list_page)
    future_events_results = _get_event_details(request, future_events)

    past_events = EventsListPage.getPastEvents(event_list_page)
    past_events_results = _get_event_details(request, past_events)

    request.close()
    return future_events_results + past_events_results


def _get_event_details(request_obj, events_list):
    """
    Given a list of dictionary events, add a 'fight_card' field with the event
    details.
    """
    event_urls = [e['event_url']
                  for e in events_list if e['event_url'] is not None]
    events_data = iter(request_obj.getMany(event_urls))
    for e in events_list:
        if e['event_url'] is not None:
            e['fight_card'] = EventPage.getJson(e['text'], next(events_data))
        else:
            e['fight_card'] = None

    return events_list


class EventPage:

    """
    Parse the 'Results' table (for past events) or 'Official fight card'
    table (for future events) on a UFC event page.
    """

    @classmethod
    def getJson(cls, title, data, as_dict=True):
        table = cls._getTable(title, data)
        if table is None:
            return None
        trs = table.findAll('tr')
        results = map(cls._parseRow, trs[1:])
        results = [x for x in results if x is not None]
        return results if as_dict else json.dumps(results, indent=2)

    @staticmethod
    def _getTable(event_title, data):
        title = data.find('h1', attrs={'id': 'firstHeading'})
        table = None

        # Special case where event is on a "2012_in_UFC" aggregated page
        if title.text.lower().endswith('in ufc'):
            debug("Title={}".format(title.text))
            headlines = data.findAll('span', attrs={'class': 'mw-headline'})
            headline = [x for x in headlines if x.text == event_title]
            table = headline[0].find_next(
                'table', attrs={'class': 'toccolours'}) if len(headline) > 0 else None
        # Normal case where event is on its own page
        else:
            table = data.find('table', attrs={'class': 'toccolours'})
        return table

    @staticmethod
    def _parseRow(row):
        tds = row.findAll('td')

        # Skip header rows (there are multiple midway through the table)
        if len(tds) == 0:
            return None

        try:
            # weight, winner, _, loser, result, rounds, time, notes
            weight, winner, _, loser, result, \
                rounds, time = tds[:7]  # pylint: disable=W0612
        except ValueError:
            debug(row)
            raise

        winner, _ = _getTextAndLink(winner)
        loser, _ = _getTextAndLink(loser)

        return OrderedDict((
            ('winner', winner),
            ('loser', loser),
            ('result', result.text),
            ('weight_class', weight.text)
        ))


class EventsListPage:

    """ Parse the 'Scheduled Events' or 'Past Events' table on List_of_UFC_events to a dictionary. """

    @classmethod
    def getPastEvents(cls, data):
        tables = data.findAll('table')
        # As of now Past Events is the 2nd table on the page
        return cls._getJson(tables[1], cls._parsePastRow)

    @classmethod
    def getFutureEvents(cls, data):
        table = data.find('table', attrs={'id': 'Scheduled_events'})
        return cls._getJson(table, cls._parseFutureRow)

    @classmethod
    def _getJson(cls, table, row_parser_func):
        trs = table.findAll('tr')
        events = [row_parser_func(tr) for tr in trs[1:]]
        return events

    @staticmethod
    def _parseDateSpan(date_td):
        """
        Retrieves the human readable date from the following td element pattern:
        <td><span class="sortkey" style="display:none;speak:none">000000002016-01-17-0000</span>
        <span style="white-space:nowrap">Jan 17, 2016</span></td>
        """
        date_spans = date_td.findAll('span')
        date = date_spans[1] if len(date_spans) > 1 else date_td
        return date

    @staticmethod
    def _parseFutureRow(row):
        event, date, venue, location = row.findAll('td')

        date = EventsListPage._parseDateSpan(date)
        text, link = _getTextAndLink(event)
        link = BASE_URL + link if link is not None else None

        return OrderedDict((
            ('text', text),
            ('date', date.text),
            ('venue', venue.text),
            ('location', location.text),
            ('event_url', link)
        ))

    @staticmethod
    def _parsePastRow(row):
        num, event, date, venue, location, attendance = row.findAll(  # pylint: disable=W0612
            'td')

        date = EventsListPage._parseDateSpan(date)
        text, link = _getTextAndLink(event)
        link = BASE_URL + link if link is not None else None

        return OrderedDict((
            ('number', num.text),
            ('text', text),
            ('date', date.text),
            ('venue', venue.text),
            ('location', location.text),
            ('event_url', link)
        ))


def _getTextAndLink(el):
    """ Returns (text, link) out of an <a> element """
    a = el.find('a')
    if a is not None:
        link = a.get('href')
        text = a.text
    else:
        link = None
        text = el.text
    return (text, link)


class RequestCache:

    def __init__(self):
        self.cache = shelve.open('bs_cache.shelve')

    def getOne(self, url=EVENTS_URL):
        if url not in self.cache:
            self.cache[url] = async_urlopen([url])[0]
        else:
            debug('Cache hit: ' + url)
        return BeautifulSoup(self.cache[url], "html.parser")

    def getMany(self, urls):
        not_cached_urls = [x for x in urls if (x not in self.cache)]
        responses = []
        if len(not_cached_urls) > 0:
            responses = async_urlopen(not_cached_urls, NUM_PARALLEL_REQUESTS)
        for req, res in zip(not_cached_urls, responses):
            self.cache[req] = res

        return [BeautifulSoup(self.cache[x], "html.parser") for x in urls]

    def close(self):
        self.cache.close()


def debug(s):
    sys.stderr.write("DEBUG: %s\n" % (s))


if __name__ == "__main__":
    main()
