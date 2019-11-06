#!/bin/sh
###############################################################################
# 
# 
#
# Author Name: Weinkauf, Chris
# Author Date: Feb 19 2019
# Purpose:
#
#
# Change Log:
# Mar 09 2019, UbiquitousChris
# - Updated to use jamf helper with a countdown since Jamf is still updating it
# Feb 19 2019, UbiquitousChris
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

MINUTES_UNTIL_REBOOT="$4"
HOURS_UNTIL_REBOOT="$((MINUTES_UNTIL_REBOOT/60))"
SECONDS_UNTIL_REBOOT="$((MINUTES_UNTIL_REBOOT*60))"

LOGGED_IN_USER=$(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }')

TESTING="false" # Set to true to bypass the jamf.log check

JAMF_HELPER="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"
ICON="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/Resources/Restart.png"

# Determine the human friendly timer for the main dialog
if [[ $HOURS_UNTIL_REBOOT == 0 ]] && [[ $MINUTES_UNTIL_REBOOT -gt 1 ]]; then
  HUMAN_FRIENDLY_TIME="$MINUTES_UNTIL_REBOOT minutes"
elif [[ $HOURS_UNTIL_REBOOT == 0 ]] && [[ $MINUTES_UNTIL_REBOOT == 1 ]]; then
  HUMAN_FRIENDLY_TIME="$MINUTES_UNTIL_REBOOT minute"
elif [[ $HOURS_UNTIL_REBOOT == 1 ]]; then
  HUMAN_FRIENDLY_TIME="$HOURS_UNTIL_REBOOT hour"
else
  HUMAN_FRIENDLY_TIME="$HOURS_UNTIL_REBOOT hours"
fi

HEADING_TEXT="Your computer is about to restart."

WINDOW_TEXT="Your computer must restart to complete the installation of applications and software updates.

You can restart your computer now or your computer will restart automatically in about $HUMAN_FRIENDLY_TIME."

REBOOT_TEXT="Your computer is restarting to complete the installation of applications and software updates."
#-------------------
# Functions
#-------------------

main()
{

    echo "INFO: Restart will take place in $MINUTES_UNTIL_REBOOT ($SECONDS_UNTIL_REBOOT seconds) minutes."

    # Display the primary dialog
    "$JAMF_HELPER" -windowType utility -title "CompName Management Action" -heading "$HEADING_TEXT" -windowPosition ur -description "$WINDOW_TEXT" -icon "$ICON" -button1 "Restart Now" -defaultButton 1 -timeout $SECONDS_UNTIL_REBOOT -countdown

    echo "INFO: Countdown timer has been reached or user chose to reboot. Rebooting now."
    # Display the final dialog
    "$JAMF_HELPER" -windowType utility -title "CompName Management Action" -description "$REBOOT_TEXT" -icon "$ICON" -button1 "Okay" -defaultButton 1 &

    # Sleep for a couple to make sure the dialog displays
    /bin/sleep 2

    # Reboot the computer
    /bin/launchctl reboot
}

#------------------------------------------------------------------------------
# Start Script
#------------------------------------------------------------------------------

# Check and make sure a time was passed in
if [[ "$MINUTES_UNTIL_REBOOT" == "" ]] || [[ "$MINUTES_UNTIL_REBOOT" == "0" ]]; then
  echo "ERROR: A time must be passed in to execute properly."
  exit 2
fi

# Check the log to see if a software update that requires a reboot was installed
/usr/bin/tail -20 "/var/log/jamf.log" | grep "Reboot is required." > /dev/null

# If not, no need to reboot. End here.
if [[ "$?" != "0" ]] && [[ "$TESTING" != "true" ]]; then
    echo "INFO: Could not find reboot request in log. No need to notify."
    exit 0
fi

# If a user is not logged in, the jamf binary will handle the reboot
if [[ "$LOGGED_IN_USER" == "" ]]; then
    echo "INFO: Nobody is logged in."
    exit 0
fi

# Execute the restart script as a separate process
main &

#------------------------------------------------------------------------------
# End Script
#------------------------------------------------------------------------------
exit 0
