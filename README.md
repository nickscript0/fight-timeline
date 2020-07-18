# Usage
## Initial setup
```bash
elm-package install
sh make.sh
```

## Run the App
```
docker run --name fight-timeline-nginx -v ${PWD}:/usr/share/nginx/html:ro -p 1234:80 -d nginx
# Go to localhost:1234/main.html in a web browser
```

## Retrieve data
```bash
cd scripts
docker-compose run --rm main /bin/sh

# Segmentation fault was occurring after the script was partway run with the default ulimit of 8192
# Doubling it did the trick, this does not work in a Dockerfile likely needs to be run in entrypoint script
ulimit -s 16384

python get_ufc_events.py > events.json
# exit the container and `cp events.json ../data/all_events.json
```
## Tests
On hold until node-elm-test is updated for 0.17
