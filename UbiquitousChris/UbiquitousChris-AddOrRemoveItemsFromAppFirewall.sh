#!/bin/zsh
###############################################################################
# 
# 
#
# Author Name: Weinkauf, Chris
# Author Date: Jan 28 2019
# Purpose: Script to allow the user to add and remove items from the application
#          firewall through Self Service
#
# Change Log:
# Jun 12 2019, UbiquitousChris
# - Updated for compatibility with macOS Catalina
# Jan 28 2019, UbiquitousChris
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

PERMANENT_WHITELIST=(/usr/local/jamf/bin/jamf
/usr/local/jamf/bin/jamfAgent
/usr/local/bin/simpana
/usr/local/bin/cvpkgcheck
/usr/local/bin/cvpkgchg
/usr/local/bin/cvpkgrm
com.jamfsoftware.selfservice.mac
com.jamf.management.Jamf
com.jamf.management.jamfAAD
com.jamfsoftware.selfservice.mac
com.forescout.secure_connector
com.qualys.cloud-agent
CbDefense
com.apple.AppStore
com.citrix.receiver.nomas
com.microsoft.CompanyPortal
com.Example.osx.hcpaw.HCP-Anywhere
com.microsoft.Excel
com.microsoft.onenote.mac
com.microsoft.Outlook
com.microsoft.Powerpoint
com.microsoft.rdc.macos
com.microsoft.teams
com.microsoft.Word
com.trusourcelabs.NoMAD
com.microsoft.OneDrive
com.commvault.processmanager
com.microsoft.SkypeForBusiness
com.vmware.fusion
us.zoom.xos
/opt/Simpana/
/opt/cisco/
com.cisco.Cisco-AnyConnect-Secure-Mobility-Client
com.cisco.pkg.anyconnect.dart)

#-------------------
# Functions
#-------------------

#-------------------------------------------------
# Extracts the filename and extension from the selected
# file for use in prompts
#-------------------------------------------------
determineFileNameAndExtension()
{
    INSTALLER_OR_APP=$(basename -- "$SPECIFIED_APP")
    FILE_EXTENSION="${INSTALLER_OR_APP##*.}"
    FILE_NAME="${INSTALLER_OR_APP%.*}"
}

#-------------------------------------------------
# Scans the whitelist variable to make sure the selected
# item isn't being managed by 
#-------------------------------------------------
checkPermanentWhitelist()
{
    foreach WL_ITEM ($PERMANENT_WHITELIST); do
        echo "INFO: Checking item against $WL_ITEM"
        if [[ "$WL_ITEM" == "$BUNDLE_IDENTIFIER" ]] || [[ "$SPECIFIED_APP" =~ "$WL_ITEM" ]]; then
            showErrorMessage "The firewall settings for $FILE_NAME cannot be altered because they are being managed by CompName.\n\nIf you have a specific business case for changing the settings of '$FILE_NAME', contact the Service Desk."
            exit 60
        fi
    done
}

#-------------------------------------------------
# Shows an AppleScript choose file dialog to the user
#-------------------------------------------------
selectAnApplicationOrBinary()
{
    # Prompt with AppleScript to select an executable file
    SPECIFIED_APP=$(osascript -e 'tell application "Self Service"' -e 'POSIX path of(choose file with prompt "Select an application or binary:" of type {"APP","APPL","public.unix-executable","public.shell-script","public.python-script","public.ruby-script","public.perl-script"})' -e 'end tell')

    # If the user doesnt pick a valid file, quit gracefully.
    if [[ "$?" != "0" ]]; then
        echo "INFO: User chose to quit."
        exit 0
    else

        TEMP_APP_STORAGE="$(echo "$SPECIFIED_APP" | rev)"
        # Remove the trailing slash if its an app bundle
        if [[ "$(echo "$TEMP_APP_STORAGE" | cut -c1)" == "/" ]]; then
            SPECIFIED_APP="$(echo "$TEMP_APP_STORAGE" | cut -c2- | rev )"
        fi
        echo "INFO: User selected $SPECIFIED_APP"
        determineFileNameAndExtension

        if [[ "$FILE_EXTENSION" == "app" ]]; then
            BUNDLE_IDENTIFIER="$(defaults read "$SPECIFIED_APP/Contents/Info.plist" CFBundleIdentifier)"
            echo "INFO: App bundle identifer is $BUNDLE_IDENTIFIER"
        fi

        checkPermanentWhitelist
    fi
}

#-------------------------------------------------
# Show an info prompt the user.
# Accepts one input:
# MSG_PROMPT: String with the human readble prompt for the user
#-------------------------------------------------
showInforPrompt()
{
    MSG_PROMPT="$1"
    echo "INFO: Displaying info prompt to user."
    echo "INFO: PROMPT: $MSG_PROMPT"
    osascript -e 'tell application "Self Service"' -e 'display dialog "'"$MSG_PROMPT"'" buttons {"Done"} default button 1 with icon note' -e 'end tell' &
}

#-------------------------------------------------
# Show an error prompt the user.
# Accepts one input:
# ERR_MSG: String with the human readble error for the user
#-------------------------------------------------
showErrorMessage()
{
    ERR_MSG="$1"
    echo "ERROR: Displaying error prompt to user."
    echo "ERROR: PROMPT: $ERR_MSG"
    osascript -e 'tell application "Self Service"' -e 'display dialog "'"$ERR_MSG"'" buttons {"Done"} default button 1 with icon stop' -e 'end tell' &
}

