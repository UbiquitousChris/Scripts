#!/bin/sh
###############################################################################
# 
# 
#
# Author Name: Weinkauf, Chris
# Author Date: Dec 21 2018
# Purpose:
#
#
# Change Log:
# Jan 21 2019, UbiquitousChris
# - If installing app bundle, we now add the bundle to the built in firewall
# Jan 16 2019, UbiquitousChris
# - Added function to mount and install items from disk images
# Jan 15 2019, UbiquitousChris
# - Fixed a bug that would cause an app bundle to be removed if a user chose the
#   app bundle from the /Applications folder.
# Dec 21 2018, UbiquitousChris
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

CURRENT_LOGGED_IN_USER=$(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }')

BOOT_DRIVE_NAME="$(diskutil info "$(bless --info --getBoot)" | awk -F':' '/Volume Name/ { print $2 }' | sed -e 's/^[[:space:]]*//')"

BLACKLISTED_IDENTIFIERS="io.fti.SplashBuddy
com.apple.InstallAssistant.Mojave
com.apple.InstallAssistant.HighSierra
com.apple.InstallAssistant.Sierra
com.adobe.flashplayer.installmanager
Oracle.MacJREInstaller"
#-------------------
# Functions
#-------------------

authenticateUser() {

    # Loop until the user enters a correct password or cancels
    while true; do

        # Use osascript to ask the user for a password
        LOCAL_PASSWORD=$(osascript -e 'text returned of (display dialog "Self Service would like to install a third party application or bundle.\n\nEnter the password for '$CURRENT_LOGGED_IN_USER' to install software." default answer "" buttons {"Cancel","OK"} default button 2 with hidden answer with icon file "System:Library:CoreServices:CoreTypes.bundle:Contents:Resources:FileVaultIcon.icns")')

        if [[ "$?" != "0" ]]; then
            echo "INFO: User chose to quit."
            exit 0
        fi

        # Validate the users password
        /usr/bin/dscl . -authonly "$CURRENT_LOGGED_IN_USER" "$LOCAL_PASSWORD"

        if [[ "$?" != "0" ]]; then
            echo "ERROR: Incorrect password for $CURRENT_LOGGED_IN_USER"
            continue
        else
            echo "INFO: Password accepted."
            break
        fi

    done
}

askUserForAppName()
{
    # Use AppleScript to prompt the user for the installer or app file
    SPECIFIED_APP=$(osascript -e 'POSIX path of(choose file with prompt "Select an application or installer to install to your computer:" of type {"PKG","MPKG","APP","DMG"})')

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
    fi

}

installPackageOrMetapackage()
{
    # Check for a developer signed package
    pkgutil --check-signature "$SPECIFIED_APP"

    # If the signing is invalid or the package is not signed, error out
    if [[ "$?" != "0" ]]; then
        echo "ERROR: Package could not be validated."
        showErrorMessage "The installer package '$INSTALLER_OR_APP' could not be verified. It may be damaged, improperly signed, or has been altered by a malicious third party.\n\nContact the vendor or manufacturer and request a properly signed package to continue.\n\nContact the Service Desk for assistance."
        exit 15
    fi

    # Verify that the user actually wants to install the package
    showVerificationMessage "The package '$INSTALLER_OR_APP' will be installed on '$BOOT_DRIVE_NAME'.\n\nAre you sure you want to continue?"

    # Perform the installation
    /usr/sbin/installer -pkg "$SPECIFIED_APP" -target / -verboseR

    if [[ "$?" != "0" ]]; then
        echo "ERROR: $INSTALLER_OR_APP failed to install. Check the installer logs for details."
        showErrorMessage "An error occured while trying to install the package '$INSTALLER_OR_APP'. You can check the logs at /var/log/install.log for more details.\n\nContact the Service Desk for assistance."
        exit 20
    fi
}


