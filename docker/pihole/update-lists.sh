#!/bin/bash

docker container exec -t pihole pihole -g

# cron to run it once a day
# 15 3 * * * ~/docker/pihole/update_lists.sh

# Blocklists
# https://blocklistproject.github.io/Lists/tracking.txt
