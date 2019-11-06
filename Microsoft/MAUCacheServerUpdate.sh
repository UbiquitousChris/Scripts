#!/bin/sh
###############################################################################
# 
# 
#
# Author Name: Weinkauf, Chris
# Author Date: Mar 28 2019
# Purpose: Updates the collateral lists on the MAU Caching server
#
#
# Change Log:
# Mar 28 2019, UbiquitousChris
# - Initial Creation
###############################################################################

#-------------------
# Variables
#-------------------

SCRIPT_NAME=`basename $0`
SCRIPT_VERSION="1.0.0"

MAUCACHE_BIN="/usr/local/MAUCacheAdmin"

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

checkCachePath()
{
    # Make sure the MAUCacheAdmin is installed where we expect and that the
    # specified cache path is present
    if [[ ! -f "$MAUCACHE_BIN" ]]; then
        echo "ERROR: The MAUCacheAdmin binary is missing from $MAUCACHE_BIN."
        exit 2
    fi

    if [[ ! -d "$CACHE_PATH" ]]; then
        echo "ERROR: The cache path $CACHE_PATH does not exist."
        exit 1
    fi
}

updateDesktopEngineering()
{
    checkCachePath
    echo "Updating DesktopEngineering collateral"

    # Check for DesktopEngineering collateral folder and create if it doesn't exist
    if [[ ! -d "$CACHE_PATH/collateral/DesktopEngineering" ]]; then
        echo "Creating collateral directory"
        mkdir -p "$CACHE_PATH/collateral/DesktopEngineering"
    fi

    # Start by getting all the available collateral versions
    COLLATERAL_VERSIONS=$("$MAUCACHE_BIN" --CachePath:"$CACHE_PATH" --ShowCollateral | awk -F'[][]' '{print $2}' | uniq | grep '^[0-9]')

    # Check that we actually got something back
    if [[ "$COLLATERAL_VERSIONS" == "" ]]; then
        echo "ERROR: No collateral was returned from the master list."
        exit 5
    fi

    for COLLATERAL in $COLLATERAL_VERSIONS; do
        "$MAUCACHE_BIN" --CachePath:"$CACHE_PATH" --CopyCollateralFrom:$COLLATERAL --CopyCollateralTo:DesktopEngineering
    done

    echo "Updating DesktopEngineering collateral completed successfully."
}

updateGroup()
{
    GROUP_NAME="$1"
    checkCachePath

    # Check that a group name was passed in
    if [[ "$GROUP_NAME" == "" ]]; then
        echo "ERROR: A group name must be passed in."
        exit 7
    elif [[ "$GROUP_NAME" == "DesktopEngineering" ]]; then
        echo "ERROR: DesktopEngineering is special. Use --updateDesktopEngineering instead."
        exit 0
    fi

    # Check for group collateral folder and create if it doesn't exist
    if [[ ! -d "$CACHE_PATH/collateral/$GROUP_NAME" ]]; then
        echo "Creating collateral directory for $GROUP_NAME"
        mkdir -p "$CACHE_PATH/collateral/$GROUP_NAME"
    fi

    echo "Updating $GROUP_NAME collateral based on DesktopEngineering collateral"
    "$MAUCACHE_BIN" --CachePath:"$CACHE_PATH" --CopyCollateralFrom:DesktopEngineering --CopyCollateralTo:"$GROUP_NAME"

    echo "Updating $GROUP_NAME collateral completed successfully."
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
        --cachepath | -p)
            shift
            CACHE_PATH="$1"
            shift
            ;;
        --desktopEngineering | --de | -d)
            updateDesktopEngineering
            shift
            ;;
        --updateGroup | -u)
            shift
            updateGroup "$1"
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

#-------------------------------------------------
# Detailed comment on a piece of code.
#-------------------------------------------------

#------------------------------------------------------------------------------
# End Script
#------------------------------------------------------------------------------
exit 0
