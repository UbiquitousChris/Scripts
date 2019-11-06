#!/bin/zsh
###############################################################################
# 
# 
#
# Author Name: Weinkauf, Chris
# Author Date: Oct 08 2018
# Purpose: Elevate a user to administrator temporarily
#
#
# Change Log:
# Sep 20 2019, UbiquitousChris
# - Switch from using Self Service to a LaunchDaemon for elevated rights
# - This will stop the issue with the Self Service policy hanging
# Sep 03 2019, UbiquitousChris
# - Moved to AppleScript dialogs instead of jamfHelper dialogs
# - Cleaned up verbiage to make it clearer what we are doing
# Jul 16 2019, UbiquitousChris
# - Fixed a bug that would cause Self Service process to hang.
# Jun 03 2019, UbiquitousChris
# - Bug fixes for macOS Catalina
# Mar 15 2019, UbiquitousChris
# - Fixed an issue that caused the password prompt to appear behind windows
# Feb 11 2019, UbiquitousChris
# - Deployed a fix for a bug that prevented non-US keyboards from being used
# - at authentication time.
# Oct 08 2018, UbiquitousChris
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

ADMINISTRATOR_THRESHOLD=$4
ADMINISTRATOR_THRESHOLD_IN_MINUTES=$((ADMINISTRATOR_THRESHOLD/60))

JAMF_HELPER_BIN="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"
PANIC_ICON="/System/Library/CoreServices/ReportPanic.app/Contents/Resources/ProblemReporter.icns"

CURRENT_LOGGED_IN_USER="$(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }')"

COUNTDOWN_APP="/Library/Application Support/CompName/Countdown/Countdown.app/Contents/MacOS/Administrative Privileges Active"

HAS_SEEN_FIRST_TIME_MESSAGE="/Users/$CURRENT_LOGGED_IN_USER/.hasSeenPAMFirstSetup"
FIRST_TIME_MESSAGE="Welcome to Make Me Admin.

Running this Self Service item will elevate the currently logged in user to administrator for $ADMINISTRATOR_THRESHOLD_IN_MINUTES minutes or until this Mac is restarted.

While your privledges are elevated, please make sure of the following:
- Respect the privacy of others
- Think before you type or click
- Make sure the actions you take abide by the CompName acceptable use policy"

#-------------------
# Functions
#-------------------

elevateToAdministrator()
{
    echo "INFO: Writing out elevation script."
    echo "#!/bin/zsh

    echo 'INFO: Elevating user to admin'
    /usr/sbin/dseditgroup -o edit -n /Local/Default -a '$CURRENT_LOGGED_IN_USER' -t user admin

    if [[ -f '$COUNTDOWN_APP' ]]; then
        echo 'INFO: Showing countdown screen'
        sudo -u '$CURRENT_LOGGED_IN_USER' '$COUNTDOWN_APP' -t $ADMINISTRATOR_THRESHOLD
        echo 'INFO: Countdown app is running.'
    else
        echo 'INFO: Pausing for $ADMINISTRATOR_THRESHOLD seconds'
        /bin/sleep $ADMINISTRATOR_THRESHOLD
    fi



    echo 'INFO: Times up. Reverting to standard account.'
    /usr/bin/touch '/private/var/tmp/.rightsmanagement'

    if [[ \$? != '0' ]]; then
        echo 'ERROR: Failed to write trigger file.'
        exit 20
    fi

    echo 'INFO: Killing jamfHelper'
    killall -9 jamfHelper

    rm /tmp/elevate.sh

    /usr/local/jamf/bin/jamf recon

    /bin/launchctl remove 'com.example.elevate'" > /tmp/elevate.sh

    /bin/chmod +x /tmp/elevate.sh

    echo "INFO: Building LaunchDaemon..."
    /usr/bin/defaults write "/Library/LaunchDaemons/com.example.elevate.plist" Label -string "com.example.elevate"
    /usr/bin/defaults write "/Library/LaunchDaemons/com.example.elevate.plist" ProgramArguments -array -string "/tmp/elevate.sh"
    /usr/bin/defaults write "/Library/LaunchDaemons/com.example.elevate.plist" RunAtLoad -bool true
    /usr/bin/defaults write "/Library/LaunchDaemons/com.example.elevate.plist" StandardOutPath -string '/var/log/makemeadmin.log'
    /usr/bin/defaults write "/Library/LaunchDaemons/com.example.elevate.plist" StandardErrorPath -string '/var/log/makemeadmin.log'


    echo "INFO: Correcting agent permissions."
    /usr/sbin/chown 'root:wheel' "/Library/LaunchDaemons/com.example.elevate.plist"
    /bin/chmod 644 "/Library/LaunchDaemons/com.example.elevate.plist"

    echo "INFO: Checking for launchd process..."
    /bin/launchctl list | grep 'com.example.elevate' > /dev/null

    if [[ "$?" == "0" ]]; then
        echo "INFO: Process already running. Killing..."
        /bin/launchctl remove 'com.example.elevate'
    fi

    echo "INFO: Loading LaunchDaemon"
    /bin/launchctl load "/Library/LaunchDaemons/com.example.elevate.plist"

    if [[ "$?" != "0" ]]; then
        echo "ERROR: Failed to load Daemon."
        rm "/Library/LaunchDaemons/com.example.elevate.plist"
        exit 35
    else
        echo "INFO: Daemon loaded successfully."
        rm "/Library/LaunchDaemons/com.example.elevate.plist"
    fi

}

