#!/bin/sh
###############################################################################
# 
# 
#
# Author Name: Weinkauf, Chris
# Author Date: Apr 26 2018
# Purpose:
#
#
# Change Log:
# Apr 26 2018, UbiquitousChris
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



#-------------------
# Functions
#-------------------

#------------------------------------------------------------------------------
# Start Script
#------------------------------------------------------------------------------

echo "INFO: Waiting for user to log in to console..."
CURRENTLY_LOGGED_IN_USER="$(who | grep console | grep -v "_mbsetupuser" | awk '{ print $1 }')"

while [ "$CURRENTLY_LOGGED_IN_USER" == "" ]; do
    echo "INFO: Still waiting..."
    CURRENTLY_LOGGED_IN_USER="$(who | grep console | grep -v "mbsetupuser" | awk '{ print $1 }')"
    sleep 1
done

echo "INFO: $CURRENTLY_LOGGED_IN_USER has logged in!"

#------------------------------------------------------------------------------
# End Script
#------------------------------------------------------------------------------
exit 0
