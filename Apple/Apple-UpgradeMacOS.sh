#!/bin/zsh
###############################################################################
# 
# 
#
# Author Name: Weinkauf, Chris
# Author Date: Aug 12 2019
# Purpose:
#
#
# Change Log:
# Aug 12 2019, UbiquitousChris
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

INSTALLER_NAME="$4"
INSTALLER_LOCATION="$5"
SILENT_UPGRADE="$6"

REQUIRED_DISK_SPACE=13     # Required free space in GB

ORIGINAL_INSTALLER_LOCATION="$INSTALLER_LOCATION"

# Determine to system update in days
SYSTEM_START_TIME=$(sysctl -a |grep kern.boottime | awk '{print $5}' | rev | cut -c2- |rev)
CURRENT_EPOCH_TIME=$(date +%s)
UPTIME_EPOCH=$(($CURRENT_EPOCH_TIME-$SYSTEM_START_TIME))
UPTIME_DAYS=$(($UPTIME_EPOCH/86400))

FILEVAULT_STATUS="$(/usr/bin/fdesetup status | awk -F'= ' '{print $2}' | tr -d '[:space:]')"

TEMP_INSTALLER="/tmp/$(/usr/bin/uuidgen).app"

CURRENT_USER="$( scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }' )"
HOME_DIRECTORY="$(/usr/bin/dscl . -read /Users/$CURRENT_USER NFSHomeDirectory | awk '{print $2}')"

KNOWN_UNSUPPORTED_APPS=("com.vmware.fusion 11.5"
"com.parallels.desktop.console 15.0"
"com.bitrock.appinstaller 8.4")

REQUIRED_SUPPORT_PKGS=("00exampleMigrateToLocalUserAccount"
"JamfNoMADUninstaller"
"zzzExampleUpdateInventory"
"ExampleBrandingIcons")


#-------------------
# Functions
#-------------------

displayErrorMessage()
{
    if [[ "$SILENT_UPGRADE" != "true" ]]; then
        echo "INFO: Displaying error prompt to user."
        displayNotification "$1"
        /usr/bin/osascript -e 'tell application "System Events" to display dialog "The installation of macOS '"$INSTALLER_NAME"' could not be completed.\n\n'"$1"'\n\nFor further assistance, contact the Service Desk." buttons {"Okay"} default button 1 with icon file "System:Library:CoreServices:CoreTypes.bundle:Contents:Resources:AlertStopIcon.icns" with title "macOS Upgrade Failed" giving up after (86400)'
    else
        echo "INFO: Silent upgrade was specified. No error message will be displayed."
    fi

    #restoreInstaller
    exit $2
}

