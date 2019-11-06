#!/bin/sh
###############################################################################
# 
# 
#
# Author Name: Weinkauf, Chris
# Author Date: Mar 20 2018
# Purpose:
#
#
# Change Log:
# Mar 27 2019, UbiquitousChris
# - Converted from Package postinstall to standalone script
# Mar 20 2018, UbiquitousChris
# - Initial Creation
###############################################################################

###############################################################################
# Parse standard package arguments
###############################################################################

pathToScript=$0
pathToPackage=$1
targetLocation=$2
targetVolume=$3

###############################################################################
# Variables
###############################################################################

SERIAL_NUMBER="$(ioreg -c IOPlatformExpertDevice -d 2 | awk -F\" '/IOPlatformSerialNumber/{print $(NF-1)}')"
FORMATTED_SERIAL="$(echo $SERIAL_NUMBER | tr -dc '[:alnum:]\n\r' | tr '[:lower:]' '[:upper:]')"


###############################################################################
# Functions
###############################################################################


###############################################################################
# Start Script
###############################################################################

# If we don't get back a serial number, generate a random string for a name
if [ "$SERIAL_NUMBER" == "" ]; then
    echo "No serial number returned. Making one up for naming purposes."

    # Generate a random string with UUID
    RAN_STRING="$(uuidgen | tr -dc '[:alnum:]\n\r' | cut -c-10)"

    # Put together a nice fomratted
    FORMATTED_SERIAL="$(echo MAC$RAN_STRING)"

else
    # Found a serial number
    echo "Serial Number is $SERIAL_NUMBER"
fi

echo "Reformatted Serial Number is $FORMATTED_SERIAL"

echo "Setting computer name to $FORMATTED_SERIAL"
/usr/sbin/systemsetup -setcomputername "$FORMATTED_SERIAL"

# Perform on error check on t he scutil command
if [ "$?" != "0" ]; then
    echo "ERROR: Failed to set the ComputerName"
    exit 1
fi

echo "Setting host name to $FORMATTED_SERIAL"
/usr/sbin/scutil --set HostName "$FORMATTED_SERIAL"

# Perform on error check on t he scutil command
if [ "$?" != "0" ]; then
    echo "ERROR: Failed to set the HostName"
    exit 1
fi

echo "Setting bonjour name to $FORMATTED_SERIAL"
/usr/sbin/scutil --set LocalHostName "$FORMATTED_SERIAL"

# Perform on error check on t he scutil command
if [ "$?" != "0" ]; then
    echo "ERROR: Failed to set the LocalHostName"
    exit 1
fi

###############################################################################
# End Script
###############################################################################
exit 0
