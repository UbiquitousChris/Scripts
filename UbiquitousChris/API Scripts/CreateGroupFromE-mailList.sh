#!/bin/sh
###############################################################################
# 
# 
#
# Author Name: Weinkauf, Chris
# Author Date: Dec 17 2018
# Purpose: Takes a file of e-mail addresses and builds a static user group on the
#           JPS
#
# Change Log:
# Dec 17 2018, UbiquitousChris
# - Initial Creation
###############################################################################

#-------------------
# Variables
#-------------------

SCRIPT_NAME=`basename $0`
SCRIPT_VERSION="1.0.0"

JAMF_PREFERENCES="/Library/Preferences/com.jamfsoftware.jamf.plist"

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

checkJPSuri()
{
    # If a server wasn't passed in, use the local one
    if [[ "$JPS_SERVER" == "" ]] && [[ -f "$JAMF_PREFERENCES" ]]; then
        JPS_SERVER="$(/usr/bin/defaults read "$JAMF_PREFERENCES" jss_url)"
    elif [[ "$JPS_SERVER" == "" ]] && [[ ! -f "$JPS_SERVER" ]]; then
        # If no local password was specified, ask for one
        while [[ "$API_PASSWORD" == "" ]]; do
            read -p "JPS URI(https://jpsuri.company.com:8443/):" JPS_SERVER
        done
    fi

    echo "INFO: JPS Server is $JPS_SERVER"
}

askForCredentails()
{
    # If a username was not passed in, ask for one
    while [[ "$API_USER" == "" ]]; do
        read -p "$JPS_SERVER Username:" API_USER
    done

    while [[ "$API_PASSWORD" == "" ]]; do
        read -s -p "$JPS_SERVER $API_USER/Password:" API_PASSWORD
    done

    echo "INFO: API_USER is $API_USER and API_PASSWORD has been specified"
}

getEmailAddressListFromInputFile()
{
    # Check for an input file
    if [[ "$INPUT_FILE" == "" ]]; then
        echo "ERROR: No input file was specified. Include an input file with --input"
        exit 10
    elif [[ ! -f "$INPUT_FILE" ]]; then
        echo "ERROR: Specified file $INPUT_FILE could not be found."
        exit 15
    fi

    EMAIL_LIST="$(cat "$INPUT_FILE" | sed "s/@/%40/g" )"

}

checkUserGroup()
{
    if [[ "$GROUP" == "" ]]; then
        echo "ERROR: No group was specified. Use --group to pass in a group name."
        exit 20
    fi

    # Get rid of spaces
    GROUP_URL="$(echo "$GROUP" | sed 's/ /%20/g')"

    GROUP_ID=$(curl -sku "$API_USER:$API_PASSWORD" -H "accept: text/xml" ${JPS_SERVER}JSSResource/usergroups/name/$GROUP_URL | xmllint --xpath '/user_group/id/text()' -)
    if [[ "$GROUP_ID" == "" ]]; then
        echo "INFO: Group not found. Attempting to create."

        curl -sku "$API_USER:$API_PASSWORD" -H "content-type: text/xml" ${JPS_SERVER}JSSResource/usergroups/id/0 -X POST -d "<user_group><name>$GROUP</name><is_smart>false</is_smart></user_group>"
        GROUP_ID=$(curl -sku "$API_USER:$API_PASSWORD" -H "accept: text/xml" ${JPS_SERVER}JSSResource/usergroups/name/$GROUP_URL | xmllint --xpath '/user_group/id/text()' -)
    fi

    if [[ "$GROUP_ID" != "" ]];then
        echo "INFO: Group was found or created with ID of $GROUP_ID"
    else
        echo "ERROR: Could not create the group"
        exit 25
    fi
}

compareUsersAgainstEmailList()
{
    for USER_EMAIL in $EMAIL_LIST; do
        echo "INFO: Checking $USER_EMAIL"
        USER_XML="$(curl -sku "$API_USER:$API_PASSWORD" -H "accept: text/xml" ${JPS_SERVER}JSSResource/users/email/$USER_EMAIL | xmllint --xpath '/users/user/id' - | sed 's/<id>/<user><id>/g' | sed 's/<\/id>/<\/id><\/user>/g')"

        if [[ "$USER_XML" != "" ]]; then
            USERS_TO_ADD+="$USER_XML"
        fi


    done
    clear
    echo "$USERS_TO_ADD"
}

postToGroup()
{
    FINAL_XML="<user_group><user_additions>$USERS_TO_ADD</user_additions></user_group>"

    curl -sku "$API_USER:$API_PASSWORD" -H "content-type: text/xml" ${JPS_SERVER}JSSResource/usergroups/id/$GROUP_ID -X PUT -d "$FINAL_XML"
}

main()
{
    checkJPSuri
    askForCredentails

    getEmailAddressListFromInputFile
    checkUserGroup
    compareUsersAgainstEmailList
    postToGroup
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
        --server | -s)
            shift
            JPS_SERVER="$1"
            shift
            ;;
        --user | -u)
            shift
            API_USER="$1"
            shift
            ;;
        --password | -p)
            shift
            API_PASSWORD="$1"
            shift
            ;;
        --input | -i)
            shift
            INPUT_FILE="$1"
            shift
            ;;
        --group | -g)
            shift
            GROUP="$1"
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

main

#-------------------------------------------------
# Detailed comment on a piece of code.
#-------------------------------------------------

#------------------------------------------------------------------------------
# End Script
#------------------------------------------------------------------------------
exit 0
