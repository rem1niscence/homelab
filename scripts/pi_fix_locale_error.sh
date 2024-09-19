#!/bin/bash

# install vim if not already
sudo apt install -y vim

# TODO: Perform zed replace
# Enable missing locales (check first which ones you're missing, usually en_US.UTF-8) 
sudo vim /etc/locale.gen

# regenerate locales
sudo locale-gen

# just to confirm it worked
locale -a
