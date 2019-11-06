#!/bin/sh
###############################################################################
# 
# 
#
# Author Name: Weinkauf, Chris
# Author Date: July 19 2018
# Purpose:
#
#
# Change Log:
# July 19 2018, UbiquitousChris
# - Initial Creation
###############################################################################

#-------------------
# Variables
#-------------------

SCRIPT_NAME=`basename $0`
SCRIPT_VERSION="1.0.0"

USER_NAME="$1"
PASSWORD="$2"
JPS_ADDRESS="$3"
CURRENT_CYCLE="$(date "+%B %Y")"
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

[[ "$USER_NAME" == "" ]] && read -p "API User: " USER_NAME
[[ "$PASSWORD" == "" ]] && read -s -p "API Password: " PASSWORD
[[ "$JPS_ADDRESS" == "" ]] && JPS_ADDRESS="$(defaults read /Library/Preferences/com.jamfsoftware.jamf.plist jss_url)"


ALL_IDS=$(curl -sku "$USER_NAME:$PASSWORD" ${JPS_ADDRESS}JSSResource/patchpolicies -H "accept: text/xml" | xmllint --xpath "//id" - | sed -e $'s/<\/id>/\\\n/g' | tr -d '<id>')

for POLICY_ID in $ALL_IDS; do

    # Pull the details for each policy
    POLICY_XML=$(curl -sku "$USER_NAME:$PASSWORD" ${JPS_ADDRESS}JSSResource/patchpolicies/id/$POLICY_ID -H "accept: text/xml")
    POLICY_NAME=$(echo "$POLICY_XML" | xmllint --xpath "/patch_policy/general/name/text()" -)
    POLICY_STATUS=$(echo "$POLICY_XML" | xmllint --xpath "/patch_policy/scope/all_computers/text()" -)
    POLICY_CYCLE=$(echo "$POLICY_NAME" | awk -F'-' '{print $2}' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')


    if [[ "$POLICY_CYCLE" == "$CURRENT_CYCLE" ]] && [[ "$POLICY_STATUS" == "false" ]]; then
        echo "Patch Policy $POLICY_ID is part of $CURRENT_CYCLE cycle but is NOT enabled for all users"
        UPDATED_XML="<patch_policy><scope><all_computers>true</all_computers><limit_to_users><user_groups/></limit_to_users></scope></patch_policy>"
        curl -sku "$USER_NAME:$PASSWORD" ${JPS_ADDRESS}JSSResource/patchpolicies/id/$POLICY_ID  -H "content-type: text/xml" -X PUT -d "$UPDATED_XML"

    elif [[ "$POLICY_CYCLE" == "$CURRENT_CYCLE" ]] && [[ "$POLICY_STATUS" == "true" ]]; then
        echo "Patch Policy $POLICY_ID is part of $CURRENT_CYCLE cycle and is enabled for all users"
        UPDATED_XML="<patch_policy><scope><all_computers>false</all_computers></scope></patch_policy>"
        curl -sku "$USER_NAME:$PASSWORD" ${JPS_ADDRESS}JSSResource/patchpolicies/id/$POLICY_ID  -H "content-type: text/xml" -X PUT -d "$UPDATED_XML"
    else
        echo "Patch Policy $POLICY_ID isn't part of the $CURRENT_CYCLE cycle"
    fi

done

#-------------------------------------------------
# Detailed comment on a piece of code.
#-------------------------------------------------

#------------------------------------------------------------------------------
# End Script
#------------------------------------------------------------------------------
exit 0
