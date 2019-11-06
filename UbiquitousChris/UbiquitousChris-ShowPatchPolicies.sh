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

echo ""
echo "INFO: Connecting to $JPS_ADDRESS as $USER_NAME"


ALL_IDS=$(curl -sku "$USER_NAME:$PASSWORD" ${JPS_ADDRESS}JSSResource/patchpolicies -H "accept: text/xml" | xmllint --xpath "//id" - | sed -e $'s/<\/id>/\\\n/g' | tr -d '<id>' | sort -nr)

for POLICY_ID in $ALL_IDS; do

    # Pull the details for each policy
    POLICY_XML=$(curl -sku "$USER_NAME:$PASSWORD" ${JPS_ADDRESS}JSSResource/patchpolicies/id/$POLICY_ID -H "accept: text/xml")
    POLICY_NAME=$(echo "$POLICY_XML" | xmllint --xpath "/patch_policy/general/name/text()" -)
    POLICY_STATUS=$(echo "$POLICY_XML" | xmllint --xpath "/patch_policy/scope/all_computers/text()" -)
    POLICY_VERSION=$(echo "$POLICY_XML" | xmllint --xpath "/patch_policy/general/target_version/text()" -)
    POLICY_TITLE=$(echo "$POLICY_XML" | xmllint --xpath "/patch_policy/software_title_configuration_id/text()" -)
    TITLE_NAME=$(curl -sku "$USER_NAME:$PASSWORD" ${JPS_ADDRESS}JSSResource/patchsoftwaretitles/id/$POLICY_TITLE -H "accept: text/xml" | xmllint --xpath "/patch_software_title/name/text()" - )
    POLICY_CYCLE=$(echo "$POLICY_NAME" | awk -F'-' '{print $2}' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')


    if [[ "$POLICY_CYCLE" == "$CURRENT_CYCLE" ]]; then
        echo "$TITLE_NAME $POLICY_VERSION"
        open -a "/Applications/Safari.app" "${JPS_ADDRESS}patchDeployment.html?id=$POLICY_ID&o=u"
    fi

done

#-------------------------------------------------
# Detailed comment on a piece of code.
#-------------------------------------------------

#------------------------------------------------------------------------------
# End Script
#------------------------------------------------------------------------------
exit 0
