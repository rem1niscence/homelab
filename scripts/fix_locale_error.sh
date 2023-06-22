#!/bin/bash

# install vim if not already
sudo apt install -y vim

# Enable missing locales (check first which ones you're missing)
sudo vim /etc/locale.gen

# regenerate locales
sudo locale-gen

# just to confirm it worked
locale -a