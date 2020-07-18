FROM python:3-alpine

# Note: gcc, musl-dev are required for pip install multidict package error:
# Failed to build wheel for multidict
# /usr/local/include/python3.8/Python.h:11:10: fatal error: limits.h: No such file or directory
RUN apk add --no-cache git gcc musl-dev
RUN pip install beautifulsoup4 git+https://github.com/nickscript0/async_request.git
WORKDIR /src
