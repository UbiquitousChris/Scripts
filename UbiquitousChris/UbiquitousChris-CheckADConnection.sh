#!/bin/sh
###############################################################################
# 
# 
#
# Author Name: Weinkauf, Chris
# Author Date: Jul 17 2018
# Purpose:
#
#
# Change Log:
# Sep 14 2018, UbiquitousChris
# - Added check for bindless AD marker for DEP
# Jul 17 2018, UbiquitousChris
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

AD_DOMAIN="$(/usr/sbin/dsconfigad -show | grep "Active Directory Domain" | awk -F'= ' '{print $2}')"
AD_SEARCH_PATH="$(dscl /Search -read / SearchPath | grep "/Active Directory/" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
COMPUTER_ACCT="$(/usr/sbin/dsconfigad -show | grep "Computer Account" | awk -F'= ' '{print $2}')"

ICON="/System/Library/CoreServices/Applications/Directory Utility.app/Contents/Resources/DirectoryUtility.icns"
JAMF_HELPER="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"
RESULT_MESSAGE="The connection to $AD_DOMAIN is working properly."

BINDLESS_MARK="/var/db/.bindlessAD"

#-------------------
# Functions
#-------------------

showResultToUser() {
    "$JAMF_HELPER" -windowType utility \
        -title "Active Directory Check" \
        -description "$RESULT_MESSAGE" \
        -icon "$ICON" \
        -button1 "Quit" \
        -defaultButton 1 &

    echo "INFO: Directory test completed at $(date)"
    exit 0
}

#------------------------------------------------------------------------------
# Start Script
#------------------------------------------------------------------------------

echo "INFO: Starting AD test at $(date)"

# Check for the bindless marker
if [[ -f "$BINDLESS_MARK" ]] && [[ "$AD_DOMAIN" == "" ]]; then
    echo "INFO: System is bindless."
    RESULT_MESSAGE="This computer is configured for bindless AD and is not joined to the domain. For domain services, log in to the NoMAD application."
    showResultToUser
    exit 0
fi

# If we didn't get back a domain in the variable, we're probably not bound.
if [[ "$AD_DOMAIN" == "" ]]; then
    echo "ERROR: We don't appear to be bound to AD."
    RESULT_MESSAGE="This computer does not appear to be bound to an Active Directory domain."
    showResultToUser
else
    echo "INFO: System is bound to $AD_DOMAIN"
fi

# If we didn't get a search path, AD is misconfigured for login
if [[ "$AD_SEARCH_PATH" == "" ]]; then
    echo "ERROR: No search path is defined for $AD_DOMAIN"
    RESULT_MESSAGE="This system appears to be joined to $AD_DOMAIN, but an Active Directory search path is not defined. Domain accounts won't be available or updated until a search path is set in Directory Utility."
    showResultToUser
else
    echo "INFO: Seach path is set to $AD_SEARCH_PATH."
fi

# Ping the domain three times
echo "INFO: Checking connection to domain"
ping -c 3 "$AD_DOMAIN" &> /dev/null

if [[ "$?" != "0" ]]; then
    echo "ERROR: Could not ping $AD_DOMAIN or connection was intermittent."
    RESULT_MESSAGE="The domain $AD_DOMAIN could not be contacted. Directory services will not work until connected to the corporate network."
    showResultToUser
else
    echo "INFO: $AD_DOMAIN is available."
fi

# Attempt to read from the domain
dscl "$AD_SEARCH_PATH" -read "Computers/$COMPUTER_ACCT" > /dev/null

if [[ "$?" != "0" ]]; then
    echo "ERROR: Could not read $COMPUTER_ACCT from $AD_DOMAIN. The connection appears to be severed."
    RESULT_MESSAGE="This computer appears to be joined to $AD_DOMAIN, but we're unable to read the computer record. The binding may have been severed or the computer's time may be wrong."
    showResultToUser
else
    echo "INFO: Able to read computer record successfully."
fi

#-------------------------------------------------
# Detailed comment on a piece of code.
#-------------------------------------------------

# If we made it this far, the connection to AD is working properly
echo "INFO: All requirements satisfied. The connection appears to be working properly."
showResultToUser


#------------------------------------------------------------------------------
# End Script
#------------------------------------------------------------------------------
exit 0
