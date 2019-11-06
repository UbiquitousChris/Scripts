#!/bin/zsh
###############################################################################
# 
# 
#
# Author Name: Weinkauf, Chris
# Author Date: Sep 18 2019
# Purpose:
#
#
# Change Log:
# Sep 18 2019, UbiquitousChris
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

API_USERNAME_B64="$4"
API_PASSWORD_B64="$5"

SERIAL_NUMBER="$(ioreg -c IOPlatformExpertDevice -d 2 | awk -F\" '/IOPlatformSerialNumber/{print $(NF-1)}')"
JPS_URL="$(/usr/bin/defaults read /Library/Preferences/com.jamfsoftware.jamf.plist jss_url)"



#-------------------
# Functions
#-------------------

getToken()
{
    TOKEN=$(/usr/bin/curl -sku "$APIUSERNAME:$APIPASSWORD" "${JPS_URL}uapi/auth/tokens" -X POST | grep token | awk '{print $3}' | tr -d ',' | tr -d '"')

    if [[ "$?" != "0" ]]; then
        echo "ERROR: Failed to connect to JPS. Check your credentials and URL and try again."
        exit 2
    fi
}

convertUsernameAndPassword()
{
    APIUSERNAME="$(echo "$API_USERNAME_B64" | base64 --decode - )"
    APIPASSWORD="$(echo "$API_PASSWORD_B64" | base64 --decode - )"
}

#------------------------------------------------------------------------------
# Start Script
#------------------------------------------------------------------------------

if [[ -z "$API_USERNAME_B64" ]] || [[ -z "$API_PASSWORD_B64" ]]; then
    echo "ERROR: API Username and Password must be passed in through parameters 4 and 5"
    exit 1
else
    echo "INFO: Converting and checking creds"
    convertUsernameAndPassword
    getToken
fi

/usr/bin/curl -s -X GET --header 'Accept: application/json' --header "Authorization: Bearer $TOKEN" "${JPS_URL}uapi/v1/computer-prestages/scope" | grep "$SERIAL_NUMBER" > /dev/null

if [[ "$?" == "0" ]]; then
    echo "INFO: Mac is ADE Capable."
    RESULT="Yes"
else
    echo "INFO: Mac is NOT ADE Capable."
    RESULT="No"
fi

echo "INFO: Updating Jamf Pro Server"
/usr/bin/curl -X PUT -su "$APIUSERNAME:$APIPASSWORD" --header 'content-type: application/xml' "${JPS_URL}JSSResource/computers/serialnumber/$SERIAL_NUMBER" -d "<computer><extension_attributes><extension_attribute><name>Automated Device Enrollment Capable</name><value>$RESULT</value></extension_attribute></extension_attributes></computer>"

echo 'INFO: Done!'
#------------------------------------------------------------------------------
# End Script
#------------------------------------------------------------------------------
exit 0
