#!/bin/sh
###############################################################################
# 
# 
#
# Author Name: Weinkauf, Chris
# Author Date: Sep 23 2019
# Purpose:
#
#
# Change Log:
# Sep 23 2019, UbiquitousChris
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
    /usr/bin/curl -sku "$APIUSERNAME:$APIPASSWORD" "${JPS_URL}uapi/auth/tokens" -X POST | grep token > /dev/null

    if [[ "$?" != "0" ]]; then
        echo "ERROR: Failed to connect to JPS. Check your credentials and URL and try again."
        exit 2
    fi
}

decodeHashedPassword()
{
    APIPASSWORD="$(echo "$APIPASSWORD" | base64 --decode --input - )"
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
            APIPASSWORD="$1"
            shift
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

# If we passed in an obfuscated password, decode it
decodeHashedPassword

#verify the connection
verifyConnection

#------------------------------------------------------------------------------
# Start Script
#------------------------------------------------------------------------------

AFFECTED_SYSTEMS=$(curl -sku "$APIUSERNAME:$APIPASSWORD" -H "accept: text/xml" ${JPS_URL}JSSResource/computerreports/id/100 | xmllint --xpath '/computer_reports/Computer/id' - | sed -e 's/<id>//g' | sed -e 's/<\/id>/ /g')
#-------------------------------------------------
# Detailed comment on a piece of code.
#-------------------------------------------------

echo "Unmanaging systems..."
for SYSTEM in $AFFECTED_SYSTEMS; do
    echo "Unmanaging $SYSTEM"

    curl -sku "$APIUSERNAME:$APIPASSWORD" --header 'content-type: application/xml' ${JPS_URL}JSSResource/computers/id/$SYSTEM --data "<computer><general><remote_management><managed>false</managed></remote_management></general></computer>" -X PUT

    echo "Done"
done
echo "Done unmanaging systems."

AFFECTED_SYSTEMS=$(curl -sku "$APIUSERNAME:$APIPASSWORD" -H "accept: text/xml" ${JPS_URL}JSSResource/computerreports/id/110 | xmllint --xpath '/computer_reports/Computer/id' - | sed -e 's/<id>//g' | sed -e 's/<\/id>/ /g')

echo "Removing systems..."
for SYSTEM in $AFFECTED_SYSTEMS; do
    echo "Removing $SYSTEM"

    curl -sku "$APIUSERNAME:$APIPASSWORD" --header 'content-type: application/xml' ${JPS_URL}JSSResource/computers/id/$SYSTEM -X DELETE

    echo "Done"
done
echo "Done removing systems."
#------------------------------------------------------------------------------
# End Script
#------------------------------------------------------------------------------
exit 0
