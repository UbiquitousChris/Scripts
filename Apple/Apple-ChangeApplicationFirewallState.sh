#!/bin/sh
###############################################################################
#
#
#
# Author Name: Weinkauf, Chris
# Author Date: Jan 21 2019
# Purpose: Turn the system firewall on or off
#
#
# Change Log:
# Mar 04 2019, UbiquitousChris
# - Added authorizationdb setting to allow all users to allow/deny items when
# - prompted by the OS
# Jan 21 2019, UbiquitousChris
# - Initial Creation
###############################################################################

#-------------------
# Parse standard package arguments
#-------------------
__TARGET_VOL="$1"
__COMPUTER_NAME="$2"
__USERNAME="$3"

#-------------------
# Variables
#-------------------

FIREWALL_STATE="$4"
SOCKETFILER_CMD="/usr/libexec/ApplicationFirewall/socketfilterfw"
ALF_PREFERENCES="/Library/Preferences/com.apple.alf"

APPS_TO_ALLOW="/usr/local/jamf/bin/jamf
/usr/local/jamf/bin/jamfAgent
/Library/Application Support/JAMF/Jamf.app
/Library/Application Support/JAMF/Jamf.app/Contents/MacOS/JamfAAD.app
/usr/libexec/emlog.pl
/Applications/Self Service.app
/Applications/ForeScout SecureConnector.app
/Applications/QualysCloudAgent.app
/usr/local/bin/simpana
/Applications/Confer.app"

OS_VERSION="$(/usr/bin/sw_vers -productVersion | awk -F. '{print $1"."$2}')"

#-------------------
# Functions
#-------------------

getCurrentFirewallState()
{
    # Get the current state of the firewall
    if [[ "$(/usr/bin/defaults read "$ALF_PREFERENCES" globalstate)" == "0" ]]; then
        CURRENT_STATE="off"
    elif [[ "$(/usr/bin/defaults read "$ALF_PREFERENCES" globalstate)" == "1" ]]; then
        CURRENT_STATE="on"
    else
        CURRENT_STATE="Unknown"
    fi
}

changeFirewallState()
{
    getCurrentFirewallState

    if [[ "$FIREWALL_STATE" == "$CURRENT_STATE" ]]; then
        echo "INFO: Firewall stare is alread $FIREWALL_STATE. No change required."
    else
        echo "INFO: Setting Firewall state to $FIREWALL_STATE"

        # Change the firewall state
        $SOCKETFILER_CMD --setglobalstate $FIREWALL_STATE

        if [[ "$?" != "0" ]]; then
            echo "ERROR: There was an error changing the firewall state."
            exit 10
        fi

        getCurrentFirewallState

        # If the state is not equal, we didn't actually change anything. Error out.
        if [[ "$FIREWALL_STATE" != "$CURRENT_STATE" ]]; then
            echo "ERROR: The state failed to change to the expected value of $FIREWALL_STATE"
            exit 15
        fi

    fi
}

configureFirewallDefaults()
{
    # Set the default firewall settings
    echo "INFO: Allowing built-in apps automatic access"
    "$SOCKETFILER_CMD" --setallowsigned on

    echo "INFO: Allowing signed apps automatic access"
    "$SOCKETFILER_CMD"  --setallowsignedapp on

    echo "INFO: Turning on stealth mode"
    "$SOCKETFILER_CMD"  --setstealthmode on

    if [[ "$OS_VERSION" != "10.13" ]]; then
      echo "INFO: Updating authorizationdb"
      /usr/bin/security authorizationdb write com.alf allow
    fi

}

addSpecifiedAppsToFirewall()
{
    OLD_IFS="$IFS"
    IFS=$'\n'

    # Add a list of specified built-in apps to the firewall settings
    for SPECIFIED_APP in $APPS_TO_ALLOW; do
        [[ ! -f "$SPECIFIED_APP" ]] && [[ ! -d "$SPECIFIED_APP" ]] && continue

        "$SOCKETFILER_CMD" --add "$SPECIFIED_APP"

        if [[ "$?" != "0" ]]; then
            echo "ERROR: Failed to add $SPECIFIED_APP to allow list"
            exit 20
        fi
    done
}

#------------------------------------------------------------------------------
# Start Script
#------------------------------------------------------------------------------

# If a firewall state change was passed in, change the state
[[ "$FIREWALL_STATE" != "" ]] && changeFirewallState

getCurrentFirewallState

if [[ "$CURRENT_STATE" == "on" ]]; then
    echo "INFO: Configuring Firewall defaults."
    configureFirewallDefaults
    addSpecifiedAppsToFirewall
else
    echo "INFO: Firewall is off. Will not alter defaults."
fi

echo "INFO: Firewall configuration complete."
#-------------------------------------------------
# Detailed comment on a piece of code.
#-------------------------------------------------

#------------------------------------------------------------------------------
# End Script
#------------------------------------------------------------------------------
exit 0
