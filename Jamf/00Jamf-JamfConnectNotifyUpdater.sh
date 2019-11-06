#!/bin/sh
###############################################################################
# 
# 
#
# Author Name: Weinkauf, Chris
# Author Date: Apr 17 2019
# Purpose: Updates the Jamf Connect Notify screens with passed in data
#
#
# Change Log:
# Apr 17 2019, UbiquitousChris
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

NOTIFY_LOG="/var/tmp/depnotify.log"

DETERMINATE="$4"
DETERMINATE_STEP="$5"
STATUS_MSG="$6"

#-------------------
# Functions
#-------------------

#------------------------------------------------------------------------------
# Start Script
#------------------------------------------------------------------------------

[[ "$DETERMINATE" != "" ]] && echo "Command: DeterminateManual: $DETERMINATE" >> "$NOTIFY_LOG"

[[ "$DETERMINATE_STEP" != "" ]] && echo "Command: DeterminateManualStep: $DETERMINATE_STEP" >> "$NOTIFY_LOG"

[[ "$STATUS_MSG" != "" ]] && echo "Status: $STATUS_MSG" >> "$NOTIFY_LOG"
#-------------------------------------------------
# Detailed comment on a piece of code.
#-------------------------------------------------

#------------------------------------------------------------------------------
# End Script
#------------------------------------------------------------------------------
exit 0
