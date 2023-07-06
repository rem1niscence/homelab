#!/bin/bash

journalctl --vacuum-size=10M

# 0 5 * * * ~/reduce_journal_size.sh

# Remember to reinstall folder2ram every once in a while to prevent the plugin
# of eating all your RAM. 