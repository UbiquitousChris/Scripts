#!/bin/bash
###############################################################################
# 
# 
#
# Author Name: Weinkauf, Chris
# Author Date: Sep 17 2019
# Purpose:
#
#
# Change Log:
# Sep 17 2019, UbiquitousChris
# - Initial Creation
###############################################################################

#-------------------
# Variables
#-------------------

SCRIPT_NAME=`basename $0`
SCRIPT_VERSION="1.0.0"

JAVA_PACKAGE="java-11-openjdk-devel"
MYSQL_PACKAGE="mysql-community-server"

INSTALLER_DIRECTORY="/jss_backups/Installers"

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
        --version | -v)
            shift
            VERSION="$1"
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
echo "******** Starting Jamf Pro Upgrade ($(date)) ********"


# Check version number
if [[ -z "$VERSION" ]]; then
    echo "Version must be specified with --version or -v"
    exit 1
fi

if [[ ! -f "/bin/jamf-pro" ]]; then
    echo "The jamf-pro binary could not be found."
    exit 2
fi

if [[ ! -f "$INSTALLER_DIRECTORY/$VERSION/jamfproinstaller.run" ]]; then
    echo "A Jamf Pro installer could not be found at $INSTALLER_DIRECTORY/$VERSION/jamfproinstaller.run."
    exit 3
fi

if [[ $(df --block-size=1073741824 / | tail -1 | awk '{print $4}') -le 2 ]]; then
    echo "Not enough free space on the root partition! Attempting to move tomcat backups..."
    mv /usr/local/jss/backups/tomcat/* /jss_backups/tomcat/

    if [[ "$?" != "0" ]]; then
        echo "FATAL: Could not clear space on root partition."
        exit 4
    fi

    if [[ $(df --block-size=1073741824 / | tail -1 | awk '{print $4}') -le 2 ]]; then
        echo "FATAL: There is still not enough free space after move."
        exit 5
    fi
fi

echo "Backing up the Jamf Pro Database..."
/bin/jamf-pro database backup

if [[ "$?" != "0" ]]; then
    echo "FATAL: Could not backup Jamf Pro database."
    exit 6
else
    echo "Database backed up successfully."
fi

/bin/jamf-pro server stop

if [[ "$?" != "0" ]]; then
    echo "FATAL: Could not stop the server service."
    exit 7
fi

/bin/jamf-pro database stop

if [[ "$?" != "0" ]]; then
    echo "FATAL: Could not stop the database service."
    exit 8
fi

echo "Upgrading support services..."
/bin/yum update -y "$JAVA_PACKAGE" "$MYSQL_PACKAGE"

if [[ "$?" != "0" ]]; then
    echo "FATAL: Failed to run yum command to upgrade services."
    exit 8
else
    echo "Services were upgraded successfully"
fi

/bin/jamf-pro database start

if [[ "$?" != "0" ]]; then
    echo "FATAL: Could not restart the database service."
    exit 9
fi


echo "Starting Jamf Pro Upgrade"
"$INSTALLER_DIRECTORY/$VERSION/jamfproinstaller.run"

if [[ "$?" != "0" ]]; then
    echo "FATAL: The Jamf Pro upgrade FAILED"
    exit 10
else
    echo "INFO: Jamf Pro upgrade completed successfully. Waiting a minute to continue..."
    sleep 120
fi

echo "Grabbing post upgrade backup of the Jamf Pro Database..."
/bin/jamf-pro database backup

if [[ "$?" != "0" ]]; then
    echo "FATAL: Could not backup Jamf Pro database."
    exit 12
else
    echo "Database backed up successfully."
fi

#-------------------------------------------------
# Detailed comment on a piece of code.
#-------------------------------------------------

#------------------------------------------------------------------------------
# End Script
#------------------------------------------------------------------------------
exit 0
