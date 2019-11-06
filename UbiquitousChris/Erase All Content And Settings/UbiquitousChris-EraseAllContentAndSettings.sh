#!/bin/sh
###############################################################################
# 
# 
#
# Author Name: Weinkauf, Chris
# Author Date: Feb 12 2019
# Purpose: This will setup and configure the computer to erase all content and
#          settings.
#
# Change Log:
# Aug 12 2019, UbiquitousChris
# - Added password check verification
# Jun 19 2019, UbiquitousChris
# - Updated for use in Self Service
# Feb 12 2019, UbiquitousChris
# - Initial Creation
###############################################################################

#-------------------
# Variables
#-------------------

SCRIPT_NAME=`basename $0`
SCRIPT_VERSION="4.0.0"

REQUEST_VERSION="$4"
OS_INSTALLER="$5"
TECH_INSTALL=$6

ORIGINAL_INSTALLER_LOCATION="$OS_INSTALLER"

CURRENT_OS="$(/usr/bin/sw_vers -productVersion | awk -F. '{print $2}')"
CURRENT_LOGGED_IN_USER=$(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }')

REQUIRED_SPACE=16   # Disk space needed in GB

FULL_OS_VERSION=$(/usr/bin/sw_vers -productVersion)
#-------------------
# Functions
#-------------------

usage()
{
    echo "Usage: ${SCRIPT_NAME} [OPTIONS...] [ARGUMENTS]"
    echo ""
    echo "Short description of what this script does"
    echo ""
    echo "Options:"
    echo " -h, -?, --help     Display this help and exit"
    echo "         --version  Display version information and exit"
    echo ""
}

version()
{
    echo "${SCRIPT_VERSION}"
}

restoreInstaller()
{
    if [[ -d "$TEMPORARY_INSTALL_LOCATION" ]]; then
        echo "INFO: Restoring installer to original location."
        mv "$TEMPORARY_INSTALL_LOCATION" "$ORIGINAL_INSTALLER_LOCATION"
    fi
}

#------------------------------------------------------------------------------
# Start Script
#------------------------------------------------------------------------------

if [[ "$REQUEST_VERSION" == "" ]]; then
    REQUEST_VERSION="$CURRENT_OS"
fi

[[ -z "$TECH_INSTALL" ]] && TECH_INSTALL=false


echo "Requested version is 10.${REQUEST_VERSION}."
echo "Installer Location: $OS_INSTALLER"

if [[ "$TECH_INSTALL" == "false" ]]; then
    /usr/bin/osascript -e 'tell application "System Events" to display dialog "You are about to reinstall macOS 10.'$REQUEST_VERSION' on your Mac.\n\nALL CONTENT, SETTINGS, AND APP DATA WILL BE ERASED! YOU ARE RESPONSIBLE FOR BACKING UP YOUR DATA!\n\nAre you sure you want to continue?" buttons {"Quit","Continue"} cancel button "Quit" with title "Reset My Mac" with icon file "System:Library:CoreServices:CoreTypes.bundle:Contents:Resources:ErasingIcon.icns" giving up after (999999)'

    if [[ "$?" != "0" ]]; then
        echo "INFO: User chose to quit at backup dialog box."
        exit 0
    fi

    /usr/bin/osascript -e 'tell application "System Events" to display dialog "Have you backed up and verified your data?" buttons {"No","Yes"} cancel button "No" with title "Reset My Mac" with icon file "System:Library:CoreServices:CoreTypes.bundle:Contents:Resources:FileVaultIcon.icns" giving up after (999999)'

    if [[ "$?" != "0" ]]; then
        echo "INFO: User chose to quit at backup dialog box."
        exit 0
    fi

    while true; do
        LOCAL_PASSWORD=$(/usr/bin/osascript -e 'tell application "System Events"' -e 'text returned of (display dialog "Self Service wants access to reset your Mac. Your data will NOT be backed up as part of this process.\n\nTo reset this Mac, enter the password of any user on this Mac." default answer "" buttons {"Quit","Continue"} cancel button "Quit" with title "Reset My Mac" with hidden answer with icon file "System:Library:CoreServices:CoreTypes.bundle:Contents:Resources:ErasingIcon.icns" giving up after (86400))' -e 'end tell')

        if [[ "$?" != "0" ]]; then
            echo "INFO: User chose to quit at password prompt."
            #restoreInstaller
            exit 0
        fi

        for INDIVIDUAL_USER in $(dscl . -list Users UniqueID | awk '$2 > 500 {print $1}'); do
            /usr/bin/dscl . -authonly "$INDIVIDUAL_USER" "$LOCAL_PASSWORD" &> /dev/null

            if [[ "$?" != "0" ]]; then
                continue
            else
                echo "INFO: Password accepted."
                PASSWORD_ACCEPTED=true
                break
            fi
        done

        [[ "$PASSWORD_ACCEPTED" == 'true' ]] && break
        echo "INFO: Password did not match any accounts on the system."

    done

    /usr/bin/osascript -e 'tell application "System Events" to display dialog "Installation assets are downloading in the background. Depending on your Internet connection, this process may take an hour or more.\n\nWhile assets are downloading a preparing, Self Service will show either a Running or Executing status." buttons {"Okay"} with title "Reset My Mac" with icon file "System:Library:CoreServices:CoreTypes.bundle:Contents:Resources:ErasingIcon.icns" giving up after (999999)' &

    echo "INFO: Clearing ignored updates..."
    /usr/sbin/softwareupdate --reset-ignored

    echo "INFO: Grab full mac OS $FULL_OS_VERSION installer from Apple"
    /usr/sbin/softwareupdate --fetch-full-installer

    if [[ "$?" != "0" ]]; then
        echo "ERROR: Failed to download installer assets."
        /usr/bin/osascript -e 'tell application "System Events" to display dialog "Reset My Mac was unable to download installer assets.\n\nPlease try again later." buttons {"Quit"} default button "Quit" with icon file "System:Library:CoreServices:CoreTypes.bundle:Contents:Resources:AlertStopIcon.icns" giving up after (999999)'
        exit 1
    fi

