#!/bin/sh
###############################################################################
# 
# 
#
# Author Name: Weinkauf, Chris
# Author Date: Jan 04 2019
# Purpose:
#
#
# Change Log:
# Jan 04 2019, UbiquitousChris
# - Initial Creation
###############################################################################

#-------------------
# Parse standard package arguments
#-------------------
__TARGET_VOL="$1"
__COMPUTER_NAME="$2"
__USERNAME="$3"

#-------------------
# Variables
#-------------------

UPDATE_TO_VERSION="$4"

MSUPDATE_COMMAND="/Library/Application Support/Microsoft/MAU2.0/Microsoft AutoUpdate.app/Contents/MacOS/msupdate"

LOGGED_IN_USER=$(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }')

#-------------------
# Functions
#-------------------

#------------------------------------------------------------------------------
# Start Script
#------------------------------------------------------------------------------

if [[ "$LOGGED_IN_USER" == "" ]]; then
    echo "WARN: Nobody is logged in. Will try later."
    exit 0
fi

if [[ ! -f "$MSUPDATE_COMMAND" ]]; then
    echo "ERROR: A compatible version of AutoUpdate is not installed"
    exit 10
fi

if [[ "$UPDATE_TO_VERSION" != "" ]]; then
    echo "INFO: Looking for updates to version $UPDATE_TO_VERSION"
    sudo -u "$LOGGED_IN_USER" "$MSUPDATE_COMMAND" --install --version $UPDATE_TO_VERSION
else
    echo "INFO: Looking for updates to all versions."
    sudo -u "$LOGGED_IN_USER" "$MSUPDATE_COMMAND" --install
fi

if [[ "$?" != "0" ]]; then
    echo "ERROR: Failed to setup AutoUpdate."
    exit 20
fi



#-------------------------------------------------
# Detailed comment on a piece of code.
#-------------------------------------------------

#------------------------------------------------------------------------------
# End Script
#------------------------------------------------------------------------------
exit 0
