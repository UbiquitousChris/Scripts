#!/bin/sh
###############################################################################
# 
# 
#
# Author Name: Weinkauf, Chris
# Author Date: Feb 05 2019
# Purpose:
#
#
# Change Log:
# Feb 05 2019, UbiquitousChris
# - Initial Creation
###############################################################################

#-------------------
# Variables
#-------------------

SCRIPT_NAME=`basename $0`
SCRIPT_VERSION="1.0.0"

TOTAL_REMOVED=0
TOTAL_COUNT=0

#-------------------
# Functions
#-------------------
checkScriptArguments()
{

    # If a URL was not passed in, attempt to pull from the local machine
    if [[ "$JAMF_PRO_URL" == "" ]]; then
        echo "Jamf Pro URL was not specified. Attempting to get URL from local preferences."
        JAMF_PRO_URL="$(/usr/bin/defaults read "/Library/Preferences/com.jamfsoftware.jamf.plist" jss_url)"

        # If we couldn't pull from a local machine, error out
        if [[ "$?" != "0" ]]; then
            echo "ERROR: Jamf Pro URL needs to be specified with --jamfAddress"
            exit 10
        fi
    fi

    # If a username or password wasnt passed in, request it
    [[ "$API_USERNAME" == "" ]] && read -p "API Username: " API_USERNAME
    [[ "$API_PASSWORD" == "" ]] && read -s -p "API Password: " API_PASSWORD
}

usage()
{
    echo "Usage: ${SCRIPT_NAME} [OPTIONS...] [ARGUMENTS]"
    echo ""
    echo "Short description of what this script does"
    echo ""
    echo "Options:"
    echo " -h, -?, --help     Display this help and exit"
    echo "         --version  Display version information and exit"
    echo ""
}

version()
{
    echo "${SCRIPT_VERSION}"
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
        --apiUser | -u)
            shift
            API_USERNAME="$1"
            shift
            ;;
        --apiPassword | -p)
            shift
            API_PASSWORD="$1"
            shift
            ;;
        --jamfAddress | -url)
            shift
            JAMF_PRO_URL="$1"
            shift
            ;;
        --dryrun | -d)
            echo "Dry Run specified."
            DRYRUN="true"
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

#------------------------------------------------------------------------------
# Start Script
#------------------------------------------------------------------------------

checkScriptArguments

BACKUP_DIRECTORY="./PolicyBackups/$(date)"

[[ ! -d "$BACKUP_DIRECTORY" ]] && mkdir -p "$BACKUP_DIRECTORY"

ALL_POLICY_IDS="$(curl -sku "$API_USERNAME:$API_PASSWORD" -H "accept: text/xml" ${JAMF_PRO_URL}JSSResource/policies | xmllint --xpath '/policies/policy/id' - | tr -d '<id>' | tr '//' ' ')"

for POLICY_ID in $ALL_POLICY_IDS; do
    POLICY_DATA="$(curl -sku "$API_USERNAME:$API_PASSWORD" -H "accept: text/xml" ${JAMF_PRO_URL}JSSResource/policies/id/$POLICY_ID)"

    POLICY_ENABLED="$(echo "$POLICY_DATA" | xmllint --xpath '/policy/general/enabled/text()' -)"
    POLICY_TITLE="$(echo "$POLICY_DATA" | xmllint --xpath '/policy/general/name/text()' -)"

    if [[ "$POLICY_ENABLED" == "true" ]]; then
        echo "Policy '$POLICY_TITLE($POLICY_ID)' is enabled."
    else
        echo "Policy '$POLICY_TITLE($POLICY_ID)' is disabled and will be deleted."

        SAFE_FILE_NAME="$(echo "$POLICY_TITLE" | tr '/' '-')"
        echo "$POLICY_DATA" | xmllint --format - > "$BACKUP_DIRECTORY/$POLICY_ID-$SAFE_FILE_NAME.xml"
        
        [[ "$DRYRUN" != "true" ]] && curl -sku "$API_USERNAME:$API_PASSWORD" -H "content-type: text/xml" ${JAMF_PRO_URL}JSSResource/policies/id/$POLICY_ID -X DELETE > /dev/null
        TOTAL_REMOVED=$((TOTAL_REMOVED+1))
    fi

    echo "$POLICY_TITLE" | egrep 'maX|X|X' > /dev/null

    if [[ "$?" == "0" ]]; then
        echo "Policy '$POLICY_TITLE($POLICY_ID) is a Jamf remote policy and will be removed. "
        [[ "$DRYRUN" != "true" ]] && curl -sku "$API_USERNAME:$API_PASSWORD" -H "content-type: text/xml" ${JAMF_PRO_URL}JSSResource/policies/id/$POLICY_ID -X DELETE > /dev/null
        TOTAL_REMOVED=$((TOTAL_REMOVED+1))
    fi

    TOTAL_COUNT=$((TOTAL_COUNT+1))
done

echo "Run completed!"
echo "Total Count: $TOTAL_REMOVED of $TOTAL_COUNT policies removed!"
#-------------------------------------------------
# Detailed comment on a piece of code.
#-------------------------------------------------

#------------------------------------------------------------------------------
# End Script
#------------------------------------------------------------------------------
exit 0
