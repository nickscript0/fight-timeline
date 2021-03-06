"""
Retrieve timeline of UFC events from wikipedia and output as json.
"""

# pip install bs4
from bs4 import BeautifulSoup
import json
import sys
import shelve
import logging
from collections import OrderedDict
import time

from async_request import async_urlopen

# Necessary to increase recursion limit so BeautifulSoup object can be stored in a shelve
# otherwise: RecursionError: maximum recursion depth exceeded while getting the str of an object
sys.setrecursionlimit(50000)

logging.getLogger('async_request').addHandler(logging.StreamHandler())
logging.getLogger('async_request').setLevel(logging.DEBUG)

EVENTS_URL = 'https://en.wikipedia.org/wiki/List_of_UFC_events'
BASE_URL = 'https://en.wikipedia.org'
NUM_PARALLEL_REQUESTS = 20


def main():
    output = OrderedDict((
        ('title', 'UFC Events'),
        ('events', get_events()),
        ('last_updated', str(int(time.time() * 1000)))
    ))
    print(json.dumps(output, indent=2))
    debug(time.strftime("%c") + ': Completed')


def get_events():
    request_cache = RequestCache()
    request = RequestCache(use_cache=False)
    event_list_page = request.getOne(EVENTS_URL)

    future_events = EventsListPage.getFutureEvents(event_list_page)
    future_events_results = _get_event_details_sequential(request, future_events)

    past_events = EventsListPage.getPastEvents(event_list_page)
    past_events_results = _get_event_details_sequential(request_cache, past_events)

    request.close()
    return future_events_results + past_events_results


# def _get_event_details(request_obj, events_list):
#     """
#     Given a list of dictionary events, add a 'fight_card' field with the event
#     details.
#     """
#     event_urls = [e['event_url']
#                   for e in events_list if e['event_url'] is not None]
#     events_data = iter(request_obj.getMany(event_urls))
#     for e in events_list:
#         if e['event_url'] is not None:
#             e['fight_card'] = EventPage.getJson(e['text'], next(events_data))
#         else:
#             e['fight_card'] = None

#     return events_list

# Using sequential as the container was running out of memory on gcloud free tier
# TODO:
#  - Could request 20 at a time or so at a time (instead of all as was before)
def _get_event_details_sequential(request_obj, events_list):
    """
    Given a list of dictionary events, add a 'fight_card' field with the event
    details.
    """
    for e in events_list:
        if e['event_url'] is not None:
            res = request_obj.getOne(e['event_url'])
            e['fight_card'] = EventPage.getJson(e['text'], res)
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
            # debug("Title={}".format(title.text))
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
            weight, winner, _, loser, result, rounds, time = extractItemsPad(tds, 7)
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


def extractItemsPad(actualItems, numExpected):
    """ Pad items with default val if there are less, to gracefully handle some rows that were missing cols """

    items = actualItems[:numExpected]
    items.extend([''] * (numExpected - len(items)))
    return items

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
        event, date, venue, location, ref, notes = extractItemsPad(row.findAll('td'), 6)

        date = EventsListPage._parseDateSpan(date)
        text, link = _getTextAndLink(event)
        link = BASE_URL + link if link is not None else None

        return OrderedDict((
            ('text', text),
            ('date', date.text if date else ''),
            ('venue', venue.text if venue else ''),
            ('location', location.text if hasattr(location, 'text') else ''),
            ('event_url', link)
        ))

    @staticmethod
    def _parsePastRow(row):
        num, event, date, venue, location, attendance, ref = extractItemsPad(row.findAll(  # pylint: disable=W0612
            'td'), 7)

        date = EventsListPage._parseDateSpan(date)
        text, link = _getTextAndLink(event)
        link = BASE_URL + link if link is not None else None

        return OrderedDict((
            ('number', num.text),
            ('text', text),
            ('date', date.text),
            ('venue', venue.text),
            ('location', location.text if hasattr(location, 'text') else ''),
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

    def __init__(self, use_cache=True):
        self.use_cache = use_cache
        self.cache = shelve.open('/shelve-cache/bs_cache.shelve') if use_cache else {}

    def getOne(self, url=EVENTS_URL):
        if url not in self.cache:
            self.cache[url] = BeautifulSoup(async_urlopen([url])[0], "html.parser")
        return self.cache[url]

    def getMany(self, urls):
        not_cached_urls = [x for x in urls if (x not in self.cache)]
        responses = []
        count_cache_hits = len(urls) - len(not_cached_urls)
        if count_cache_hits > 0:
            debug('{}/{} cache hits'.format(count_cache_hits, len(urls)))
        if len(not_cached_urls) > 0:
            responses = async_urlopen(not_cached_urls, NUM_PARALLEL_REQUESTS)
        for req, res in zip(not_cached_urls, responses):
            self.cache[req] = BeautifulSoup(res, "html.parser")

        return [self.cache[x] for x in urls]

    def close(self):
        if self.use_cache:
            self.cache.close()


def debug(s):
    sys.stderr.write("DEBUG: %s\n" % (s))


if __name__ == "__main__":
    main()
