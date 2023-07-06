#!/bin/bash

# 15 min timeout for each sync
timeout 900 docker container exec rclone rclone sync onedrive: /data/onedrive
docker 900 container exec rclone rclone sync gphotos: /data/gphotos
docker 900 container exec rclone rclone sync gdrive: /data/gdrive

# cron to run it once a day
# 30 4 * * * ~/rclone/sync.sh
