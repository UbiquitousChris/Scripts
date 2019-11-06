#!/bin/zsh
###############################################################################
# 
# 
#
# Author Name: Weinkauf, Chris
# Author Date: Jan 24 2019
# Purpose: This script will download, verify, and install a Microsoft app
#          specified by it's parameter link.
#
# Change Log:
# Oct 09 2019, UbiquitousChris
# - Updated for zsh
# - Added installation status notifications
# Jan 24 2019, UbiquitousChris
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

FW_LINK="$4"
TEMPORARY_DOWNLOAD_LOCATION="/var/tmp/$FW_LINK.pkg"

#-------------------
# Functions
#-------------------

verifyInstallationAssets()
{
    # Make sure installation assets actually exist
    if [[ ! -f "$TEMPORARY_DOWNLOAD_LOCATION" ]]; then
        echo "ERROR: Installation assets are missing."
        displayNotification "ERROR: Installation assets are missing."
        exit 20
    fi

    echo "INFO: Verifying installation assets."
    displayNotification "Verifying downloaded installer assets..."
    /usr/sbin/pkgutil --check-signature "$TEMPORARY_DOWNLOAD_LOCATION" > /dev/null

    if [[ "$?" != "0" ]]; then
        echo "ERROR: Failed to verify installation assets."
        displayNotification "ERROR: Failed to verify installation assets."
        removeDownloadedInstallerAssets
        exit 30
    fi

    displayNotification "Installation assets verified."
    echo "INFO: Verified."
}

getPackageName()
{
    PACKAGE_NAME="$(/usr/sbin/installer -pkginfo -pkg "$TEMPORARY_DOWNLOAD_LOCATION")"
    echo "INFO: Package name is $PACKAGE_NAME"
}

downloadInstallationAssets()
{
    echo "INFO: Starting download of $FW_LINK from Microsoft."
    displayNotification "Downloading installation assets from Microsoft..."
    /usr/bin/curl -sJL "https://go.microsoft.com/fwlink/?linkid=$FW_LINK" -o "$TEMPORARY_DOWNLOAD_LOCATION"

    if [[ "$?" != "0" ]]; then
        echo "ERROR: Failed to download installer resources for $FW_LINK"
        displayNotification "Error: Failed to download installation assets."
        removeDownloadedInstallerAssets
        exit 10
    fi

    verifyInstallationAssets
    getPackageName
}

installPackage()
{
    echo "INFO: Starting installation of $PACKAGE_NAME"
    displayNotification "Installing $PACKAGE_NAME..."
    /usr/sbin/installer -pkg "$TEMPORARY_DOWNLOAD_LOCATION" -tgt /

    if [[ "$?" != "0" ]]; then
        echo "ERROR: Failed to install $PACKAGE_NAME"
        displayNotification "ERROR: The installation of $PACKAGE_NAME failed. Please try again later."
        /usr/bin/tail -100 "/var/log/install.log"
        removeDownloadedInstallerAssets
        exit 40
    fi

    echo "INFO: Installation of $PACKAGE_NAME was completed successfully."
    displayNotification "$PACKAGE_NAME installation completed successfully."
}

removeDownloadedInstallerAssets()
{
    echo "INFO: Removing downloaded installer assets"
    [[ -f "$TEMPORARY_DOWNLOAD_LOCATION" ]] && rm "$TEMPORARY_DOWNLOAD_LOCATION"
    echo "INFO: Done"
}

displayNotification()
{
    echo "INFO: Displaying notification '$1'"
    '/Library/Application Support/JAMF/bin/Management Action.app/Contents/MacOS/Management Action' -title "Microsoft App Install" -message "$1"
}

#------------------------------------------------------------------------------
# Start Script
#------------------------------------------------------------------------------
echo "INFO: Starting script execution at $(date)"

if [[ "$FW_LINK" == "" ]]; then
    echo "ERROR: A forwarding link was not supplied."
    exit 5
fi

downloadInstallationAssets
installPackage


#-------------------------------------------------
# Detailed comment on a piece of code.
#-------------------------------------------------

#------------------------------------------------------------------------------
# End Script
#------------------------------------------------------------------------------
removeDownloadedInstallerAssets
exit 0