notifyUserOfLegacyApps()
{
    # If a forced upgrade is specified, skip notifying the user
    [[ "$SILENT_UPGRADE" == "true" ]] && return 0
    FORMATTED=""

    # Get the total number of legacy apps
    NUMBER_OF_LEGACY_APPS="$(wc -l "/Library/Application Support/CompName/LegacyApps.txt" | awk '{print $1}')"

    # Loop through the list of known unsupported app versions
    for i in $KNOWN_UNSUPPORTED_APPS; do
        RESULT_BNAME=$(eval "checkForUnsupportedVersionOfSoftware $i")


        if [[ "$?" != "0" ]]; then
            FORMATTED+="\"$RESULT_BNAME\","
            NUMBER_OF_LEGACY_APPS=$((NUMBER_OF_LEGACY_APPS+1))
        fi

    done


    if [[ $NUMBER_OF_LEGACY_APPS -eq 0 ]]; then
        echo "INFO: No legacy apps were found on this Mac"
        return 0
    else
        echo "INFO: There were $NUMBER_OF_LEGACY_APPS legacy apps found on this device."
    fi

    # Switch the IFS variable to consider newlines as separator
    OLDIFS=$IFS
    IFS=$'\n'

    # Format the list of legacy apps for the AppleScript list
    for LEGACYAPP in $(cat "/Library/Application Support/CompName/LegacyApps.txt"); do
        [[ -z "$LEGACYAPP" ]] && continue
        FORMATTED+="$(echo "\"$(basename $LEGACYAPP)\"",)"
    done

    displayNotification "Found $NUMBER_OF_LEGACY_APPS unsupported apps."

    # Switch to the original IFS separator
    IFS=$OLDIFS

    # Remove the trailing comma so osascript doesnt get all angry
    FORMATTED="$(echo $FORMATTED | awk '{$0=substr($0,1,length($0)-1); print $0}')"

    #echo "DEBUG: $FORMATTED"

    # Prompt the user with the list of legacy apps
    echo "INFO: Show prompt with list of apps."
    RESULT=$(/usr/bin/osascript -e 'with timeout of 86400 seconds' -e 'tell application "System Events"' -e 'choose from list {'"$FORMATTED"'} with prompt "The following apps installed on your Mac are not compatible with macOS 10.15 and will no longer run after upgrading. You should check with the software vendors if an update is available.\n\nIf you would like to continue the upgrade process, select one of the apps below and then click continue." OK button name {"Continue"} cancel button name {"Quit"} with title "Legacy App Compatibility Warning"' -e 'end tell' -e 'end timeout')

    if [[ "$?" != "0" ]]; then
        echo "ERROR: The compatibility warning window exited with a non-zero status."
        exit 56
    fi

    if [[ "$RESULT" == "false" ]]; then
        echo "INFO: User chose to quit at app compatibility dialog."
        #restoreInstaller
        exit 0
    fi

    # Because I dont believe the user actually looked at the previous dialog, force them to agree by entering their password.
    while true; do
        LOCAL_PASSWORD=$(/usr/bin/osascript -e 'tell application "System Events"' -e 'text returned of (display dialog "By continuing, you acknowledge that the legacy apps that were presented to you will no longer run after upgrading to macOS 10.15.\n\nEnter the password for '$CURRENT_USER' to continue upgrading to macOS 10.15." default answer "" buttons {"Quit","Continue"} cancel button "Quit" with title "Legacy App Compatibility Warning" with hidden answer with icon file "System:Library:CoreServices:CoreTypes.bundle:Contents:Resources:AlertCautionIcon.icns" giving up after (86400))' -e 'end tell')

        if [[ "$?" != "0" ]]; then
            echo "INFO: User chose to quit."
            #restoreInstaller
            exit 0
        fi

        /usr/bin/dscl . -authonly "$CURRENT_USER" "$LOCAL_PASSWORD"

        if [[ "$?" != "0" ]]; then
            echo "ERROR: Incorrect password for $CURRENT_USER"
            continue
        else
            echo "INFO: Password accepted."
            return 0
        fi

    done

}

checkForPower()
{
    [[ "$SILENT_UPGRADE" == "true" ]] && return

    echo "INFO: Checking for AC Power..."
    while [[ -z "$(/usr/bin/pmset -g batt | grep 'AC Power')" ]]; do
        echo "INFO: Mac is on battery power."
        displayNotification "Your Mac is using battery power. Please plug it in to continue."
        /usr/bin/osascript -e 'tell application "System Events" to display dialog "Your Mac is currently running on battery power. Plug in your power adaptor to continue." buttons {"Quit","Continue"} default button "Continue" cancel button "Quit" with title "AC Power" with icon file "System:Library:PreferencePanes:EnergySaver.prefPane:Contents:Resources:EnergySaver.icns" giving up after (86400)'

        if [[ "$?" != "0" ]]; then
            echo "INFO: User chose to quit."
            #restoreInstaller
            exit 1
        fi
    done
    echo "INFO: Mac is plugged in."
}

