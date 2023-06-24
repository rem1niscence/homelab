#!/bin/bash

docker container exec -t pihole pihole -g

# cron to run it once a day
# 15 3 * * * ~/pihole/update_lists.sh

# Blocklists
# https://github.com/blocklistproject/Lists