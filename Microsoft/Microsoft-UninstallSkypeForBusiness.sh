#!/bin/zsh
###############################################################################
# Uninstall Applications
# 
#
# Author Name: Weinkauf, Chris
# Author Date: Oct 18 2019
# Purpose: Uninstall Skype for Business
#
#
# Change Log:
# Oct 18 2019, UbiquitousChris
# - Initial Creation
###############################################################################

#-------------------
# Variables
#-------------------

# Update the IFS varible to ignore spaces in lists
OLD_IFS="$(echo $IFS)"
IFS=$'\n'

# Gets a list of all the interactive users on a system. I would reccomend not
# altering this variable
ALL_USERS=($(dscl . -list Users | grep -v "_" | grep -v daemon | grep -v management_user | grep -v root | grep -v nobody))

# A human readable name for the application/item being uninstalled.
# Example: Skype for Business
APP_NAME="Skype for Business"

# Disable all prompts to perform a silent uninstall. Set to true to perform a
# silent uninstallation
DISABLE_UNINSTALL_PROMPTS=false

# If set to true, will prompt the user that a restart is required when the install
# is complete. Restart should be handled by the jamf binary. This only covers prompts.
# NOTE: If DISABLE_UNINSTALL_PROMPTS is set to true, this will be ignored
RESTART_REQUIRED=false

# A list of processes that need to close. If a user is logged in, they will be
# prompted to close an application if it running
APPLICATIONS_TO_CLOSE="Skype for Business"

# LaunchDaemons and Agents to be unloaded and removed (both user and system)
# Just the name of the plist file. No directory structure needed.
# Exmaple: com.microsoft.update.agent.plist
LAUNCHD_ITEMS=""

# Paths to items that are not located in a user's home folder
# Example: /Applications/TextWrangler.app
# Eample: /Library/Preferences/com.taco.bell.plist
ROOT_ITEMS=("/Applications/Skype for Business.app"
"/Library/Internet Plug-Ins/MeetingJoinPlugin.plugin"
"/private/var/db/receipts/com.microsoft.SkypeForBusiness")

# RELATIVE paths to items that would be located in a users home folder
# NOTE: Do not include a / at the beginning of the path
# EXAMPLE: Library/Preferences/com.microsoft.SkypeForBusiness.plist
USER_ITEMS=("Library/Containers/com.microsoft.SkypeForBusiness"
"Library/Saved Application State/com.microsoft.SkypeForBusiness.savedState"
"Library/Preferences/com.microsoft.SkypeForBusiness.plist"
"Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.ApplicationRecentDocuments/com.microsoft.skypeforbusiness"
"Library/Cookies/com.microsoft.SkypeForBusiness"
"Library/Application Scripts/com.microsoft.SkypeForBusiness")

# Any package receipts that should be removed. You can find a list of package
# recipts installed on a system using the following command: pkgutil --packages
PACKAGE_RECEIPTS="com.microsoft.SkypeForBusiness"

# Change the message displayed to the user when the uninstallation process starts
UNINSTALL_DESCRIPTION="You are about to uninstall $APP_NAME and all related preferences and components. No user data will be preserved.\n\nAre you sure you want to continue?"


# Built in varible below this point. I reccomend not altering these.
ICON="System:Library:CoreServices:CoreTypes.bundle:Contents:Resources:TrashIcon.icns"
RESTART_ICON="Library:Application Support:JAMF:bin:jamfHelper.app:Contents:Resources:Restart.png"
PANIC_ICON="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertCautionIcon.icns"
DESCRIPTION="$APP_NAME has been removed successfully."

#-------------------
# Functions
#-------------------

clearLaunchDItem()
{
    # Grab the folder to look for
    AGENT_FILE="$1"
    echo "Agent File is $AGENT_FILE"

    # Check to make sure something was passed in
    if [[ "$AGENT_FILE" == "" ]]; then
        echo "ERROR: No agent file was passed to clearLaunchDItems"
        return
    fi


    # Check for the presense of an agent
    if [[ -f "$AGENT_FILE" ]]; then
        echo "Found LaunchAgent $AGENT_FILE"

        # Disable the agent
        echo "Unloading $AGENT_FILE..."
        /bin/launchctl unload -F "$AGENT_FILE"

        # Remove the agent plist
        echo "Removing $AGENT_FILE..."
        rm "$AGENT_FILE"

        # Make sure the removal was successful
        if [[ "$?" != "0" ]]; then
            echo "ERROR: Failed to delete LaunchAgent $AGENT_FILE"
            exit 20
        else
            echo "Unloaded and removed $AGENT_FILE successfully."
        fi
    else
        return
    fi
}

