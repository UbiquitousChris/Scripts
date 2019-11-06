#!/bin/sh
###############################################################################
# Uninstall Applications
# 
#
# Author Name: Weinkauf, Chris
# Author Date: Jan 03 2019
# Purpose:
#
#
# Change Log:
# Jan 03 2019, UbiquitousChris
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
ALL_USERS="$(dscl . -list Users | grep -v "_" | grep -v daemon | grep -v management_user | grep -v root | grep -v nobody)"

# A human readable name for the application/item being uninstalled.
# Example: Skype for Business
APP_NAME="Microsoft Silverlight"

# Disable all prompts to perform a silent uninstall. Set to true to perform a
# silent uninstallation
DISABLE_UNINSTALL_PROMPTS=true

# If set to true, will prompt the user that a restart is required when the install
# is complete. Restart should be handled by the jamf binary. This only covers prompts.
# NOTE: If DISABLE_UNINSTALL_PROMPTS is set to true, this will be ignored
RESTART_REQUIRED=false

# A list of processes that need to close. If a user is logged in, they will be
# prompted to close an application if it running
APPLICATIONS_TO_CLOSE=""

# LaunchDaemons and Agents to be unloaded and removed (both user and system)
# Just the name of the plist file. No directory structure needed.
# Exmaple: com.microsoft.update.agent.plist
LAUNCHD_ITEMS=""

# Paths to items that are not located in a user's home folder
# Example: /Applications/TextWrangler.app
# Eample: /Library/Preferences/com.taco.bell.plist
ROOT_ITEMS="/Library/Application Support/Microsoft/Silverlight
/Library/Internet Plug-Ins/Silverlight.plugin
/tmp/SilverlightInstallTools"

# RELATIVE paths to items that would be located in a users home folder
# NOTE: Do not include a / at the beginning of the path
# EXAMPLE: Library/Preferences/com.microsoft.SkypeForBusiness.plist
USER_ITEMS=""

# Any package receipts that should be removed. You can find a list of package
# recipts installed on a system using the following command: pkgutil --packages
PACKAGE_RECEIPTS="com.microsoft.silverlight.plugin"

# Change the message displayed to the user when the uninstallation process starts
UNINSTALL_DESCRIPTION="You are about to uninstall $APP_NAME and all related preferences and components. No user data will be preserved.

Are you sure you want to continue?"


# Built in varible below this point. I reccomend not altering these.
JAMF_HELPER="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"
ICON="/System/Library/CoreServices/Setup Assistant.app/Contents/Resources/check0.tiff"
RESTART_ICON="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/Resources/Restart.png"
PANIC_ICON="/System/Library/CoreServices/ReportPanic.app/Contents/Resources/ProblemReporter.icns"
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
    if [ "$AGENT_FILE" == "" ]; then
        echo "ERROR: No agent file was passed to clearLaunchDItems"
        return
    fi


    # Check for the presense of an agent
    if [ -f "$AGENT_FILE" ]; then
        echo "Found LaunchAgent $AGENT_FILE"

        # Disable the agent
        echo "Unloading $AGENT_FILE..."
        /bin/launchctl unload -F "$AGENT_FILE"

        # Remove the agent plist
        echo "Removing $AGENT_FILE..."
        rm "$AGENT_FILE"

        # Make sure the removal was successful
        if [ "$?" != "0" ]; then
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
    if [ "$LOGGED_IN_USER" != "" ]; then
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

if [ isConsoleUserLoggedIn ] && [ $DISABLE_UNINSTALL_PROMPTS == false ]; then
    # Prompt the user.
    "$JAMF_HELPER" -windowType utility -description "$UNINSTALL_DESCRIPTION" -icon "$PANIC_ICON" -button1 "Yes" -button2 "No" -defaultButton 1

    if [ "$?" != "0" ]; then
        echo "INFO: User has chosen to cancel. Exiting..."
        exit 0
    else
        echo "INFO: User has selected to continue."
    fi
fi

#--------------------------------------------------
# If a restart is required, inform the user
#--------------------------------------------------

