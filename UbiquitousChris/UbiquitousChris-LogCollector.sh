#!/bin/sh
###############################################################################
# 
# 
#
# Author Name: Weinkauf, Chris
# Author Date: Dec 07 2018
# Purpose: Package up the enrollment logs and upload them to the server
#
#
# Change Log:
# Dec 07 2018, UbiquitousChris
# - Initial Creation, based on the enrollment log collector
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

COLLECT_SYSTEM_LOGS="$6"
COLLECT_HOME_LOGS="$7"
COLLECT_SYSDIAGNOSE="$8"

API_URL="$(echo "$(/usr/bin/defaults read /Library/Preferences/com.jamfsoftware.jamf.plist jss_url)JSSResource")"
SERIAL_NUMBER="$(ioreg -c IOPlatformExpertDevice -d 2 | awk -F\" '/IOPlatformSerialNumber/{print $(NF-1)}')"
CURRENT_EPOCH="$(date "+%m%d%y%H%M%S")"
CURRENT_LOGGED_IN_USER=$(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }')

LOG_PACKAGE="logCollection-$SERIAL_NUMBER-$PACKAGE_TYPE-$CURRENT_EPOCH"
LOG_FOLDER="/var/tmp"
LOG_ZIP="$LOG_FOLDER/$LOG_PACKAGE.zip"

SYSTEM_LOG_LOCATIONS="/var/log
/Library/Logs"

HOME_LOG_LOCATIONS="Library/Logs"


#-------------------
# Functions
#-------------------

#------------------------------------------------------------------------------
# Start Script
#------------------------------------------------------------------------------
echo "INFO: API URL is $API_URL"
echo "INFO: System serial number is $SERIAL_NUMBER"
echo "INFO: API Username is $API_USERNAME"
echo "INFO: Current user is $CURRENT_LOGGED_IN_USER"

[[ "$COLLECT_HOME_LOGS" != "" ]] && echo "INFO: Home logs will be collected for current user"
[[ "$COLLECT_SYSTEM_LOGS" != "" ]] && echo "INFO: System logs will be collected"
[[ "$COLLECT_SYSDIAGNOSE" != "" ]] && echo "INFO: Sysdiagnose has been requested. Home/System logs will be submitted as part of Sysdiagnose"


echo "INFO: Getting computer ID"
JPS_ID="$(curl -sku "$API_USERNAME:$API_PASSWORD" $API_URL/computers/serialnumber/$SERIAL_NUMBER | xmllint -xpath '/computer/general/id/text()' -)"

if [[ "$JPS_ID" != "" ]]; then
    echo "INFO: JPS ID for $SERIAL_NUMBER is $JPS_ID"
else
    echo "ERROR: Failed to get JPS ID! Exiting."
    exit 10
fi

echo "INFO: Creating directory $LOG_FOLDER/$LOG_PACKAGE"
mkdir -p "$LOG_FOLDER/$LOG_PACKAGE"

if [[ "$?" != "0" ]]; then
    echo "ERROR: Could not create directory $LOG_FOLDER/$LOG_PACKAGE"
    exit 15
fi

if [[ "$COLLECT_SYSTEM_LOGS" != "" ]]; then
    echo "INFO: Gathering system logs"

    for ITEM_COPY in $SYSTEM_LOG_LOCATIONS; do
        echo "INFO: Gathering $ITEM_COPY"

        cp -Rf "$ITEM_COPY" "$LOG_FOLDER/$LOG_PACKAGE"

    done

fi


if [[ "$COLLECT_HOME_LOGS" != "" ]] && [[ "$CURRENT_LOGGED_IN_USER" != "" ]]; then
    echo "INFO: Collecting logs for $CURRENT_LOGGED_IN_USER"

    HOME_LOG_COPY="$LOG_FOLDER/$LOG_PACKAGE/Users/$CURRENT_LOGGED_IN_USER"

    mkdir -p "$HOME_LOG_COPY"

    HOME_DIRECTORY=$(dscl . -read Users/$CURRENT_LOGGED_IN_USER NFSHomeDirectory | awk '{print $2}' )
    echo "INFO: Home directory is $HOME_DIRECTORY"

    for ITEM_COPY in $HOME_LOG_LOCATIONS; do
        echo "INFO: Gathering $HOME_DIRECTORY/$ITEM_COPY"
        cp -Rf "$HOME_DIRECTORY/$ITEM_COPY" "$HOME_LOG_COPY"
    done

elif [[ "$COLLECT_HOME_LOGS" != "" ]] && [[ "$CURRENT_LOGGED_IN_USER" == "" ]]; then
    echo "WARN: No user is currently logged in so no home logs will be collected."
fi

echo "INFO: Done copying logs."

cd "$LOG_FOLDER"
zip -r "$LOG_ZIP" "$LOG_PACKAGE" -x "*.DS_Store"

if [[ "$?" != "0" ]]; then
    echo "ERROR: Failed to create zip file $LOG_ZIP"
    exit 25
fi


echo "$API_URL/fileuploads/computers/id/$JPS_ID"
/usr/bin/curl -sku "$API_USERNAME:$API_PASSWORD" $API_URL/fileuploads/computers/id/$JPS_ID -X POST -F name=@"$LOG_ZIP"

if [[ "$?" != "0" ]]; then
    echo "ERROR: Failed to upload enrollmentPackage"
    exit 30
fi

#------------------------------------------------------------------------------
# End Script
#------------------------------------------------------------------------------
exit 0