isConsoleUserLoggedIn()
{
    # Check for a logged in user
    LOGGED_IN_USER="$(who | grep console | awk '{ print $1 }')"

    # Handle the results
    if [[ "$LOGGED_IN_USER" != "" ]]; then
        echo "INFO: $LOGGED_IN_USER is currently logged in."
        return 0
    else
        echo "INFO: Nobody is currently logged in."
        return 1
    fi

}

#------------------------------------------------------------------------------
# Start Script
#------------------------------------------------------------------------------
echo "Starting removal of $APP_NAME"



#--------------------------------------------------
# Warn the user what we're about to do.
#--------------------------------------------------

if [[ isConsoleUserLoggedIn ]] && [[ $DISABLE_UNINSTALL_PROMPTS == false ]]; then
    # Prompt the user.
    /usr/bin/osascript -e 'tell application "System Events" to display dialog "'"$UNINSTALL_DESCRIPTION"'" buttons {"No","Yes"} default button "Yes" cancel button "No" with title "Uninstall '"$APP_NAME"'" with icon file "System:Library:CoreServices:CoreTypes.bundle:Contents:Resources:AlertCautionIcon.icns" giving up after (86400)'

    if [[ "$?" != "0" ]]; then
        echo "INFO: User has chosen to cancel. Exiting..."
        exit 0
    else
        echo "INFO: User has selected to continue."
    fi
fi

#--------------------------------------------------
# If a restart is required, inform the user
#--------------------------------------------------

if [[ isConsoleUserLoggedIn ]] && [[ $RESTART_REQUIRED == true ]] && [[ $DISABLE_UNINSTALL_PROMPTS == false ]]; then
    echo "INFO: A restart is required after uninstalling $APP_NAME. Prompting user..."
    # Prompt the user.
    /usr/bin/osascript -e 'tell application "System Events" to display dialog "Your computer will need to restart after uninstalling '"$APP_NAME"'.\n\nAre you sure you want to continue?" buttons {"No","Yes"} default button "Yes" cancel button "No" with title "Uninstall '"$APP_NAME"'" with icon file "Library:Application Support:JAMF:bin:jamfHelper.app:Contents:Resources:Restart.png" giving up after (86400)'

    if [ "$?" != "0" ]; then
        echo "INFO: User has chosen to cancel. Exiting..."
        exit 0
    else
        echo "INFO: User has selected to continue."
    fi
fi

#--------------------------------------------------
# Check for and close processes if a user is logged in
#--------------------------------------------------

# Check for a logged in user
if [[ isConsoleUserLoggedIn ]] && [[ "$APPLICATIONS_TO_CLOSE" != "" ]] && [[ $DISABLE_UNINSTALL_PROMPTS == false ]]; then

    # Loop through provided applications
    for OPEN_APP in $APPLICATIONS_TO_CLOSE; do
        echo "INFO: Checking for running process: $OPEN_APP"
        /usr/bin/pgrep "$OPEN_APP" &> /dev/null

        if [[ "$?" == "0" ]]; then
            echo "INFO: $OPEN_APP is running. Prompting to close."
            /usr/bin/killall -9 "$OPEN_APP"

        fi

    done

elif [[ "$APPLICATIONS_TO_CLOSE" != "" ]] && [[ $DISABLE_UNINSTALL_PROMPTS == true ]]; then
    echo "INFO: Prompts have been disabled. Check for and killing apps and processes."

    # Loop through all listed open applications
    for OPEN_APP in $APPLICATIONS_TO_CLOSE; do

        # Check for the application
        /usr/bin/pgrep "$OPEN_APP" &> /dev/null

        # If we get back a 0, a process matched.
        if [[ "$?" == "0" ]]; then
            echo "INFO: $OPEN_APP process is running. Attempting to kill..."

            # Force kill the process
            /usr/bin/killall -9 "$OPEN_APP"
        else
            echo "INFO: $OPEN_APP: No running processes found"
            continue
        fi

    done

fi

