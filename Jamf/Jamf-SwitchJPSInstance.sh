#!/bin/zsh
###############################################################################
# 
# 
#
# Author Name: Weinkauf, Chris
# Author Date: Jul 22 2019
# Purpose:
#
#
# Change Log:
# Jul 22 2019, UbiquitousChris
# - Initial Creation
###############################################################################

#-------------------
# Variables
#-------------------

SCRIPT_NAME=`basename $0`
SCRIPT_VERSION="1.0.0"

LOGGED_IN_USER=$(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }')
USER_HOME="$(/usr/bin/dscl . -read /Users/$LOGGED_IN_USER NFSHomeDirectory | awk -F': ' '{print $2}')"
JPS_PREFERENCE="$USER_HOME/Library/Preferences/com.jamfsoftware.jss.plist"
RECON_PREFERENCE="$USER_HOME/Library/Preferences/com.jamfsoftware.recon.plist"

DEV_SERVER="https://dev.example.com:8443/"
PROD_SERVER="https://jamf.example.com:8443/"

LIST_OF_APPS="Jamf Admin
Jamf Admin-Dev
Jamf Remote
Jamf Remote-Dev
Jamf Recon
Jamf Recon-Dev"
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

changeServer()
{
    SERVER="$1"
    /usr/bin/defaults write "$JPS_PREFERENCE" url "$SERVER"
    /usr/bin/defaults write "$RECON_PREFERENCE" server "$SERVER"
    echo "INFO: Server changed to $SERVER"
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
if type emulate >/dev/null 2>/dev/null; then emulate ksh; fi

if [[ -z "$LOGGED_IN_USER" ]]; then
    echo "ERROR: No user is logged in."
    exit 1
fi

CURRENT_SERVER="$(/usr/bin/defaults read "$JPS_PREFERENCE" url)"

if [[ -z "$CURRENT_SERVER" ]]; then
    echo "INFO: No JPS Server currently set. Will default to production."
else
    echo "INFO: Current server is $CURRENT_SERVER"
fi

IFS=$'\n'
for APP in $LIST_OF_APPS; do
    ps aux | grep "$APP" | grep -v grep > /dev/null
    if [[ "$?" == "0" ]]; then
        echo "INFO: Asking $APP to quit."
        osascript -e 'tell application "'"$APP"'" to quit'

        if [[ "$?" != "0" ]]; then
            echo "ERROR: Failed to quit $APP. Please manually quit and run again."
            exit 4
        fi
    fi
done

if [[ "$CURRENT_SERVER" == "$DEV_SERVER" ]]; then
    changeServer "$PROD_SERVER"
elif [[ "$CURRENT_SERVER" == "$PROD_SERVER" ]]; then
    changeServer "$DEV_SERVER"
else
    changeServer "$PROD_SERVER"
fi


#-------------------------------------------------
# Detailed comment on a piece of code.
#-------------------------------------------------

#------------------------------------------------------------------------------
# End Script
#------------------------------------------------------------------------------
exit 0
