#!/bin/bash
set -e

./bundle.sh
rsync -av bundle/ www-data@careful.observer:/var/www/nicolas
