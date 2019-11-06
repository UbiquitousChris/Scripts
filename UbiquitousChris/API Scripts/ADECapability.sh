#!/bin/sh
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
# Variables
#-------------------

SCRIPT_NAME=`basename "$0"`
SCRIPT_VERSION="1.0.0"

JPS_URL="$(/usr/bin/defaults read /Library/Preferences/com.jamfsoftware.jamf.plist jss_url)"

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
    echo "     -u, --username The username required to connect to the Jamf Pro API"
    echo "     -p, --password The password for the API user. This option is insecure and is disabled by default"
    echo " -a, -url, --jps-address  The URL for the JPS. Not required if connecting to the same JPS this Mac is enrolled in."
}

version()
{
    echo "${SCRIPT_VERSION}"
}

verifyConnection()
{
    TOKEN=$(/usr/bin/curl -sku "$APIUSERNAME:$APIPASSWORD" "${JPS_URL}uapi/auth/tokens" -X POST | grep token | awk '{print $3}' | tr -d ',' | tr -d '"')

    if [[ "$?" != "0" ]]; then
        echo "ERROR: Failed to connect to JPS. Check your credentials and URL and try again."
        exit 2
    fi
}


#-------------------
# Parse Arguments
#-------------------
while [ "$#" -gt "0" ]; do
    case "$1" in
        --help | -h | -\?)
            usage
            shift
            exit 0
            ;;
        --version)
            version
            shift
            exit 0
            ;;
        --username | -u)
            shift
            APIUSERNAME="$1"
            shift
            ;;
        --password | -p)
            echo "WARNING: Passing your password in via the command line is insecure."
            echo "WARNING: Uncomment the lines in the script to allow this."
            shift
            # APIPASSWORD="$1"
            # shift
            ;;
        --jps-address | -url | -a)
            shift
            JPS_URL="$1"
            shift
            ;;
        -*)
            echo "Unknown option: $1"
            exit -1
            ;;
        *)
            break
            ;;
    esac
done

#-------------------------------------------------
# Verify credentials passed in
#-------------------------------------------------
clear
echo "###################################################"
echo "# Starting $SCRIPT_NAME version $SCRIPT_VERSION"
echo "###################################################"

# Do we have a valid JPS url
if [[ -z "$JPS_URL" ]]; then
    echo "ERROR: No JPS URL was passed in or found on this system."
    echo "ERROR: Specify a url with -url"
    exit 1
else
    echo "Jamf Pro Server is $JPS_URL"
fi

# Did we get a username and password
while [[ -z "$APIUSERNAME" ]];do read -p "API User: " APIUSERNAME; done
while [[ -z "$APIPASSWORD" ]];do read -s -p "$APIUSERNAME Password: " APIPASSWORD; done

#verify the connection
verifyConnection

#------------------------------------------------------------------------------
# Start Script
#------------------------------------------------------------------------------
PRESTAGED_MACS=$(curl -s -X GET --header 'Accept: application/json' --header "Authorization: Bearer $TOKEN " 'https://jamf.example.com:8443/uapi/v1/computer-prestages/scope')

#| jq '. | .serialsByPrestageId.C02YK2QBJGH6'

#-------------------------------------------------
# Detailed comment on a piece of code.
#-------------------------------------------------
ALL_SERIAL_NUMBER=$(curl -sku "$APIUSERNAME:$APIPASSWORD" -H "accept: text/xml" ${JPS_URL}JSSResource/computers/subset/basic | xmllint --xpath '/computers/computer/serial_number' - | sed -e 's/<serial_number>//g' | sed -e 's/<\/serial_number>/,/g')

echo "serial,capable" > ADECapable.csv

IFS=$','
for SERIAL in $ALL_SERIAL_NUMBER; do
    RESULT=$(echo "$PRESTAGED_MACS" | jq ". | .serialsByPrestageId.$SERIAL")

    if [[ "$RESULT" != "null" ]]; then
        echo "$SERIAL,Yes" >> ADECapable.csv
    else
        echo "$SERIAL,No" >> ADECapable.csv
    fi

done
#------------------------------------------------------------------------------
# End Script
#------------------------------------------------------------------------------
exit 0
