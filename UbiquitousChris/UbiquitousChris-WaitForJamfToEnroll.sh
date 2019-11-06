#!/bin/sh
###############################################################################
# 
# 
#
# Author Name: Weinkauf, Chris
# Author Date: May 08 2018
# Purpose:
#
#
# Change Log:
# May 08 2018, UbiquitousChris
# - Initial Creation
###############################################################################

#-------------------
# Parse standard package arguments
#-------------------
__SCRIPT_PATH="$0"
__PACKAGE_PATH="$1"
__DEFAULT_LOC="$2"
__TARGET_VOL="$3"

#-------------------
# Variables
#-------------------

JAMF_BIN="/usr/local/bin/jamf"
JAMF_LOG="/private/var/log/jamf.log"

#-------------------
# Functions
#-------------------

#------------------------------------------------------------------------------
# Start Script
#------------------------------------------------------------------------------

echo "INFO: Waiting for the jamf binary to appear..."

while [ ! -f "$JAMF_BIN" ]; do
    sleep 1
done

echo "INFO: Jamf Binary is now available at $JAMF_BIN"

echo "INFO: Waiting for the jamf log to appear"

while [ ! -f "$JAMF_LOG" ]; do
    sleep 1
done

echo "INFO: Jamf log is now available at $JAMF_LOG"

#-------------------------------------------------
# Detailed comment on a piece of code.
#-------------------------------------------------

#------------------------------------------------------------------------------
# End Script
#------------------------------------------------------------------------------
exit 0
