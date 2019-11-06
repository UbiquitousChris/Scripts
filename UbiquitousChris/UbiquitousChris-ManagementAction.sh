#!/bin/zsh
###############################################################################
# 
# 
#
# Author Name: Weinkauf, Chris
# Author Date: Jun 28 2019
# Purpose: Display an alert using the Management Action app
#
#
# Change Log:
# Jun 28 2019, UbiquitousChris
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

MANAGEMENT_ACTION_BIN="/Library/Application Support/JAMF/bin/Management Action.app/Contents/MacOS/Management Action"

MESSAGE="$4"
TITLE="$5"
SUBTITLE="$6"
DELIVERY_DELAY="$7"

#-------------------
# Functions
#-------------------

#------------------------------------------------------------------------------
# Start Script
#------------------------------------------------------------------------------

# Make sure the management action app exists
if [[ ! -f "$MANAGEMENT_ACTION_BIN" ]]; then
    echo "ERROR: Managment Action app is missing."
    exit 3
fi

# Make sure a message was passed in
if [[ -z "$MESSAGE" ]]; then
    echo "ERROR: Message parameter must be specified"
    exit 1
fi

# Set up the base command
COMMAND="'$MANAGEMENT_ACTION_BIN' -message '$MESSAGE'"

# Add options if specified
[[ ! -z "$TITLE" ]] && COMMAND+=" -title '$TITLE'"
[[ ! -z "$SUBTITLE" ]] && COMMAND+=" -subtitle '$SUBTITLE'"
[[ ! -z "$DELIVERY_DELAY" ]] && COMMAND+=" -deliverydelay $DELIVERY_DELAY"

echo "INFO: Command: $COMMAND"

# Show the notification
eval "$COMMAND"

if [[ "$?" != "0" ]]; then
    echo "ERROR: Failed to show notification"
    exit 2
fi

#-------------------------------------------------
# Detailed comment on a piece of code.
#-------------------------------------------------

#------------------------------------------------------------------------------
# End Script
#------------------------------------------------------------------------------
exit 0
