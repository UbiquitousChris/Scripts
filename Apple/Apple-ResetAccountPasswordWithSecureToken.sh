#!/bin/zsh
###############################################################################
# 
# 
#
# Author Name: Weinkauf, Chris
# Author Date: Aug 26 2019
# Purpose:
#
#
# Change Log:
# Aug 26 2019, UbiquitousChris
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

ACCOUNT_NAME_BASE64="$4"
ACCOUNT_PASSWORD_BASE64="$5"
ACCOUNT_OLD_PASSWORD_BASE64="$6"

#-------------------
# Functions
#-------------------

#------------------------------------------------------------------------------
# Start Script
#------------------------------------------------------------------------------

ACCOUNT_NAME="$(echo "$ACCOUNT_NAME_BASE64" | base64 --decode --input -)"
ACCOUNT_PASSWORD="$(echo "$ACCOUNT_PASSWORD_BASE64" | base64 --decode --input -)"
ACCOUNT_OLD_PASSWORD="$(echo "$ACCOUNT_OLD_PASSWORD_BASE64" | base64 --decode --input -)"

echo "INFO: Checking if new password is already set."
/usr/bin/dscl . -authonly "$ACCOUNT_NAME" "$ACCOUNT_PASSWORD"

if [[ "$?" == "0" ]]; then
    echo "INFO: Password is already set."
    exit 0
fi


echo "INFO: Changing password for account $ACCOUNT_NAME"
/usr/sbin/sysadminctl -resetPasswordFor "$ACCOUNT_NAME" -newPassword "$ACCOUNT_PASSWORD" -adminUser "$ACCOUNT_NAME" -adminPassword "$ACCOUNT_OLD_PASSWORD"

echo "INFO: Validating password change..."
/usr/bin/dscl . -authonly "$ACCOUNT_NAME" "$ACCOUNT_PASSWORD"

if [[ "$?" != "0" ]]; then
    echo "ERROR: Password update failed. Forcing change..."
    /usr/sbin/sysadminctl -resetPasswordFor "$ACCOUNT_NAME" -newPassword "$ACCOUNT_PASSWORD"

    /usr/bin/dscl . -authonly "$ACCOUNT_NAME" "$ACCOUNT_PASSWORD"

    if [[ "$?" != "0" ]]; then
        echo "FATAL: Failed to force password update!"
        exit 1
    fi

else
    echo "INFO: Password update successful!"
fi

#------------------------------------------------------------------------------
# End Script
#------------------------------------------------------------------------------
exit 0
