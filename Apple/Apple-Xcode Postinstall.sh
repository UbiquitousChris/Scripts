#!/bin/sh
###############################################################################
# 
# 
#
# Author Name: Weinkauf, Chris
# Author Date: Jan 16 2019
# Purpose: Performs post installation tasks to complete the install of Xcode
#
#
# Change Log:
# Sep 17 2019, UbiquitousChris
# - Updated for compatibility with macOS Catalina
# Jan 16 2019, UbiquitousChris
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


CURRENT_USER="$(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }')"

#-------------------
# Functions
#-------------------
showErrorMessage()
{
    ERR_MSG="$1"
    osascript -e 'tell application "System Events" to display dialog "'"$ERR_MSG"'" buttons {"Done"} default button 1 with icon file "System:Library:CoreServices:CoreTypes.bundle:Contents:Resources:AlertStopIcon.icns"' &
}
#------------------------------------------------------------------------------
# Start Script
#------------------------------------------------------------------------------

# Ask the user for the app they'd like to configure
XCODE_INSTALLATION=$(osascript -e 'tell application "System Events"' -e 'activate' -e 'POSIX path of(choose file with prompt "Select the Xcode application bundle you would like to configure.\nYou can use either a production or beta version of Xcode if your OS is able to support it." of type {"APP"} default location "/Applications")' -e 'end tell')

if [[ "$?" != "0" ]]; then
    echo "INFO: User chose to quit."
    exit 0
fi

# Verify that the user selected a valid copy of Xcode
if [[ "$(defaults read "${XCODE_INSTALLATION}/Contents/Info.plist" CFBundleIdentifier)" != "com.apple.dt.Xcode" ]]; then
    echo "ERROR: $XCODE_INSTALLATION is not Xcode"
    showErrorMessage "The selected application bundle does not appear to be a valid copy of Xcode. Please re-run the process and select Xcode.app or Xcode-beta.app."
    exit 5
fi


echo "INFO: Accepting the license on the users behalf."
${XCODE_INSTALLATION}/Contents/Developer/usr/bin/xcodebuild -license accept

if [[ "$?" != "0" ]]; then
    echo "ERROR: Failed to accept license"
    showErrorMessage "There was a problem accept the Xcode license agreement. Please restart your computer and try running this process again."
    exit 10
fi

# Enable developer mode
echo "INFO: Enabling developer mode"
/usr/sbin/DevToolsSecurity -enable

if [[ "$?" != "0" ]]; then
    echo "ERROR: Developer mode could not be enabled"
    showErrorMessage "There was a problem enabling developer mode on your Mac. Please restart your computer and try running this process again."
    exit 15
fi

# Install Components
for PACKAGE in ${XCODE_INSTALLATION}/Contents/Resources/Packages/*; do
    echo "Installing $PACKAGE"
    installer -pkg "$PACKAGE" -target /

    if [[ "$?" != "0" ]]; then
        echo "ERROR: There was a problem installing $PACKAGE"
        showErrorMessage "There was a problem installing one of the support packages. Please restart your computer and try running this process again."

        exit 20
    fi
done

echo "Info: Adding $CURRENT_USER to developer group"
/usr/sbin/dseditgroup -o edit -a "$CURRENT_USER" -t user _developer

if [[ "$?" != "0" ]]; then
    echo "ERROR: Could not add $CURRENT_USER to _developer group."
    showErrorMessage "There was a problem enabling developer mode on your Mac. Please restart your computer and try running this process again."
    exit 25
fi

#-------------------------------------------------
# Detailed comment on a piece of code.
#-------------------------------------------------

#------------------------------------------------------------------------------
# End Script
#------------------------------------------------------------------------------
exit 0