#-------------------------------------------------
# Show a yes/no prompt tho a user.
# Accepts one input:
# VERIFICATION_MSG: String with the question for the user
#-------------------------------------------------
showVerificationMessage()
{
    VERIFICATION_MSG="$1"
    echo "INFO: Requesting verification from user."
    RESULT=$(osascript -e 'tell application "Self Service"' -e 'button returned of (display dialog "'"$VERIFICATION_MSG"'" buttons {"No","Yes"} default button 1 with icon file "System:Library:CoreServices:CoreTypes.bundle:Contents:Resources:ConnectToIcon.icns")' -e 'end tell')

    if [[ "$RESULT" == "No" ]]; then
        echo "INFO: The user chose not to continue."
        showInforPrompt "No changes were applied to the application firewall.\n\nContact the Service Desk if you need assistance."
        exit 0
    fi

}

#-------------------------------------------------
# This function handles the changing of an items
# status in the firewall. Accepts one input:
# STATUS
# unblockapp = Allow App
# blockapp = Block app
# remove = Remove from firewall
#-------------------------------------------------
changeStatus()
{
    # unblockapp = Allow App
    # blockapp = Block app
    # remove = Remove from firewall
    STATUS="$1"

    [[ "$STATUS" == "unblockapp" ]] && HUMAN_READABLE_STATUS="allow"
    [[ "$STATUS" == "blockapp" ]] && HUMAN_READABLE_STATUS="block"
    [[ "$STATUS" == "remove" ]] && HUMAN_READABLE_STATUS="remove"

    if [[ "$STATUS" == "remove" ]]; then
        showVerificationMessage "You're about to remove '$FILE_NAME' from the firewall app list.\n\nCommunication will no longer be explicitly allowed or denied to this application or executable. The OS will attempt to determine the best firewall settings.\n\nAre you sure you want to continue?"
    elif [[ "$STATUS" == "remove" ]]; then
        showVerificationMessage "You're about to explicitly $HUMAN_READABLE_STATUS communication to '$FILE_NAME' through the application firewall. This will prevent all inbound communication to '$FILE_NAME' and may prevent it from functioning properly.\n\nAre you sure you want to do this?"
    else
        showVerificationMessage "You're about to explicitly $HUMAN_READABLE_STATUS communication to '$FILE_NAME' through the application firewall.\n\nAre you sure you want to do this?"
    fi

    /usr/libexec/ApplicationFirewall/socketfilterfw --$STATUS "$SPECIFIED_APP"

    if [[ "$?" != "0" ]]; then
        echo "ERROR: The script was unable to $STATUS $SPECIFIED_APP"
        showErrorMessage "There was a problem attempting to $STATUS '$FILE_NAME'.\n\nContact the Service Desk for assistance."
        exit 40
    fi

}

#-------------------------------------------------
# Function to check if the app is on the blocked list
#-------------------------------------------------
checkIfAppIsBlocked()
{
    /usr/libexec/ApplicationFirewall/socketfilterfw --getappblocked "$SPECIFIED_APP" | grep "blocked" > /dev/null

    if [[ "$?" == 0 ]]; then
        return 0
    else
        return 1
    fi
}

#-------------------------------------------------
# Function to display the prompt asking the user
# how they want to act on a specific app
#-------------------------------------------------
promptForOptions()
{
    if checkIfAppIsBlocked; then
        CURRENT_STATUS="blocked from receiving external communication"
    else
        CURRENT_STATUS="allowed to receive external communication"
    fi

    echo "INFO: Prompting for options. "
    SELECTION="$(osascript -e 'tell application "Self Service"' -e 'choose from list {"Allow communication","Block communication","Remove firewall entry"} with prompt "'"$FILE_NAME"' is currently '"$CURRENT_STATUS"'.\n\nWhat action would you like to take with '"$FILE_NAME"'?" OK button name {"Apply"} cancel button name {"Cancel"}' -e 'end tell')"

    case "$SELECTION" in
        "Allow communication")
        echo "INFO: User chose to allow communication."
        changeStatus "unblockapp"
        ;;
        "Block communication")
        echo "INFO: User chose to block communication."
        changeStatus "blockapp"
        ;;
        "Remove firewall entry")
        echo "INFO: User chose to remove from firewall"
        changeStatus "remove"
        ;;
        *)
        echo "INFO: User chose to cancel."
        exit 0
        ;;
    esac

}

#-------------------------------------------------
# Function to add the selected item to the firewall.
# Must be done before app can be allowed or blocked
#-------------------------------------------------
addAppToFirewall()
{
    /usr/libexec/ApplicationFirewall/socketfilterfw --add "$SPECIFIED_APP"

    if [[ "$?" != "0" ]]; then
        echo "ERROR: There was a problem adding $SPECIFIED_APP to the firewall."
        showErrorMessage "There was a problem adding '$FILE_NAME' to the firewall.\n\nContact the Service Desk for assistance."
        exit 20
    fi
}


#-------------------------------------------------
# The main script
#-------------------------------------------------
main(){
    selectAnApplicationOrBinary

    /usr/libexec/ApplicationFirewall/socketfilterfw --listapps | grep "$SPECIFIED_APP" > /dev/null

    if [[ "$?" == "0" ]]; then
        echo "INFO: $SPECIFIED_APP already explicitly on firewall list."
        promptForOptions
    else
        echo "INFO: Application will be added to the firewall"
        showVerificationMessage "An entry for '$FILE_NAME' will be added to the firewall.\n\nThis will explicitly allow communication with '$FILE_NAME' unless otherwise specified on the next prompt.\n\nAre you sure you want to do this?"
        addAppToFirewall
        promptForOptions


    fi

    showInforPrompt "Your changes to '$FILE_NAME' have been applied successfully."
}

#------------------------------------------------------------------------------
# Start Script
#------------------------------------------------------------------------------

main


#------------------------------------------------------------------------------
# End Script
#------------------------------------------------------------------------------
exit 0