checkForUnsupportedVersionOfSoftware()
{
    APP_BUNDLE="$(mdfind "kMDItemCFBundleIdentifier == $1")"
    [[ -z "$APP_BUNDLE" ]] && return 0

    VERS=$(mdls -name kMDItemVersion -raw "$APP_BUNDLE" | awk -F. '{print $1"."$2}')

    echo "$(basename "$APP_BUNDLE")"

    if [[ $VERS -lt $2 ]]; then
        return 1
    else
        return 0
    fi
}

checkForSupportPackages()
{
    for PKG in $REQUIRED_SUPPORT_PKGS; do
        echo "INFO: Checking for support pkg $PKG"

        ls -1 "/Library/Application Support/JAMF/Waiting Room/" | grep -v xml | grep "$PKG" > /dev/null

        if [[ "$?" != "0" ]]; then
            echo "ERROR: Support package $PKG was not found. Installation cannot continue."
            displayErrorMessage "Required support packages are missing. Please try again later." 70
        fi

    done
}

displayNotification()
{
    [[ "$SILENT_UPGRADE" == "true" ]] && return
    '/Library/Application Support/JAMF/bin/Management Action.app/Contents/MacOS/Management Action' -title "MacOS Upgrade" -message "$1"
}

#------------------------------------------------------------------------------
# Start Script
#------------------------------------------------------------------------------

# If a pre-installation script found an issue, kill the installation
if [[ -f "/tmp/.doNotAllowUpgrade" ]]; then
    echo "ERROR: One or more requirements was not met."
    rm "/tmp/.doNotAllowUpgrade"
    exit 5
fi

if [[ -z "$INSTALLER_NAME" ]]; then
    echo "ERROR: No OS name was passed in through parameter 4"
    exit 3
fi

# Check for an installer file
if [[ -z "$INSTALLER_LOCATION" ]]; then
    echo "ERROR: An installer location was not passed in through parameter 5"
    displayErrorMessage "An installer location was not passed through parameter 5." 1
elif [[ ! -d "$INSTALLER_LOCATION" ]]; then
    echo "ERROR: An installer could not be found at the location specified in parameter 5"
    displayErrorMessage "Installation media was not found in the expected location." 2
else
    echo "INFO: Installer was found."
fi

# Verify the installation media
echo "INFO: Verifying installation media"
/usr/bin/codesign --verify --no-strict "$INSTALLER_LOCATION"

if [[ "$?" != "0" ]]; then
    echo "ERROR: Installation media could not be verified"
    rm -Rf "$INSTALLER_LOCATION"
    displayErrorMessage "The installation media could not be verified. It has been removed from this system. Please try the upgrade process again." 4
else
    echo "INFO: Installer media was verified successfully."
    displayNotification "Verified installation assets"
fi

checkForSupportPackages

# Create a local snapshot to roll back to if the upgrade fails
echo "INFO: Creating local snapshot..."
displayNotification "Creating a local restore snapshot..."
/usr/bin/tmutil localsnapshot
displayNotification "Snapshot created successfully..."

# Check the system uptime
echo "INFO: The system uptime is $UPTIME_DAYS days."
if [[ $UPTIME_DAYS -ge 7 ]] && [[ "$SILENT_UPGRADE" != "true" ]]; then
    echo "ERROR: The system uptime is too damn high! A reboot is required before proceeding."
    displayNotification "Your Mac needs to restart."
    # Prompt the user to reboot the system
    RESULT=$(/usr/bin/osascript -e 'tell application "System Events" to get button returned of (display dialog "Your Mac has been online for '"$UPTIME_DAYS"' days.\n\nTo ensure a smooth upgrade experience, you must restart your Mac before starting the upgrade process. Restart your Mac, then run this process again.\n\nWould you like to restart your Mac now?" buttons {"Restart Later","Restart Now"} default button 2 with icon file "Library:Application Support:JAMF:bin:jamfHelper.app:Contents:Resources:Restart.png" with title "macOS Upgrade" giving up after (86400))')

    if [[ "$RESULT" == "Restart Now" ]]; then
        echo "INFO: User has chosen to restart now. Triggering restart."
        #restoreInstaller
        /bin/launchctl reboot system
        exit 0
    else
        echo "INFO: User has chosen to restart later. Ending IPU process."
        #restoreInstaller
        exit 0
    fi

