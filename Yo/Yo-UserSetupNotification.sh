#!/bin/sh
###############################################################################
# 
# 
#
# Author Name: Weinkauf, Chris
# Author Date: Feb 06 2019
# Purpose: Allows jamf to prompt the user with a yo notification
#
#
# Change Log:
# Feb 06 2019, UbiquitousChris
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

YO_SCHEDULER="/usr/local/bin/yo_scheduler"
YO_BINARY="/Applications/Utilities/yo.app/Contents/MacOS/yo"
TITLE="$4"
SUBTITLE="$5"
INFO_TEXT="$6"
BUTTON_TITLE="$7"
ACTION_PATH="${8}"
BASH_ACTION="$9"
OTHER_BUTTON="${10}"
ICON="${11}"

#-------------------
# Functions
#-------------------

#------------------------------------------------------------------------------
# Start Script
#------------------------------------------------------------------------------

if [[ "$ACTION_PATH" =~ ^[0-9]+$ ]]; then
    echo "INFO: Numeric value passed in. Assuming Self Service policy ID"
    ACTION_PATH='jamfselfservice://content?entity=policy&id='$ACTION_PATH'&action=execute'
fi

# Check for yo framework
if [[ ! -f "$YO_SCHEDULER" ]] || [[ ! -f "$YO_BINARY" ]]; then
    echo "WARN: yo is not installed."
    exit 1
fi

# Check for title
if [[ "$TITLE" == "" ]]; then
    echo "ERROR: Title must be specified!"
    exit 10
else
    CMD="$YO_SCHEDULER --title '$TITLE'"
fi

[[ "$SUBTITLE" != "" ]] && CMD+=" --subtitle '$SUBTITLE'"
[[ "$INFO_TEXT" != "" ]] && CMD+=" --info '$INFO_TEXT'"
[[ "$BUTTON_TITLE" != "" ]] && CMD+=" --action-btn '$BUTTON_TITLE'"
[[ "$ACTION_PATH" != "" ]] && CMD+=" --action-path '$ACTION_PATH'"
[[ "$BASH_ACTION" != "" ]] && CMD+=" --bash-action '$BASH_ACTION'"
[[ "$OTHER_BUTTON" != "" ]] && CMD+=" --other-btn '$OTHER_BUTTON'"
[[ "$ICON" != "" ]] && CMD+=" --content-image '$ICON'"
CMD+=" --delivery-sound 'None'"

# Build out command
echo "INFO: Running command: $CMD"
eval "$CMD"

#-------------------------------------------------
# Detailed comment on a piece of code.
#-------------------------------------------------

#------------------------------------------------------------------------------
# End Script
#------------------------------------------------------------------------------
exit 0