installAppBundle()
{
    echo "INFO: Installing application bundle."

    checkBundleIdentifierAgainstBlacklist

    INSTALL_LOCATION="/Applications/$INSTALLER_OR_APP"

    # Check to make sure the user didn't pick an app in the Applications folder
    if [[ "$SPECIFIED_APP" == "$INSTALL_LOCATION" ]]; then
        echo "ERROR: User selected an app in the applications folder."
        showErrorMessage "The selected application bundle '$INSTALLER_OR_APP' was chosen from the Applications folder. The source file to be installed cannot be the same as the destination file.\n\nContact the Service Desk for assistance."
        exit 7
    fi

    # Check the bundle's code signiture
    /usr/bin/codesign -v "$SPECIFIED_APP"

    # If the signature isn't valid or the app is not signed, stop the process
    if [[ "$?" != "0" ]]; then
        echo "ERROR: App bundle could not be verified."
        showErrorMessage "The application bundle '$INSTALLER_OR_APP' could not be verified. It may be damaged, improperly signed, or has been altered by a malicious third party.\n\nContact the Service Desk for assistance."
        exit 5
    fi

    # Verify with the user that they actually want to install this
    showVerificationMessage "The app bundle '$INSTALLER_OR_APP' will be copied to the Applications folder on '$BOOT_DRIVE_NAME'.\n\nAre you sure you want to continue?"



    # Check for and remove any current application bundle
    if [[ -d "/Applications/$INSTALLER_OR_APP" ]]; then
        echo "INFO: Found previous version of $INSTALLER_OR_APP. Removing..."

        rm -rf "$INSTALL_LOCATION"

        echo "INFO: Removed."
    fi

    # Copy the application to the destination
    echo "INFO: $SPECIFIED_APP will be copied to /Applications"
    cp -Rf "$SPECIFIED_APP" "/Applications/"

    if [[ "$?" != "0" ]]; then
        echo "ERROR: Failed to install application."
        showErrorMessage "An error occured while trying to copy $INSTALLER_OR_APP to the Applications folder.\n\nContact the Service Desk for assistance."
        exit 30
    fi

    # Change the permissions to the user installing the app so that automatic updates can be applied
    echo "INFO: Updating permissions"
    chown -R "$CURRENT_LOGGED_IN_USER:wheel" "$INSTALL_LOCATION"

    if [[ "$?" != "0" ]]; then
        echo "ERROR: Failed to update permissions application."
        showErrorMessage "An error occured while trying to copy $INSTALLER_OR_APP to the Applications folder.\n\nContact the Service Desk for assistance."
        exit 30
    fi

    echo "INFO: Explicitly allowing app on firewall"

    /usr/libexec/ApplicationFirewall/socketfilterfw --add "$INSTALL_LOCATION"

    if [[ "$?" != "0" ]]; then
        echo "ERROR: Failed to add application to firewall."
        showErrorMessage "An error occured while trying to add $INSTALLER_OR_APP to the application firewall.\n\nContact the Service Desk for assistance."
        exit 30
    fi

}

checkBundleIdentifierAgainstBlacklist()
{
    echo "INFO: Checking bundle identifier against blacklist"

    BUNDLE_INFO_FILE="$SPECIFIED_APP/Contents/Info.plist"

    if [[ ! -f "$BUNDLE_INFO_FILE" ]]; then
        echo "ERROR: Bundle info could not be read."
        showErrorMessage "The bundle identifier for '$INSTALLER_OR_APP' could not be validated.\n\nContact the Service Desk for assistance."
        exit 40
    fi

    BUNDLE_IDENTIFIER="$(defaults read "$BUNDLE_INFO_FILE" CFBundleIdentifier)"

    for BLACKLISTED_ITEM in $BLACKLISTED_IDENTIFIERS; do
        if [[ "$BLACKLISTED_ITEM" == "$BUNDLE_IDENTIFIER" ]]; then
            echo "ERROR: $BUNDLE_IDENTIFIER is blacklisted."
            showErrorMessage "The application '$INSTALLER_OR_APP' cannot be installed on CompName managed assets.\n\nContact the Service Desk for assistance."
            exit 45
        fi

    done

}

