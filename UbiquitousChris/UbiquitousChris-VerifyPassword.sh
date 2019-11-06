#!/bin/sh
###############################################################################
# 
# 
#
# Author Name: Weinkauf, Chris
# Author Date: Apr 24 2019
# Purpose: Verifies the locally cached password of the currently logged in user
#
#
# Change Log:
# Apr 24 2019, UbiquitousChris
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

CURRENT_LOGGED_IN_USER="$(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }')"

while true; do
    LOCAL_PASSWORD=$(sudo -u "$CURRENT_LOGGED_IN_USER" /usr/bin/osascript -e 'tell me to activate' -e 'text returned of (display dialog "The password validation tool will checks your password against the local password database.\n\nEnter the password for '$CURRENT_LOGGED_IN_USER'." default answer "" buttons {"Cancel","OK"} default button 2 with hidden answer with icon file "System:Library:CoreServices:CoreTypes.bundle:Contents:Resources:FileVaultIcon.icns")')

    if [[ "$?" != "0" ]]; then
        echo "INFO: User chose to quit."
        exit 0
    fi

    /usr/bin/dscl . -authonly "$CURRENT_LOGGED_IN_USER" "$LOCAL_PASSWORD"

    if [[ "$?" != "0" ]]; then
        echo "ERROR: Incorrect password for $CURRENT_LOGGED_IN_USER"
        osascript -e 'display dialog "Invalid Password." buttons {"Try Again"} default button 1 with icon file "System:Library:CoreServices:CoreTypes.bundle:Contents:Resources:AlertStopIcon.icns"'
        continue
    else
        echo "INFO: Password accepted."
        osascript -e 'display dialog "Password is valid." buttons {"Done"} default button 1 with icon file "System:Library:CoreServices:CoreTypes.bundle:Contents:Resources:ToolbarInfo.icns"' &
        break
    fi

done

#-------------------
# Functions
#-------------------

#------------------------------------------------------------------------------
# Start Script
#------------------------------------------------------------------------------

#-------------------------------------------------
# Detailed comment on a piece of code.
#-------------------------------------------------

#------------------------------------------------------------------------------
# End Script
#------------------------------------------------------------------------------
exit 0
