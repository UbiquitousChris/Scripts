#!/bin/sh
###############################################################################
# 
# 
#
# Author Name: Weinkauf, Chris
# Author Date: Jun 06 2019
# Purpose: Find and output all 32-bit apps as a text file
#
#
# Change Log:
# Jun 06 2019, UbiquitousChris
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

RUN_THROUGH_SELF_SERVICE="$4"
FILE_NAME="LegacyApps.txt"
SYSTEM_LOCATION="/Library/Application Support/CompName"
CURRENT_USER="$(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }')"

#-------------------
# Functions
#-------------------

#------------------------------------------------------------------------------
# Start Script
#------------------------------------------------------------------------------

echo "INFO: Checking for output directory"
[[ "$RUN_THROUGH_SELF_SERVICE" == "true" ]] && echo "INFO: Requested via Self Service. Will open after running."

echo "INFO: Creating output directory if required"
[[ ! -d "$SYSTEM_LOCATION" ]] && mkdir -p "$SYSTEM_LOCATION"

echo "INFO: Output location: $SYSTEM_LOCATION/$FILE_NAME"
echo "INFO: Gathering report..."
/usr/sbin/system_profiler SPApplicationsDataType | grep -B 6 -A 2 "(Intel): No" | grep "Location:" | sed -e 's/^[ \t]*//' | sed -e 's/Location\: //g' | grep -v /opt/Simpana | grep -v /opt/simpana | grep -v /System/Library | grep -v '/Users/' | grep -v 'DVD Player.app' > "$SYSTEM_LOCATION/$FILE_NAME"

if [[ "$RUN_THROUGH_SELF_SERVICE" == "true" ]]; then
    echo "INFO: Copying the list to tmp"
    cp "$SYSTEM_LOCATION/$FILE_NAME" "/tmp/$FILE_NAME"
    echo "INFO: Opening output"
    sudo -u "$CURRENT_USER" /usr/bin/open -a "/Applications/TextEdit.app" "/tmp/$FILE_NAME"
    echo "INFO: Displaying dialog."
    osascript -e 'tell application "System Events"' -e 'display dialog "The list of legacy apps has opened in TextEdit for your review." buttons {"Ok"} default button 1 with icon file "System:Library:CoreServices:CoreTypes.bundle:Contents:Resources:AlertNoteIcon.icns"' -e 'end tell' &
fi

echo "INFO: Done!"
#-------------------------------------------------
# Detailed comment on a piece of code.
#-------------------------------------------------

#------------------------------------------------------------------------------
# End Script
#------------------------------------------------------------------------------
exit 0
