#!/bin/bash

# 'journalctl' and 'folder2ram' store disk data in RAM with the intention of preserving
# the lifespan of the SD card. However, if left unmonitored, 
# they can potentially consume excessive RAM.

journalctl --vacuum-size=10M
folder2ram -syncall

# 0 5 * * * ~/reduce_journal_size.sh