#------------------------------------------------------------------------------
# Start Script
#------------------------------------------------------------------------------

# Check and make sure a time value was passed in
if [[ "$ADMINISTRATOR_THRESHOLD" == "" ]]; then
    echo "ERROR: A time value in seconds must be passed in through parameter 4."
    exit 30
fi

# Check is the user already has admin rights
IS_ADMIN="$(dseditgroup -o checkmember -m "$CURRENT_LOGGED_IN_USER" admin | awk '{print $1}')"

if [[ "$IS_ADMIN" == "yes" ]]; then
    echo "INFO: $CURRENT_LOGGED_IN_USER is already an admin."
    # "$JAMF_HELPER_BIN" -windowType utility \
    #     -title "CompName Management Action" \
    #     -description "The user $CURRENT_LOGGED_IN_USER is already elevated. No action is required." \
    #     -icon "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/LockedIcon.icns" \
    #     -iconSize 32 \
    #     -button1 "Okay" \
    #     -defaultButton 1 &

    /usr/bin/osascript -e 'tell application "System Events" to display dialog "The user '"$CURRENT_LOGGED_IN_USER"' is already an administator on this Mac.\n\nIf this user does not have administrative rights, restart the system and try again." buttons {"Ok"} default button "Ok" with title "Make Me Admin" with icon file "System:Library:CoreServices:CoreTypes.bundle:Contents:Resources:Everyone.icns"'

    exit 0
fi


if [[ ! -f "$HAS_SEEN_FIRST_TIME_MESSAGE" ]]; then
    echo "INFO: Displaying first time message"
    # "$JAMF_HELPER_BIN" -windowType utility \
    #     -title "CompName Management Action" \
    #     -description "$FIRST_TIME_MESSAGE" \
    #     -icon "$PANIC_ICON" \
    #     -button1 "Okay" \
    #     -defaultButton 1

    /usr/bin/osascript -e 'tell application "System Events" to display dialog "'"$FIRST_TIME_MESSAGE"'" buttons {"Ok"} default button "Ok" with title "Make Me Admin" with icon file "System:Library:CoreServices:CoreTypes.bundle:Contents:Resources:Everyone.icns"'


    touch "$HAS_SEEN_FIRST_TIME_MESSAGE"
    chown "$CURRENT_LOGGED_IN_USER" "$HAS_SEEN_FIRST_TIME_MESSAGE"
fi

while true; do
    LOCAL_PASSWORD=$(/usr/bin/osascript -e 'tell application "System Events"' -e 'text returned of (display dialog "Make Me Admin needs your local account password to verify your identity.\n\nEnter the password for '$CURRENT_LOGGED_IN_USER' to elevate privileges." default answer "" buttons {"Quit","Elevate"} default button "Elevate" cancel button "Quit" with title "Make Me Admin" with hidden answer with icon file "System:Library:CoreServices:CoreTypes.bundle:Contents:Resources:FileVaultIcon.icns")' -e 'end tell')

    if [[ "$?" != "0" ]]; then
        echo "INFO: User chose to quit."
        exit 0
    fi

    /usr/bin/dscl . -authonly "$CURRENT_LOGGED_IN_USER" "$LOCAL_PASSWORD"

    if [[ "$?" != "0" ]]; then
        echo "ERROR: Incorrect password for $CURRENT_LOGGED_IN_USER"
        continue
    else
        echo "INFO: Password accepted."
        break
    fi

done

elevateToAdministrator
#------------------------------------------------------------------------------
# End Script
#------------------------------------------------------------------------------
echo "INFO: Done!"
exit 0
