#!/bin/zsh
###############################################################################
# 
# 
#
# Author Name: Weinkauf, Chris
# Author Date: Aug 05 2019
# Purpose:
#
#
# Change Log:
# Aug 05 2019, UbiquitousChris
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

AGENT_NAME="com.example.microsoft.OneDrive"
AGENT_LOCATION="/Library/LaunchAgents/$AGENT_NAME.plist"

#-------------------
# Functions
#-------------------

#------------------------------------------------------------------------------
# Start Script
#------------------------------------------------------------------------------

/usr/bin/defaults write "$AGENT_LOCATION" Label "$AGENT_NAME"
/usr/bin/defaults write "$AGENT_LOCATION" ProgramArguments -array -string "/Applications/OneDrive.app/Contents/MacOS/OneDrive"
/usr/bin/defaults write "$AGENT_LOCATION" KeepAlive -bool true
#/usr/bin/defaults write "$AGENT_LOCATION" RunAtLoad -bool true
/usr/bin/defaults write "$AGENT_LOCATION" ThrottleInterval -int 300

/usr/sbin/chown root:wheel "$AGENT_LOCATION"
/bin/chmod 644 "$AGENT_LOCATION"

[[ -f "/private/var/db/.SetupDone" ]] && /bin/launchctl load "$AGENT_LOCATION"



#------------------------------------------------------------------------------
# End Script
#------------------------------------------------------------------------------
exit 0
