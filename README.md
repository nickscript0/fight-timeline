# Usage
## Initial setup
```bash
elm-package install
sh make.sh
```

## Retrieve data
```bash
cd scripts
docker-compose run main /bin/bash
python get_ufc_events.py > events.json
```
## Tests
On hold until node-elm-test is updated for 0.17