scanDiskImageForInstallerOrApp()
{

    echo "INFO: Received disk image. Scanning for installable items."

    # Generate a folder to mount to
    MOUNT_POINT="/tmp/$(uuidgen)"

    # Attempt to mount the disk image
    hdiutil mount "$SPECIFIED_APP" -mountpoint "$MOUNT_POINT" -quiet -nobrowse

    # If we couldn't mount the disk image, fail out.
    if [[ "$?" != "0" ]]; then
        echo "ERROR: Could not mount DMG"
        showErrorMessage "The disk image '$INSTALLER_OR_APP' could not be read.\n\nContact the Service Desk for assistance."
        exit 60
    fi

    # Scan the disk image for an applicable file to install
    SPECIFIED_APP="$(ls -1d $MOUNT_POINT/* | grep -m1 -E ".app|.pkg|.mpkg")"

    if [[ "$?" != "0" ]]; then
        # If we didnt find one, fail out
        echo "ERROR: No installable items found in $MOUNT_POINT"
        showErrorMessage "No installable items were found in the disk image '$INSTALLER_OR_APP'. The disk image must contain an installer package or application bundle to be installed.\n\nContact the Service Desk for assistance."
        unmountDiskImage
        exit 65
    else
        # If we did find one, have it take over as the new installable item
        determineFileNameAndExtension
        echo "INFO: $INSTALLER_OR_APP found in disk image. Will install."
    fi

}

showErrorMessage()
{
    ERR_MSG="$1"
    osascript -e 'display dialog "'"$ERR_MSG"'" buttons {"Done"} default button 1 with icon file "System:Library:CoreServices:CoreTypes.bundle:Contents:Resources:AlertStopIcon.icns"' &

    unmountDiskImage
}

unmountDiskImage()
{
    # If a disk image was select, unmount it
    if [[ "$isDiskImage" == "true" ]]; then

        # If the mountpoint cannot be found, return
        [[ ! -d "$MOUNT_POINT" ]] && return

        echo "INFO: Unmounting disk image at $MOUNT_POINT"
        hdiutil detach "$MOUNT_POINT"

        if [[ "$?" != "0" ]]; then
            echo "ERROR: Failed to unmount disk image at $MOUNT_POINT"
            showErrorMessage "There was a problem unmounting the selected disk image. You will need to restart your computer to attemp another install with Self Service.\n\nContact the Service Desk for assistance."
            exit 120
        fi
    fi
}

showVerificationMessage()
{
    VERIFICATION_MSG="$1"
    RESULT=$(osascript -e 'button returned of (display dialog "'"$VERIFICATION_MSG"'" buttons {"No","Yes"} with icon file "System:Library:CoreServices:Installer.app:Contents:Resources:Installer.icns")')

    if [[ "$RESULT" == "No" ]]; then
        echo "INFO: The user chose not to continue."
        unmountDiskImage
        exit 0
    fi

}

determineFileNameAndExtension()
{
    INSTALLER_OR_APP=$(basename -- "$SPECIFIED_APP")
    FILE_EXTENSION="${INSTALLER_OR_APP##*.}"
    FILE_NAME="${INSTALLER_OR_APP%.*}"
}

main()
{
    authenticateUser
    askUserForAppName
    determineFileNameAndExtension



    echo "INFO: BASE NAME $INSTALLER_OR_APP"
    echo "INFO: EXTENSION $FILE_EXTENSION"
    echo "INFO: FILENAME $FILE_NAME"

    if [[ "$FILE_EXTENSION" == "dmg" ]]; then
        isDiskImage=true
        scanDiskImageForInstallerOrApp
    fi

    if [[ "$FILE_EXTENSION" == "pkg" ]] || [[ "$FILE_EXTENSION" == "mpkg" ]]; then
        installPackageOrMetapackage
        osascript -e 'display dialog "The installation of '"$INSTALLER_OR_APP"' has completed successfully.\n\nYou can view the installation logs at /var/log/install.log." buttons {"Done"} default button 1 with icon file "System:Library:CoreServices:CoreTypes.bundle:Contents:Resources:ToolbarInfo.icns"' &
    elif [[ "$FILE_EXTENSION" == "app" ]]; then
        installAppBundle
        osascript -e 'display dialog "The installation of '"$INSTALLER_OR_APP"' has completed successfully.\n\nYou can find the installed application in your Applications folder on '"$BOOT_DRIVE_NAME"'." buttons {"Done"} default button 1 with icon file "System:Library:CoreServices:CoreTypes.bundle:Contents:Resources:ToolbarInfo.icns"' &
    else
        echo "ERROR: Invalid file extension: $FILE_EXTENSION"
        showErrorMessage "File extension type $FILE_EXTENSION is not supported.\n\nContact the Service Desk for assistance."
        exit 100
    fi

    unmountDiskImage

    echo "INFO: The application installed successfully."

}

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
