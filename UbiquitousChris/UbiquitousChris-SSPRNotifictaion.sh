#!/bin/sh
###############################################################################
# 
# 
#
# Author Name: Weinkauf, Chris
# Author Date: May 07 2019
# Purpose: Display a popup notification encouraging user to sign up for
#          SSPR
#
# Change Log:
# Jun 14 2019, UbiquitousChris
# - Updated to use OSA instead of open command
# May 07 2019, UbiquitousChris
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

JAMF_HELPER_BIN="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"

TITLE="CompName Information Security"
HEADING="Action Required"
DESCRIPTION="Register now so you can easily reset your password the next time it expires. Click Register Now and sign up using your CompName email address and password."
BUTTON1="Register Now"
BUTTON2="Later"


ICON_B64="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"

ICON="/tmp/icon.png"

CURRENT_USER="$(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }')"

#-------------------
# Functions
#-------------------

#------------------------------------------------------------------------------
# Start Script
#------------------------------------------------------------------------------
if [[ -z "$CURRENT_USER" ]]; then
  echo "INFO: Nobody logged in."
  exit 0
fi

if [[ -f "/var/tmp/.hasSeenSSPRNotice" ]]; then
  echo "INFO: SSPR notice has already shown"
  exit 0
fi

echo "$ICON_B64" | base64 --decode --output "$ICON" --input -

"$JAMF_HELPER_BIN" -windowType hud \
  -windowPosition lr \
  -title "$TITLE" \
  -heading "$HEADING" \
  -description "$DESCRIPTION" \
  -icon "$ICON" \
  -button1 "$BUTTON1" \
  -button2 "$BUTTON2" \
  -defaultButton 1

if [[ "$?" == "0" ]]; then
  /usr/bin/osascript -e 'open location "https://aka.ms/ssprsetup"'

  /usr/bin/touch "/var/tmp/.hasSeenSSPRNotice"
fi




#-------------------------------------------------
# Detailed comment on a piece of code.
#-------------------------------------------------

#------------------------------------------------------------------------------
# End Script
#------------------------------------------------------------------------------
exit 0
