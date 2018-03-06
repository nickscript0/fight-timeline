FROM python:3.5-alpine
RUN apk add --no-cache git

WORKDIR /workdir
RUN pip install beautifulsoup4 git+https://github.com/nickscript0/async_request.git

# Install cron
COPY scripts/refreshdata /workdir/
COPY scripts/get_ufc_events.py /workdir/


# Copy static files to /static volume
COPY index.html /static/
COPY main.css /static/
COPY timeline.js /static/

# Cache the python request cache in a volume
VOLUME ["/shelve-cache"]

# Run twice a day: 12:18am and 12:18pm
RUN echo '18 */12 * * *    /workdir/refreshdata' > /etc/crontabs/root

CMD /workdir/refreshdata && crond -l 2 -f