#--------------------------------------------------
# If the uninstall script needs to perform additional
# scripted tasks, this is the place to do it.
#--------------------------------------------------
rm -rf /private/var/db/receipts/com.microsoft.SkypeForBusiness* &> /dev/null
/usr/bin/find -f /private/var/db/BootCaches/* -name "app.com.microsoft.SkypeForBusiness*" -exec sudo rm -rf {} + &> /dev/null

#--------------------------------------------------
# Kill and remove system level LaunchAgents/Daemons
#--------------------------------------------------

# Loop through the LAUNCHD_ITEMS
for AGENT in $LAUNCHD_ITEMS;do
    # Check for and clear system level LaunchAgents and Daemons
    clearLaunchDItem "/Library/LaunchDaemon/$AGENT"
    clearLaunchDItem "/Library/LaunchAgents/$AGENT"
done

# Log that we've completed this portion
echo "Finished handling system level LaunchAgents and LaunchDaemon"

#-------------------------------------------------
# Remove items from root folders
#-------------------------------------------------
echo "Removing general items from root level..."

for ROOT_ITEM in $ROOT_ITEMS; do
    # Check to make sure that the item actually exists
    if [[ ! -d "$ROOT_ITEM" ]] && [[ ! -f "$ROOT_ITEM" ]]; then
        continue
    fi

    # Remove the item in question
    echo "Attempting to delete $ROOT_ITEM"
    rm -Rf "$ROOT_ITEM"

    # Check for errors
    if [[ "$?" != "0" ]]; then
        echo "ERROR: Failed to delete $ROOT_ITEM"
        exit 1
    fi


done

echo "Finished removing root level items."


#-------------------------------------------------
# Remove items from User home folders
#-------------------------------------------------
echo '#-------------------------------------------------
# Remove items from User home folders
#-------------------------------------------------'

# Loop through each local user on the system
for USER in $(dscl . list /Users UniqueID | awk '$2 > 500 { print $1 }'); do
    # Get the user's home directory
    HOME_DIRECTORY="$(dscl . -read Users/$USER NFSHomeDirectory | awk '{print $2}')"

    # If the user has no home folder, slip them
    if [[ ! -d "$HOME_DIRECTORY" ]]; then
        continue
    fi

    echo "*****************************************"
    echo "Removing files from $HOME_DIRECTORY home"
    echo "*****************************************"
    # Loop through the LAUNCHD_ITEMS
    for AGENT in $LAUNCHD_ITEMS;do
        # Check for and clear system level LaunchAgents and Daemons
        echo "Checking for the presense of $AGENT launch agent"
        clearLaunchDItem "$HOME_DIRECTORY/Library/LaunchAgents/$AGENT"
    done

    rm -rf $HOME_DIRECTORY/Library/Logs/DiagnosticReports/Skype\ for\ Business_*
    rm -rf $HOME_DIRECTORY/Library/Application\ Support/CrashReporter/Skype\ for\ Business_*

    for USER_ITEM in $USER_ITEMS; do
        # Check to make sure that the item actually exists
        if [[ ! -d "$HOME_DIRECTORY/$USER_ITEM" ]] && [[ ! -f "$HOME_DIRECTORY/$USER_ITEM" ]]; then
            continue
        fi

        # Remove the item in question
        echo "Attempting to delete $HOME_DIRECTORY/$USER_ITEM"
        rm -Rfv "$HOME_DIRECTORY/$USER_ITEM"

        # Check for errors
        if [[ "$?" != "0" ]]; then
            echo "ERROR: Failed to delete $HOME_DIRECTORY/$USER_ITEM"
            exit 1
        fi
    done
done

# Forget the package receipts
echo "Forgetting the package was installed"
for RECEIPT in $PACKAGE_RECEIPTS; do
    /usr/sbin/pkgutil --forget "$RECEIPT"
done

# Check if a user is logged in
if [[ isConsoleUserLoggedIn ]] && [[ $DISABLE_UNINSTALL_PROMPTS == false ]]; then
    # Throwing up a jamfHelper
    /usr/bin/osascript -e 'tell application "System Events" to display dialog "'"$DESCRIPTION"'" buttons {"Okay"} default button "Okay" with title "Uninstall '"$APP_NAME"'" with icon file "'"$ICON"'" giving up after (86400)'

fi

echo "$DESCRIPTION"
#------------------------------------------------------------------------------
# End Script
#------------------------------------------------------------------------------
exit 0
