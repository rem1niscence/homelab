#!/bin/bash

docker container exec rclone rclone sync onedrive: /data/onedrive
docker container exec rclone rclone sync gphotos: /data/gphotos
docker container exec rclone rclone sync gdrive: /data/gdrive

# cron to run it once a day
# 30 4 * * * ~/rclone/sync.sh
