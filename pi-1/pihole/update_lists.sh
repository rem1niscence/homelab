#!/bin/bash

docker container exec -t pihole pihole -g

# cron to run it once a day
# 15 3 * * * /home/pi-1/pihole/update_lists.sh