else
    echo "INFO: System uptime is within acceptable specifications. Proceeding."
fi

# Verify that enough space is present
FREE_SPACE=$(df -g / | tail -1 | awk '{print $4}')
if [[ $FREE_SPACE -lt $REQUIRED_DISK_SPACE ]]; then
    echo "ERROR: There isn't enough disk space available. At least $((FREE_SPACE-REQUIRED_SPACE))GB needs to be freed up"
    displayErrorMessage "There isn't enough disk space available. At least $((FREE_SPACE-REQUIRED_SPACE))GB of disk space is required to complete the upgrade." 5
else
    echo "INFO: Disk space requirements met: $FREE_SPACE GB available, $REQUIRED_DISK_SPACE GB required."
    displayNotification "Disk space requirements are met."
fi

# Check the status of FileVault and make sure we're not currently encrypting
if [[ "$FILEVAULT_STATUS" != "" ]]; then
    echo "Encryption is currently in progress. The upgrade cannot continue."
    displayErrorMessage "Full disk encryption is currently in progress." 6
else
    # If we're not encrypting, make a note and move forward
    echo "INFO: FileVault is not currently encrypting. Proceeding"
    displayNotification "Disk encryption requirements are met."
fi

if [[ $? == 0 ]]; then
    echo "INFO: Bomgar Representative Console was not found"
else
    echo "WARN: Bomgar Representative Console is installed"
    /usr/bin/osascript -e 'tell application "System Events" to display dialog "The upgrade process found the Bomgar Representative Console on your Mac which is not compatible with macOS 10.15.\n\nIf you choose to continue to upgrade, you can use the Bomgar Representative console web app as an alternative.\n\nAdditionally, you will not be able to initiate support sessions with computers running macOS 10.15.\n\nDo you want to continue the upgrade?" buttons {"No","Yes"} default button "No" cancel button "No" with title "Bomgar Representative Console" with icon file "System:Library:CoreServices:CoreTypes.bundle:Contents:Resources:AlertCautionIcon.icns"'

    [[ "$?" != "0" ]] && exit 0
fi

# Check for 32-bit and unsupported legacy apps
notifyUserOfLegacyApps
if [[ "$?" != "0" ]]; then
    #restoreInstaller
    exit 9
fi

checkForPower

IFS=$'\n'
ADDITIONAL_PKGS=""
for CACHE_PKG in $(ls -1d /Library/Application\ Support/JAMF/Waiting\ Room/* | grep -v xml); do
    echo "INFO: Attaching package $CACHE_PKG"
    ADDITIONAL_PKGS+="--installpackage '$CACHE_PKG' "
done

if [[ ! -z "$(pgrep "Self Service")" ]]; then
    echo "INFO: Attaching Self Service kill to command..."
    ADDITIONAL_PKGS+="--pidtosignal $(pgrep "Self Service") "
fi

#-------------------------------------------------
# Kick off OS installation
#-------------------------------------------------
echo "INFO: Starting installation of macOS $INSTALLER_NAME. This will take a while..."
displayNotification "Starting preparations for in-place upgrade. This may take a while..."
#eval "'$INSTALLER_LOCATION/Contents/Resources/startosinstall' --agreetolicense --rebootdelay 5 $ADDITIONAL_PKGS"

if [[ "$?" != "0" ]]; then
    echo "ERROR: Upgrade failed to start as expected."
    displayErrorMessage "The upgrade process returned an error." 20
else
    echo "INFO: Upgrade is prepared"
    displayNotification "The upgrade process is ready. Your Mac will restart now."
fi

#------------------------------------------------------------------------------
# End Script
#------------------------------------------------------------------------------
exit 0
