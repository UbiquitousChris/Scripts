#!/bin/zsh
###############################################################################
# 
# 
#
# Author Name: Weinkauf, Chris
# Author Date: Aug 05 2019
# Purpose:
#
#
# Change Log:
# Aug 05 2019, UbiquitousChris
# - Initial Creation
###############################################################################

#-------------------
# Variables
#-------------------

SCRIPT_NAME=`basename $0`
SCRIPT_VERSION="1.0.0"

FOLDERS_TO_BACKUP=('Desktop' 'Documents' 'Downloads' 'Pictures' 'Movies')
ONEDRIVE_DIRECTORY="OneDrive - CompName"

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

waitForUserToLogin()
{
    while true; do
        CURRENT_USER="$(ls -la /dev/console | awk '{print $3}')"

        if [[ "$CURRENT_USER" == "root" ]]; then
            sleep 1
            continue
        elif [[ "$CURRENT_USER" == "" ]] || [[ "$CURRENT_USER" == "management_user" ]] || [[ "$CURRENT_USER" == "jamfsvc" ]]; then
            echo "INFO: $CURRENT_USER is unsupported. Exiting."
            exit 0
        else
            echo "INFO: $CURRENT_USER has logged in."
            HOME_DIRECTORY="$(/usr/bin/dscl . -read /Users/$CURRENT_USER NFSHomeDirectory | awk -F': ' '{print $2}')"
            echo "INFO: $CURRENT_USER home directory is $HOME_DIRECTORY"
            break
        fi
    done
}

checkIfBackupConfigurationHasCompleted()
{
    if [[ -f "$HOME_DIRECTORY/Library/Preferences/com.example.onedrivebackupd.plist" ]]; then
        LAST_VERSION="$(defaults read "$HOME_DIRECTORY/Library/Preferences/com.example.onedrivebackupd.plist" ConfigVersion)"

        if [[ "$LAST_VERSION" == "$SCRIPT_VERSION" ]]; then
            echo "INFO: Already configured. Exiting."
            exit 0
        fi
    fi
    echo "INFO: New configuration."
}

waitForOneDriveToBeConfigured()
{
    echo "INFO: Waiting for OneDrive folder to appear at $HOME_DIRECTORY/$ONEDRIVE_DIRECTORY"
    while [[ ! -d "$HOME_DIRECTORY/$ONEDRIVE_DIRECTORY" ]]; do
        sleep 5
    done
    echo "INFO: Ready."
}

configureBackupFolders()
{
    for FOLDER in $FOLDERS_TO_BACKUP; do

        if [[ -d "$HOME_DIRECTORY/$FOLDER" ]] && [[ -d "$HOME_DIRECTORY/$ONEDRIVE_DIRECTORY/$FOLDER" ]]; then
            updateBackupFolder "$FOLDER"
        elif [[ -d "$HOME_DIRECTORY/$FOLDER" ]] && [[ ! -d "$HOME_DIRECTORY/$ONEDRIVE_DIRECTORY/$FOLDER" ]]; then
            createBackupFolder "$FOLDER"
        elif [[ ! -d "$HOME_DIRECTORY/$FOLDER" ]] && [[ -d "$HOME_DIRECTORY/$ONEDRIVE_DIRECTORY/$FOLDER" ]]; then
            createBackupFolder "$FOLDER"
        else
            echo "INFO: ¯\_(ツ)_/¯"
        fi

    done
}

createBackupFolder()
{
    echo "Creating Backup for folder $HOME_DIRECTORY/$1"
    /bin/mv "$HOME_DIRECTORY/$1" "$HOME_DIRECTORY/$ONEDRIVE_DIRECTORY/$1"

    /bin/ln -s "$HOME_DIRECTORY/$ONEDRIVE_DIRECTORY" "$HOME_DIRECTORY/$1"
}

updateBackupFolder()
{
    echo "Would have updated backup folder $1"
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

waitForUserToLogin
checkIfBackupConfigurationHasCompleted
waitForOneDriveToBeConfigured
configureBackupFolders


#-------------------------------------------------
# Detailed comment on a piece of code.
#-------------------------------------------------

#------------------------------------------------------------------------------
# End Script
#------------------------------------------------------------------------------
exit 0
