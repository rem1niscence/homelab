#!/bin/bash

wget -O - https://raw.githubusercontent.com/OpenMediaVault-Plugin-Developers/installScript/master/install | sudo bash

# Note: after this is done it will break all the network connections and change
# the hostname to the user name, you may have to perform manual network changes
# TODO: Explain how to fix such changes