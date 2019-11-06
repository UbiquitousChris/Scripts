#!/bin/zsh
###############################################################################
# 
# 
#
# Author Name: Weinkauf, Chris
# Author Date: Jul 08 2019
# Purpose: Grabs the currently assigned user settings from the JPS and adds them
#          to the user file.
#
# Change Log:
# Jul 08 2019, UbiquitousChris
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

API_USERNAME="$4"
API_PASSWORD="$5"
USER_CONFIG_FILE="$6"

JPS_URL="$(/usr/bin/defaults read /Library/Preferences/com.jamfsoftware.jamf.plist jss_url)"

SERIAL_NUMBER="$(ioreg -c IOPlatformExpertDevice -d 2 | awk -F\" '/IOPlatformSerialNumber/{print $(NF-1)}')"

#-------------------
# Functions
#-------------------

#------------------------------------------------------------------------------
# Start Script
#------------------------------------------------------------------------------

# Perform sanity checks
if [[ -z "$API_USERNAME" ]]; then
    echo "ERROR: No API username was passed"
    exit 1
else
    echo "INFO: Decrypting API username"
    API_USERNAME="$(echo "$API_USERNAME" | base64 --decode -)"

    if [[ "$?" != "0" ]]; then
        echo "ERROR: Could not decrypt username value"
        exit 4
    fi
fi

if [[ -z "$API_PASSWORD" ]]; then
    echo "ERROR: No API password was passed in"
    exit 2
else
    echo "INFO: Decrypting API password"
    API_PASSWORD="$(echo "$API_PASSWORD" | base64 --decode -)"

    if [[ "$?" != "0" ]]; then
        echo "ERROR: Could not decrypt password value"
        exit 4
    fi
fi

if [[ -z "$JPS_URL" ]]; then
    echo "ERROR: No JPS URL found. Check system enrollment"
    exit 3
fi

if [[ -z "$USER_CONFIG_FILE" ]]; then
    echo "WARN: User configuration plist was not passed in. Using default: /Library/Preferences/com.example.user.plist"
    USER_CONFIG_FILE="/Library/Preferences/com.example.user.plist"
fi

#-------------------------------------------------
# Report back inputs
#-------------------------------------------------
echo "INFO: API Username: $API_USERNAME"
echo "INFO: JPS URL: $JPS_URL"
echo "INFO: User configuration: $USER_CONFIG_FILE"
echo "INFO: Serial Number: $SERIAL_NUMBER"

echo "INFO: Getting data from JPS."
XML_DATA=$(curl -sku "$API_USERNAME:$API_PASSWORD" -H "accept: text/xml" ${JPS_URL}JSSResource/computers/serialnumber/$SERIAL_NUMBER)

if [[ "$?" != "0" ]]; then
    echo "ERROR: Failed to pull data from JPS."
    exit 7
fi

# Write out preferences based on response
echo "INFO: Writing out preference file."
/usr/bin/defaults write "$USER_CONFIG_FILE" username "$(echo $XML_DATA |  xmllint --xpath '/computer/location/username/text()' -)"
/usr/bin/defaults write "$USER_CONFIG_FILE" realname "$(echo $XML_DATA |  xmllint --xpath '/computer/location/realname/text()' -)"
/usr/bin/defaults write "$USER_CONFIG_FILE" email "$(echo $XML_DATA |  xmllint --xpath '/computer/location/email_address/text()' -)"
/usr/bin/defaults write "$USER_CONFIG_FILE" position "$(echo $XML_DATA |  xmllint --xpath '/computer/location/position/text()' -)"
/usr/bin/defaults write "$USER_CONFIG_FILE" phone "$(echo $XML_DATA |  xmllint --xpath '/computer/location/phone/text()' -)"
/usr/bin/defaults write "$USER_CONFIG_FILE" department "$(echo $XML_DATA |  xmllint --xpath '/computer/location/department/text()' -)"

echo "INFO: Setting proper permissions"
/usr/sbin/chown root:wheel "$USER_CONFIG_FILE"
/bin/chmod 644 "$USER_CONFIG_FILE"



#------------------------------------------------------------------------------
# End Script
#------------------------------------------------------------------------------
echo "INFO: Complete."
exit 0