fi


# Perform a check to make sure we have enough free space available.
echo "Checking free space on main volume..."
FREE_SPACE=$(df -g / | tail -1 | awk '{print $4}')

# If the amount of free space is less than the amount required, error out
if [[ $FREE_SPACE -lt $REQUIRED_SPACE ]]; then
    /usr/bin/osascript -e 'tell application "System Events" to display dialog "There is not enough free disk space to download installation assets.\n\nThere is '$FREE_SPACE' GB free while '$REQUIRED_SPACE' GB is required." buttons {"Quit"} default button "Quit" with icon file "System:Library:CoreServices:CoreTypes.bundle:Contents:Resources:AlertStopIcon.icns" giving up after (999999)'
    echo "ERROR: There is not enough free disk space to download assets. $FREE_SPACE GB free. $REQUIRED_SPACE GB required."
    exit 3
fi

echo "Verifying downloaded assets..."
if [[ -z "$OS_INSTALLER" ]] || [[ ! -d "$OS_INSTALLER" ]]; then
    /usr/bin/osascript -e 'tell application "System Events" to display dialog "An error occured while verifying the installation assets. The erase and install process cannot continue." buttons {"Quit"} default button "Quit" with icon file "System:Library:CoreServices:CoreTypes.bundle:Contents:Resources:AlertStopIcon.icns"'
    echo "ERROR: OS Installer is not where it's expected to be."
    exit 5
fi

/usr/bin/codesign --verify --no-strict "$OS_INSTALLER"

if [[ "$?" != "0" ]]; then
    /usr/bin/osascript -e 'tell application "System Events" to display dialog "An error occured while verifying the installation assets. The erase and install process cannot continue." buttons {"Quit"} default button "Quit" with icon file "System:Library:CoreServices:CoreTypes.bundle:Contents:Resources:AlertStopIcon.icns"'
    echo "ERROR: Codesign cannot verify the application bundle."
    rm -Rf "$TEMPORARY_INSTALL_LOCATION"
    exit 6
fi


echo "Gathering cached components"
COMPONENT_PKGS="$(ls -1 -d /Library/Application\ Support/JAMF/Waiting\ Room/*.pkg)"

OLD_IFS=$IFS
IFS=$'\n'

INSTALL_PKG_CMD=""

for PKG in $COMPONENT_PKGS; do
    echo "Adding $PKG"
    INSTALL_PKG_CMD+="--installpackage '$PKG' "
    sleep 0.1
done

SELF_SERVICE_PID="$(/usr/bin/pgrep "Self Service")"

if [[ ! -z "$SELF_SERVICE_PID" ]]; then
    echo "INFO: Adding Self Service PID $SELF_SERVICE_PID"
    INSTALL_PKG_CMD+="--pidtosignal $SELF_SERVICE_PID"
fi

echo "Preparing OS installation..."
eval "'$OS_INSTALLER/Contents/Resources/startosinstall' --agreetolicense --eraseinstall --newvolumename \"Macintosh HD\" --rebootdelay 5 $INSTALL_PKG_CMD"

if [ "$?" != "0" ]; then
    /usr/bin/osascript -e 'tell application "System Events" to display dialog "An error occured while preparing to reinstall macOS.\n\nThe erase and install process cannot continue." buttons {"Quit"} default button "Quit" with icon file "System:Library:CoreServices:CoreTypes.bundle:Contents:Resources:AlertStopIcon.icns"'
    echo "ERROR: Something went wrong preparing startosinstall. Restart the computer and try again."
    restoreInstaller
    exit 9
fi

#------------------------------------------------------------------------------
# End Script
#------------------------------------------------------------------------------
exit 0
