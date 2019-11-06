#!/bin/zsh
###############################################################################
# 
# 
#
# Author Name: Weinkauf, Chris
# Author Date: May 25 2018
# Purpose: Allow a user to set region
#
#
# Change Log:
# Sep 20 2019, UbiquitousChris
# - Updated to use osascript instead of CocoaDialog and JamfHelper
# - Updated for macOS Catalina Compatibility
# June 25 2018, UbiquitousChris
# - Added logic to create /Library/Example if it doesn't exist
# May 25 2018, UbiquitousChris
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

EXT_REGION="$4"
REGION_PLIST="/Library/Preferences/com.example.system.plist"

#-------------------
# Functions
#-------------------

setRegion()
{
    echo "INFO: Setting region to $1"
    # Function to set the region to the passed in value
    /usr/bin/defaults write "$REGION_PLIST" DeviceRegion "$1"

    if [[ "$?" != "0" ]]; then
        echo "ERROR: Failed to set preferences"
        exit 20
    fi

    # Fix permissions on the file
    chmod 644 "$REGION_PLIST"

    if [[ "$?" != "0" ]]; then
        echo "ERROR: Failed to set permissions on preferences"
        exit 30
    fi
}

#------------------------------------------------------------------------------
# Start Script
#------------------------------------------------------------------------------

#-------------------------------------------------
# Detailed comment on a piece of code.
#-------------------------------------------------

# Make sure the service folder exists at /Library/Example
if [[ ! -d "/Library/Example/" ]]; then
    echo "WARN: Example service folder is missing from /Library. Creating..."
    mkdir -p "/Library/Example/"

    echo "INFO: Service folder created. Fixing permissions..."
    chmod 755 "/Library/Example/"

    echo "INFO: Service folder has been created."
fi

# Check if someone is logged in
LOGGED_IN_USER="$(who | grep console | awk '{print $1}')"

if [[ "$LOGGED_IN_USER" == "" ]] && [[ "$EXT_REGION" == "" ]]; then
    echo "ERROR: No region was passed in and nobody is logged in."
    exit 10
fi

# If a region was passed in externally
if [[ "$EXT_REGION" != "" ]]; then

    # Make sure the passed in value is uppercase
    EXT_REGION="$(echo $EXT_REGION | tr '[:lower:]' '[:upper:]')"

    case "$EXT_REGION" in
        "AMER")
        setRegion "AMER"
        ;;
        "EMEA")
        setRegion "EMEA"
        ;;
        "APAC")
        setRegion "APAC"
        ;;
        *)
        echo "ERROR: Invalid Region $EXT_REGION"
        exit 40
        ;;
    esac

    echo "INFO: Region set to $EXT_REGION successfully"
    exit 0
fi

# Check for the presense of the region preference
if [[ -f "$REGION_PLIST" ]]; then

    # Get the current region setting
    REGION="$(/usr/bin/defaults read "$REGION_PLIST" DeviceRegion)"


    # If its found, present the user with a dialog asking if they actually want
    # to do this

    /usr/bin/osascript -e 'tell applications "System Events" to display dialog "The region is already set to '"$REGION"' on this computer. Are you sure you want to change it?" buttons {"No","Yes"} default button "No" cancel button "No" with icon file "System:Library:CoreServices:CoreTypes.bundle:Contents:Resources:AlertCautionIcon.icns"'

    if [[ "$?" != "0" ]]; then
        echo "INFO: User chose to cancel."
        exit 0
    fi
fi

# Prompt the user to set the region
REGION=$(/usr/bin/osascript -e 'tell application "System Events" to choose from list {"Americas (AMER)", "Asia and the Pacific (APAC)", "Europe, Middle East, Africa (EMEA)"} with title "Region Selection" with prompt "Please select the region you are in:"')

if [[ "$?" != "0" ]]; then
    echo "INFO: User chose to cancel at region selection."
    exit 0
fi

REGION_SELECTION="$(echo $REGION | awk -F'[()]' '{print $2}')"
echo "REGION_SELECTION: $REGION_SELECTION"


case "$REGION_SELECTION" in
    "AMER")
    setRegion "AMER"
    ;;
    "EMEA")
    setRegion "EMEA"
    ;;
    "APAC")
    setRegion "APAC"
    ;;
    *)
    echo "ERROR: Invalid Region $REGION_SELECTION"
    exit 50
    ;;
esac

#------------------------------------------------------------------------------
# End Script
#------------------------------------------------------------------------------
exit 0
