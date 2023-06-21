#!/bin/bash

# Enable missing locales
sudo vim /etc/locale.gen

# regenerate locales
sudo locale-gen

# just to confirm it worked
locale -a