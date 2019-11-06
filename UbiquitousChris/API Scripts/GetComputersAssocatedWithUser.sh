#!/bin/sh
###############################################################################
# 
# 
#
# Author Name: Weinkauf, Chris
# Author Date: Jul 23 2019
# Purpose:
#
#
# Change Log:
# Jul 23 2019, UbiquitousChris
# - Initial Creation
###############################################################################

#-------------------
# Variables
#-------------------

SCRIPT_NAME=`basename "$0"`
SCRIPT_VERSION="0.1.0"

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
        --input | -i)
            shift
            INPUT_FILE="$1"
            shift
            ;;
        --output | -o)
            shift
            OUTPUT_FILE="$1"
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

if [[ -z "$INPUT_FILE" ]] || [[ ! -f "$INPUT_FILE" ]]; then
    echo "ERROR: Input file was not specified or found."
    exit 5
fi

if [[ -z "$OUTPUT_FILE" ]]; then
    echo "ERROR: Output file was not specified with -o."
    exit 6
fi

# Did we get a username and password
while [[ -z "$APIUSERNAME" ]];do read -p "API User: " APIUSERNAME; done
while [[ -z "$APIPASSWORD" ]];do read -s -p "$APIUSERNAME Password: " APIPASSWORD; done

#verify the connection
verifyConnection


#------------------------------------------------------------------------------
# Start Script
#------------------------------------------------------------------------------

echo "Username,Computer 1,Computer 2,Computer 3," > "$OUTPUT_FILE"


ALL_JPS_USERS=$(curl -sku "$APIUSERNAME:$APIPASSWORD" -H "accept: text/xml" ${JPS_URL}JSSResource/users | xmllint --format --xpath '/users/user/name' - | sed -e 's/<[^>]*>/ /g' | tr '[:upper:]' '[:lower:]' )

for IND_USER in $(cat "$INPUT_FILE" | tr '[:upper:]' '[:lower:]'); do
    for JPS_USR in $ALL_JPS_USERS; do
        if [[ "$JPS_USR" == "$IND_USER" ]]; then
            echo "${IND_USER},$(curl -sku "$APIUSERNAME:$APIPASSWORD" -H "accept: text/xml" ${JPS_URL}JSSResource/users/name/$JPS_USR | xmllint --xpath '/user/links/computers/computer/name' - | sed -e 's/<name>//g' | sed -e 's/<\/name>/,/g')" >> "$OUTPUT_FILE"
            break
        fi
    done

done

#-------------------------------------------------
# Detailed comment on a piece of code.
#-------------------------------------------------

#------------------------------------------------------------------------------
# End Script
#------------------------------------------------------------------------------
exit 0
