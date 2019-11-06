#!/bin/sh
###############################################################################
# 
# 
#
# Author Name: Weinkauf, Chris
# Author Date: Aug 19 2019
# Purpose:
#
#
# Change Log:
# Aug 19 2019, UbiquitousChris
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

getListOfIDs()
{
    LIST_URI="$1"
    LIST_XPATH="$2"

    /usr/bin/curl -sku "$APIUSERNAME:$APIPASSWORD" "${JPS_URL}JSSResource/$LIST_URI" -X GET | xmllint --xpath "$LIST_XPATH" - |  tr -d '<id>' | tr '//' '\n'
}

updateAllIDsInUse()
{
    LIST_URI="$1"
    LIST_XPATH="$2"
    ID_TO_CHECK="$3"

    XML_DATA="$(/usr/bin/curl -sku "$APIUSERNAME:$APIPASSWORD" "${JPS_URL}JSSResource/$LIST_URI/id/$ID_TO_CHECK" -X GET)"

    SCOPE_IDS=$( echo "$XML_DATA" | xmllint --xpath "/$LIST_XPATH/scope/computer_groups/computer_group/id" - |  tr -d '<id>' | tr '//' '\n')
    echo "INFO: Scope IDs: $SCOPE_IDS"
    EXCLUSION_IDS=$(echo "$XML_DATA" | xmllint --xpath "/$LIST_XPATH/scope/exclusions/computer_groups/computer_group/id" - |  tr -d '<id>' | tr '//' '\n')
    echo "INFO: EXCLUSION_IDS: $EXCLUSION_IDS"

    for S_ID in $SCOPE_IDS; do
        [[ $GROUPS_IN_USE =~ (^|[[:space:]])$S_ID($|[[:space:]]) ]] && continue
        GROUPS_IN_USE+="$S_ID "
    done

    for E_ID in $EXCLUSION_IDS; do
        [[ $GROUPS_IN_USE =~ (^|[[:space:]])$E_ID($|[[:space:]]) ]] && continue
        GROUPS_IN_USE+="$E_ID "
    done
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

ALL_GROUP_IDS=$(getListOfIDs "computergroups" "/computer_groups/computer_group/id")
ALL_POLICY_IDS=$(getListOfIDs "policies" "/policies/policy/id")
ALL_PATCH_IDS=$(getListOfIDs "patchpolicies" "/patch_policies/patch_policy/id")
ALL_CONFIG_PROFILES=$(getListOfIDs "osxconfigurationprofiles" "/os_x_configuration_profiles/os_x_configuration_profile/id")

for POLICY_ID in $ALL_POLICY_IDS; do
    updateAllIDsInUse "policies" "policy" "$POLICY_ID" &
    sleep 0.1
done

sleep 5

echo "LIST IF IDs in use:"
echo "$GROUPS_IN_USE"
#-------------------------------------------------
# Detailed comment on a piece of code.
#-------------------------------------------------

#------------------------------------------------------------------------------
# End Script
#------------------------------------------------------------------------------
exit 0
