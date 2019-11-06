#!/bin/sh
###############################################################################
# 
# 
#
# Author Name: Weinkauf, Chris
# Author Date: Mar 12 2019
# Purpose: Allows the jamfHelper to be called as a launch daemon
#
#
# Change Log:
# Mar 12 2019, UbiquitousChris
# - Initial Creation
###############################################################################

#-------------------
# Variables
#-------------------

SCRIPT_NAME=`basename $0`
SCRIPT_VERSION="1.0.0"

JAMF_HELPER="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"

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
        --preferences | -p)
            shift
            PREFERENCE_FILE="$1"
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

# Make sure jamfHelper is actually installed on this system
if [[ ! -f "$JAMF_HELPER" ]]; then
    echo "ERROR: jamfHelper is not installed."
    exit 1
fi

# If a preference file wasn't specified, look for the default
[[ "$PREFERENCE_FILE" == "" ]] && PREFERENCE_FILE="/tmp/jamfHelperPreferences.plist"

# If the preference file was not found, exit with an error
if [[ ! -f "$PREFERENCE_FILE" ]]; then
    echo "ERROR: A preference file must be specified with the --preferences or -p flag."
    exit 5
else
    echo "Jamf Helper Preferences: $PREFERENCE_FILE"
fi

# Read in preferences
WINDOW_TYPE="$(/usr/bin/defaults read "$PREFERENCE_FILE" windowType)"
WINDOW_POSITION="$(/usr/bin/defaults read "$PREFERENCE_FILE" windowPosition)"
WINDOW_TITLE="$(/usr/bin/defaults read "$PREFERENCE_FILE" title)"
HEADING="$(/usr/bin/defaults read "$PREFERENCE_FILE" heading)"
DESCRIPTION="$(/usr/bin/defaults read "$PREFERENCE_FILE" description)"
ICON_FILE="$(/usr/bin/defaults read "$PREFERENCE_FILE" icon)"
BUTTON1="$(/usr/bin/defaults read "$PREFERENCE_FILE" button1)"
BUTTON2="$(/usr/bin/defaults read "$PREFERENCE_FILE" button2)"
DEFAULT_BUTTON="$(/usr/bin/defaults read "$PREFERENCE_FILE" defaultButton)"
CANCEL_BUTTON="$(/usr/bin/defaults read "$PREFERENCE_FILE" cancelButton)"
SHOW_DELAY_OPTIONS="$(/usr/bin/defaults read "$PREFERENCE_FILE" showDelayOptions)"
ALIGN_DESCRIPTION="$(/usr/bin/defaults read "$PREFERENCE_FILE" alignDescription)"
ALIGN_HEADING="$(/usr/bin/defaults read "$PREFERENCE_FILE" alignHeading)"
ALIGN_COUNTDOWN="$(/usr/bin/defaults read "$PREFERENCE_FILE" alignCountdown)"
TIMEOUT="$(/usr/bin/defaults read "$PREFERENCE_FILE" timeout)"
COUNTDOWN="$(/usr/bin/defaults read "$PREFERENCE_FILE" countdown)"
ICON_SIZE="$(/usr/bin/defaults read "$PREFERENCE_FILE" iconSize)"
LOCK_HUD="$(/usr/bin/defaults read "$PREFERENCE_FILE" lockHUD)"
STARTLAUNCHD="$(/usr/bin/defaults read "$PREFERENCE_FILE" startLaunchd)"
FULL_SCREEN_ICON="$(/usr/bin/defaults read "$PREFERENCE_FILE" fullScreenIcon)"
SHUTDOWN_OR_RESTART="$(/usr/bin/defaults read "$PREFERENCE_FILE" ShutdownOrRestart)"

FULL_COMMAND="\"$JAMF_HELPER\" "

[[ "$WINDOW_TYPE" == "" ]] && FULL_COMMAND+="-windowType utility "
[[ "$WINDOW_TYPE" != "" ]] && FULL_COMMAND+="-windowType $WINDOW_TYPE "
[[ "$WINDOW_POSITION" != "" ]] && FULL_COMMAND+="-windowPosition $WINDOW_POSITION "
[[ "$WINDOW_TITLE" != "" ]] && FULL_COMMAND+="-windowPostion $WINDOW_POSITION "
[[ "$HEADING" != "" ]] && FULL_COMMAND+="-heading \"$HEADING\" "
[[ "$DESCRIPTION" != "" ]] && FULL_COMMAND+="-description \"$DESCRIPTION\" "
[[ "$ICON_FILE" != "" ]] && FULL_COMMAND+="-icon \"$ICON_FILE\" "
[[ "$BUTTON1" != "" ]] && FULL_COMMAND+="-button1 \"$BUTTON1\" "
[[ "$BUTTON2" != "" ]] && FULL_COMMAND+="-button2 \"$BUTTON1\" "
[[ "$DEFAULT_BUTTON" != "" ]] && FULL_COMMAND+="-defaultButton $DEFAULT_BUTTON "
[[ "$CANCEL_BUTTON" != "" ]] && FULL_COMMAND+="-cancelButton $CANCEL_BUTTON "
[[ "$SHOW_DELAY_OPTIONS" != "" ]] && FULL_COMMAND+="-showDelayOptions \"$SHOW_DELAY_OPTIONS\" "
[[ "$ALIGN_DESCRIPTION" != "" ]] && FULL_COMMAND+="-alignDescription $ALIGN_DESCRIPTION "
[[ "$ALIGN_HEADING" != "" ]] && FULL_COMMAND+="-alignHeading $ALIGN_HEADING "
[[ "$ALIGN_COUNTDOWN" != "" ]] && FULL_COMMAND+="-alignCountdown $ALIGN_COUNTDOWN "
[[ "$TIMEOUT" != "" ]] && FULL_COMMAND+="-timeout $TIMEOUT "
[[ "$COUNTDOWN" != "" ]] && FULL_COMMAND+="-countdown "
[[ "$ICON_SIZE" != "" ]] && FULL_COMMAND+="-iconSize $ICON_SIZE "
[[ "$LOCK_HUD" != "" ]] && FULL_COMMAND+="-lockHUD "
[[ "$STARTLAUNCHD" != "" ]] && FULL_COMMAND+="-startlaunchd "
[[ "$FULL_SCREEN_ICON" != "" ]] && FULL_COMMAND+="-fullScreenIcon "

echo "$FULL_COMMAND"
eval "$FULL_COMMAND"

if [[ "$SHUTDOWN_OR_RESTART" == "restart" ]]; then
    echo "Restart Requested"
    /bin/launchctl reboot
elif [[ "$SHUTDOWN_OR_RESTART" == "shutdown" ]]; then
    echo "Shutdown Requested"
    /bin/launchctl reboot halt
fi

















#-------------------------------------------------
# Detailed comment on a piece of code.
#-------------------------------------------------

#------------------------------------------------------------------------------
# End Script
#------------------------------------------------------------------------------
exit 0
