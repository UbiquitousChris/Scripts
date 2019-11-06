#!/bin/zsh
###############################################################################
# 
# 
#
# Author Name: Weinkauf, Chris
# Author Date: Sep 09 2019
# Purpose: Removes all items from the Jamf waiting room
#
#
# Change Log:
# Sep 09 2019, UbiquitousChris
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

JAMF_DIRECTORY="/Library/Application Support/JAMF"
WAITING_ROOM="$JAMF_DIRECTORY/Waiting Room"
DOWNLOADS="$JAMF_DIRECTORY/Downloads"

#-------------------
# Functions
#-------------------

#------------------------------------------------------------------------------
# Start Script
#------------------------------------------------------------------------------

if [[ -d "$DOWNLOADS" ]]; then
    echo "INFO: Clearing Downloads"
    rm -Rfv "$DOWNLOADS/"

    if [[ "$?" != "0" ]]; then
        echo "ERROR: Failed to clear directory $DOWNLOADS"
        exit 1
    else
        echo "INFO: Downloads cleared successfully."
    fi
else
    echo "INFO: Downloads directory does not exist."
fi


if [[ -d "$WAITING_ROOM" ]]; then
    echo "INFO: Clearing Waiting Room"
    rm -Rfv "$WAITING_ROOM/"

    if [[ "$?" != "0" ]]; then
        echo "ERROR: Failed to clear directory $WAITING_ROOM"
        exit 1
    else
        echo "INFO: Waiting Room cleared successfully."
    fi
else
    echo "INFO: Waiting Room does not exist."
fi

#------------------------------------------------------------------------------
# End Script
#------------------------------------------------------------------------------
exit 0
