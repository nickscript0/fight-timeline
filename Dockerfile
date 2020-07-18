FROM python:3-alpine

# Note: gcc, musl-dev are required for pip install multidict package error:
# Failed to build wheel for multidict
# /usr/local/include/python3.8/Python.h:11:10: fatal error: limits.h: No such file or directory
RUN apk add --no-cache git gcc musl-dev

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