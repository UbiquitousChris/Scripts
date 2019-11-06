#!/bin/sh
###############################################################################
# 
# 
#
# Author Name: Weinkauf, Chris
# Author Date: Aug 01 2018
# Purpose: Configures the network time servers used to sync time with
#          Active Directory
#
# Change Log:
# Aug 01 2018, UbiquitousChris
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

TIME_SERVERS="$4"
TIME_SERVER_STATUS="$(/usr/sbin/systemsetup -getusingnetworktime | awk -F': ' '{print $2}')"
NTP_CONFIG="/etc/ntp.conf"
COUNT=0

#-------------------
# Functions
#-------------------

#------------------------------------------------------------------------------
# Start Script
#------------------------------------------------------------------------------
echo "INFO: Starting network time configuration at $(date)"

if [[ "$TIME_SERVERS" == "" ]]; then
    echo "ERROR: No timeservers were passed in!"
    exit 1
fi

# Check for the presense of the network time configuration. Reset if found.
if [[ -f "$NTP_CONFIG" ]]; then
    echo "INFO: Network time configuration present. Removing."
    rm "$NTP_CONFIG"
    touch "$NTP_CONFIG"
fi

# Loop through all the passed in servers
for SERVER in $TIME_SERVERS; do
    # If we're working with the first server passed in, make it the primary
    if [[ $COUNT == 0 ]]; then
        echo "INFO: Adding primary time server $SERVER"
        /usr/sbin/systemsetup -setnetworktimeserver "$SERVER"
        # Set the count switch to 1 so all other server get set as alternatives
        COUNT=1

        # Call ntpdate to attempt to force an update from the primary server
        # Skip if ntpdate is not present (10.14+)
        [[ -f "/usr/sbin/ntpdate" ]] && echo "INFO: Forcing an update from time server $SERVER"
        [[ -f "/usr/sbin/ntpdate" ]] && /usr/sbin/ntpdate -u "$SERVER"

        # Sleep for a few seconds to let the system catch up
        sleep 1
    else
        # The count switch was set to 1, so this server is an alternative
        echo "INFO: Adding backup time server $SERVER"
        # Add the server to the NTP config file
        echo "server $SERVER" >> "$NTP_CONFIG"
    fi
done
echo "INFO: Time Servers have been set successfully."

# If network time was not turned on for some reason, do that now
if [[ "$TIME_SERVER_STATUS" == "Off" ]]; then
    echo "INFO: Enabling network time servers"
    /usr/sbin/systemsetup -setusingnetworktime on
fi

echo "INFO: Network time configuration completed at $(date)"

#------------------------------------------------------------------------------
# End Script
#------------------------------------------------------------------------------
exit 0