if [ isConsoleUserLoggedIn ] && [ $RESTART_REQUIRED == true ] && [ $DISABLE_UNINSTALL_PROMPTS == false ]; then
    echo "INFO: A restart is required after uninstalling $APP_NAME. Prompting user..."
    # Prompt the user.
    "$JAMF_HELPER" -windowType utility -description "Your computer will need to restart after uninstalling $APP_NAME. Are you sure you want to continue?" -icon "$RESTART_ICON" -button1 "Yes" -button2 "No" -defaultButton 1

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
if [ isConsoleUserLoggedIn ] && [ "$APPLICATIONS_TO_CLOSE" != "" ] && [ $DISABLE_UNINSTALL_PROMPTS == false ]; then

    # Loop through provided applications
    for OPEN_APP in $APPLICATIONS_TO_CLOSE; do
        echo "INFO: Checking for running process: $OPEN_APP"
        ps aux | grep "$OPEN_APP" | grep -v jamf | grep -v grep > /dev/null

        if [ "$?" == "0" ]; then
            echo "INFO: $OPEN_APP is running. Prompting to close."

            "$JAMF_HELPER" -windowType utility -description "Please quit $OPEN_APP to continue with the uninstallation process." -icon "$PANIC_ICON" &

            # Loop until the process is closed
            echo "INFO: Waiting for $OPEN_APP to close."
            while true; do
                # Check for the presense of the open process
                ps aux | grep "$OPEN_APP" | grep -v jamf | grep -v grep > /dev/null

                # If the app is no longer open, break from the loop
                if [ "$?" != "0" ]; then
                    echo "INFO: $OPEN_APP has quit. Continuing."

                    # Close our jamfHelper
                    killall -9 jamfHelper

                    # Break from the loop
                    break
                fi

                # Sleep a beat
                sleep 1
            done
        fi

    done

elif [ "$APPLICATIONS_TO_CLOSE" != "" ] && [ $DISABLE_UNINSTALL_PROMPTS == true ]; then
    echo "INFO: Prompts have been disabled. Check for and killing apps and processes."

    # Loop through all listed open applications
    for OPEN_APP in $APPLICATIONS_TO_CLOSE; do

        # Check for the application
        ps aux | grep -m1 "$OPEN_APP" | grep -v grep > /dev/null

        # If we get back a 0, a process matched.
        if [ "$?" == "0" ]; then
            echo "INFO: $OPEN_APP process is running. Attempting to kill..."

            # Force kill the process
            killall -9 "$OPEN_APP"
        else
            echo "INFO: $OPEN_APP: No running processes found"
            continue
        fi

    done

fi

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
    if [ ! -d "$ROOT_ITEM" ] && [ ! -f "$ROOT_ITEM" ]; then
        continue
    fi

    # Remove the item in question
    echo "Attempting to delete $ROOT_ITEM"
    rm -Rf "$ROOT_ITEM"

    # Check for errors
    if [ "$?" != "0" ]; then
        echo "ERROR: Failed to delete $ROOT_ITEM"
        exit 1
    fi


done

echo "Finished removing root level items."


#-------------------------------------------------
# Remove items from User home folders
#-------------------------------------------------
echo "Removing user level items..."

# Loop through each local user on the system
for USER in $ALL_USERS; do
    # Get the user's home directory
    HOME_DIRECTORY="$(dscl . -read Users/$USER NFSHomeDirectory | awk '{print $2}')"

    # If the user has no home folder, slip them
    if [ ! -d "$HOME_DIRECTORY" ]; then
        continue
    fi
    echo "Removing files from $HOME_DIRECTORY home"

    # Loop through the LAUNCHD_ITEMS
    for AGENT in $LAUNCHD_ITEMS;do
        # Check for and clear system level LaunchAgents and Daemons
        echo "Checking for the presense of $AGENT launch agent"
        clearLaunchDItem "$HOME_DIRECTORY/Library/LaunchAgents/$AGENT"
    done

    for USER_ITEM in $USER_ITEMS; do
        # Check to make sure that the item actually exists
        if [ ! -d "$HOME_DIRECTORY/$USER_ITEM" ] && [ ! -f "$HOME_DIRECTORY/$USER_ITEM" ]; then
            continue
        fi

        # Remove the item in question
        echo "Attempting to delete $HOME_DIRECTORY/$USER_ITEM"
        rm -Rf "$HOME_DIRECTORY/$USER_ITEM"

        # Check for errors
        if [ "$?" != "0" ]; then
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
if [ isConsoleUserLoggedIn ] && [ $DISABLE_UNINSTALL_PROMPTS == false ]; then
    # Throwing up a jamfHelper
    "$JAMF_HELPER" -windowType utility -description "$DESCRIPTION" -icon "$ICON" -button1 "Ok" -defaultButton 1 &
fi

echo "$DESCRIPTION"
#------------------------------------------------------------------------------
# End Script
#------------------------------------------------------------------------------
exit 0
