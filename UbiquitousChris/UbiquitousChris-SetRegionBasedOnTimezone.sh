#!/bin/sh
###############################################################################
# 
# 
#
# Author Name: Weinkauf, Chris
# Author Date: June 25 2018
# Purpose: Sets the system's region key based on the currently configured Timezone
#
#
# Change Log:
# June 25 2018, UbiquitousChris
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

CURRENT_TIMEZONE="$(/usr/sbin/systemsetup -gettimezone | awk -F': ' '{print $2}')"
CURRENT_TIME_REGION="$(echo $CURRENT_TIMEZONE | awk -F'/' '{print $1}')"

#-------------------
# Functions
#-------------------

#------------------------------------------------------------------------------
# Start Script
#------------------------------------------------------------------------------

# Make sure the service folder exists at /Library/Example
if [[ ! -d "/Library/Example/" ]]; then
    echo "WARN: Example service folder is missing from /Library. Creating..."
    mkdir -p "/Library/Example/"

    echo "INFO: Service folder created. Fixing permissions..."
    chmod 755 "/Library/Example/"

    echo "INFO: Service folder has been created."
fi

echo "INFO: Current Timezone is $CURRENT_TIMEZONE"
echo "INFO: Current Time Region is $CURRENT_TIME_REGION"

# Set the region based on time region
case $CURRENT_TIME_REGION in
    "America" | "Antarctica" | "Arctic" | "US" )
        REGION="AMER"
        ;;
    "Africa" | "Europe" | "GMT" )
        REGION="EMEA"
        ;;
    "Asia" | "Australia" | "Indian" | "Pacific" )
        REGION="APAC"
        ;;
    *)
        REGION="UNK"
        ;;
esac

# Set the primary GEOReceipt key
echo "INFO: Setting GEOReceipt preference to show $REGION"
/usr/bin/defaults write /Library/Example/GEOReceipt.plist LocationInfo "$REGION"

# Check for errors
if [[ "$?" != "0" ]]; then
    echo "ERROR: Failed to set GEOReceipt preference."
    exit 10
fi

# Set the secondary GEOReceipt key
echo "INFO: Setting ImagingReceipt preference to show $REGION"
/usr/bin/defaults write /Library/Example/ImagingReceipt.plist LocationInfo "$REGION"

# Check for errors
if [[ "$?" != "0" ]]; then
    echo "ERROR: Failed to set ImagingReceipt preference."
    exit 15
fi

echo "INFO: Fixing permissions on plist files"
chmod +r /Library/Example/GEOReceipt.plist
chmod +r /Library/Example/ImagingReceipt.plist


#-------------------------------------------------
# Detailed comment on a piece of code.
#-------------------------------------------------

#------------------------------------------------------------------------------
# End Script
#------------------------------------------------------------------------------
exit 0
