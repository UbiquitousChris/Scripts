#!/bin/zsh
###############################################################################
# 
# 
#
# Author Name: Weinkauf, Chris
# Author Date: Sep 05 2019
# Purpose:
#
#
# Change Log:
# Sep 05 2019, UbiquitousChris
# - Initial Creation
###############################################################################

#-------------------
# Variables
#-------------------

SCRIPT_NAME=`basename $0`
SCRIPT_VERSION="1.0.0"

CONSOLE_USER=$(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }')
HOME_DIRECTORY="$(/usr/bin/dscl . -read /Users/$CONSOLE_USER NFSHomeDirectory | awk '{print $2}' )"

YO='/Applications/Utilities/yo.app/Contents/MacOS/yo'

TENNANT_NAME="OneDrive - CompName"

ONEDRIVE_BIN="/Applications/OneDrive.app/Contents/MacOS/OneDrive"
ONEDRIVE_ICON='/Applications/OneDrive.app/Contents/Resources/OneDrive.icns'

COMPLETION_FLAG="$HOME_DIRECTORY/.hasSeenOneDriveSetup"
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

displayNotification()
{
    echo "INFO: Displaying notification."

    "$YO" --title 'You saved to a local location' \
        --info 'Save items to OneDrive so you can get to them if you lose your Mac.' \
        --icon "$ONEDRIVE_ICON" \
        --action-btn "Open" \
        --action-path "$HOME_DIRECTORY/OneDrive - CompName"
}

checkForOneDrive()
{
    if [[ -f "$ONEDRIVE_BIN" ]]; then
        echo "INFO: OneDrive is installed."
        return
    else
        echo "ERROR: OneDrive is not installed."
        exit 1
    fi
}

checkIfOneDriveIsLoggedIn()
{
    if [[ ! -d "$HOME_DIRECTORY/$TENNANT_NAME" ]]; then
        echo "ERROR: OneDrive is not signed in."
        exit 2
    else
        echo "INFO: OneDrive appears to be signed in."
        echo "INFO: OneDrive directory is $HOME_DIRECTORY/$TENNANT_NAME"
        return
    fi
}

initiailSetup()
{
    echo "INFO: Adding OneDrive folder to Dock."
    /usr/local/bin/dockutil --add "$HOME_DIRECTORY/$TENNANT_NAME" --view grid --display folder

    echo "NFO: Creating link on Desktop"
    /bin/ln -s "$HOME_DIRECTORY/$TENNANT_NAME" "$HOME_DIRECTORY/Desktop/$TENNANT_NAME"

    echo "INFO: Marking setup complete"
    /usr/bin/touch "$COMPLETION_FLAG"
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

echo "*** $SCRIPT_NAME $SCRIPT_VERSION ***"

if [[ "$CONSOLE_USER" == "" ]] || [[ "$CONSOLE_USER" == "extra_user" ]]; then
    echo "INFO: $CONSOLE_USER is exempt. Quitting."
    exit 0
else
    echo "INFO: Current user is $CONSOLE_USER with home directory $HOME_DIRECTORY"
fi

checkForOneDrive
checkIfOneDriveIsLoggedIn
[[ ! -f "$COMPLETION_FLAG" ]] && initiailSetup

displayNotification

#-------------------------------------------------
# Detailed comment on a piece of code.
#-------------------------------------------------

#------------------------------------------------------------------------------
# End Script
#------------------------------------------------------------------------------
exit 0
