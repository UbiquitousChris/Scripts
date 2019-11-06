#!/bin/sh
###############################################################################
#
#
#
# Author Name: Weinkauf, Chris
# Author Date: Aug 08 2018
# Purpose:
#
#
# Change Log:
# July 16 2019, UbiquitousChris
# - Switched back to getting user details from Self Service as
# - Jamf PI-006954 has been fixed in JP 10.13
# - (See May 2 change log for deets)
# June 12 2019, UbiquitousChris
# - Compatibility with macOS Catalina
# - Removed requirement to turn the airport card off and on
# - Error dialogs are now displayed using AppleScript instead of Jamf Helpers
# May 14 2019, UbiquitousChris
# - Removed requirement to be able to contact AD
# May 02 2019, UbiquitousChris
# - Changed the method in which the script determines who is logged in to Self Service
# - due to Jamf PI-006954
# Sep 17 2018, UbiquitousChris
# - Fixed an issue that may cause the process to fail if it cant remove the
# - Automatic profile
# - Updated version to 6.1.1
# Sep 14 2018, UbiquitousChris
# - Adds function to remove the older automatic profile as well as
# - the older Example 802.1x profile
# - Updated version to 6.1.0
# Aug 30 2018, UbiquitousChris
# - Fixed issue that would cause WirelessSSID not to connect properly
# - Updated version to 6.0.1
# Aug 08 2018, UbiquitousChris
# - Initial Creation
###############################################################################

#-------------------
# Parse standard package arguments
#-------------------
__TARGET_VOL="$1"
__COMPUTER_NAME="$2"
__USERNAME="$3"
AUTO_ENROLL="$4"


#-------------------
# Functions
#-------------------

showErrorMessage()
{
    MESSAGE="$1"

    [[ "$MESSAGE" == "" ]] && MESSAGE="An error occurred attempting to install the network profile. For further assistance, contact the Service Desk."

    # "$JAMF_HELPER_BIN" -windowType utility \
    #     -title "Certificate Request Error" \
    #     -description "$MESSAGE" \
    #     -button1 "Ok" \
    #     -defaultButton 1 \
    #     -icon "$PANIC_ICON"

    /usr/bin/osascript -e 'tell application "Self Service"' -e 'display dialog "'"$MESSAGE"'" buttons {"Okay"} default button 1 with icon file "System:Library:CoreServices:CoreTypes.bundle:Contents:Resources:AlertStopIcon.icns"' -e 'end tell'
}

determineUserName()
{
    echo "INFO: Getting username from Jamf configuration"
    USER_PLIST="/Library/Managed Preferences/com.example.user.plist"
    if [[ -f "$USER_PLIST" ]]; then
        __USERNAME="$(/usr/bin/defaults read "$USER_PLIST" username)"
    else
        echo "ERROR: Plist file not found. Is this system assigned to anyone?"
        cleanUpInstallation
        exit 20
    fi

    if [[ -z "$__USERNAME" ]]; then
        echo "ERROR: Failed to obtain a username."
        cleanUpInstallation
        exit 21
    fi

    echo "INFO: Username is set to $__USERNAME"

}

#-------------------
# Variables
#-------------------

[[ "$AUTO_ENROLL" == "yes" ]] && determineUserName
[[ "$AUTO_ENROLL" == "true" ]] && determineUserName

JAMF_HELPER_BIN="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"
PANIC_ICON="/System/Library/CoreServices/ReportPanic.app/Contents/Resources/ProblemReporter.icns"
UPGRADE_ICON="/Applications/Utilities/AirPort Utility.app/Contents/Resources/AirPortUtility.icns"


OS_VERSION=$(sw_vers -productVersion | awk -F. '{print $2}')

CURRENT_LOGGED_IN_USER="$(ls -la /dev/console | awk '{print $3}')"
AD_PRINCIPAL_USERNAME="$__USERNAME@example.com"
SYSTEM_HOSTNAME="$(/usr/sbin/scutil --get ComputerName)"

PKI_DOMAIN="pki.example.com"
PKI_URL="https://$PKI_DOMAIN/certsrv"
AD_DOMAIN="example.com"

WI_FI_INTERFACE="$(/usr/sbin/networksetup -listallhardwareports | grep -A 1 Wi-Fi | grep Device | awk '{print $2}')"


TEMPORARY_DIRECTORY="/var/tmp/.csr_workspace"

## Set temp directory and intermediary file names and locations.
KEY="$TEMPORARY_DIRECTORY/autoenroll.key"
CSR="$TEMPORARY_DIRECTORY/autoenroll.csr"
DER="$TEMPORARY_DIRECTORY/certnew.cer"
PEM="$TEMPORARY_DIRECTORY/certnew.pem"
PK12="$TEMPORARY_DIRECTORY/autoenroll.p12"
MOBILECONFIG="$TEMPORARY_DIRECTORY/autoenroll.mobileconfig"

CERT_TYPE_USER="Example User Authentication"

MAX_COUNT=60

#------------------------------------------------------------------------------
# Start Script
#------------------------------------------------------------------------------

echo "INFO: Running as $__USERNAME."
echo "INFO: Current console user is $CURRENT_LOGGED_IN_USER."
echo "INFO: OS Version is 10.$OS_VERSION"

# Make sure required items are in place
if [[ "$PKI_DOMAIN" == "" ]] || [[ "$AD_DOMAIN" == "" ]]; then
    echo "ERROR: Either no PKI domain or AD domain was specified. Make sure a user is logged in to NoMAD."
    exit 5
fi

# Check server connectivity
PKI_SERVER_REACHABILITY="$(/sbin/ping -c 1 $PKI_DOMAIN | /usr/bin/grep ttl)"
#AD_DOMAIN_REACHABILITY="$(/sbin/ping -c 1 $AD_DOMAIN | /usr/bin/grep ttl)"

if [[ "$PKI_SERVER_REACHABILITY" == "" ]]; then
    echo "ERROR: Unable to contact required network resources."
    showErrorMessage "The certificate service or domain could not be contacted. Make sure you are connected to the corporate network or VPN before attempting to install your profile."
    exit 10
fi

# Build our temporary working directory
if [[ ! -d "$TEMPORARY_DIRECTORY" ]]; then
    echo "INFO: Creating directory $TEMPORARY_DIRECTORY."
    mkdir -p "$TEMPORARY_DIRECTORY"
else
    echo "INFO: Recreating directory $TEMPORARY_DIRECTORY."
    rm -Rf "$TEMPORARY_DIRECTORY"
    mkdir -p "$TEMPORARY_DIRECTORY"
fi

# Generate a Certificate Request to be deployed to the server.
echo "INFO: Generating CSR request"
/usr/bin/openssl req -new -batch -newkey rsa:2048 -nodes -outform PEM -keyout "$KEY" -out "$CSR" -subj "/CN=$AD_PRINCIPAL_USERNAME"

if [[ "$?" != "0" ]]; then
    echo "ERROR: Failed to generate CSR."
    showErrorMessage "There was a problem generating your certificate request. Please try again later or contact the Service Desk for assistance."
    exit 1
fi

# Encode the CSR to be used as part of a URL
echo "INFO: Encoding CSR..."
ENCODED_CSR=`cat ${CSR} | hexdump -v -e '1/1 "%02x\t"' -e '1/1 "%_c\n"' |
LANG=C awk '
    $1 == "20"                      { printf("%s",      "+");   next    }
    $2 ~  /^[a-zA-Z0-9.*()\/-]$/    { printf("%s",      $2);    next    }
                                    { printf("%%%s",    $1)             }'`


# Get the users password
while true; do
    echo "INFO: Getting users password"
    AD_PASSWORD=$(osascript -e 'tell application "Self Service"' -e 'text returned of (display dialog "Your network identity profile needs to be updated to maintain your connection to the CompName network.\n\nEnter the network password for '$__USERNAME' to install your identity profile." default answer "" buttons {"Cancel","OK"} default button 2 with hidden answer with icon file "System:Library:CoreServices:CoreTypes.bundle:Contents:Resources:SidebarNetwork.icns")' -e 'end tell')

    if [[ "$?" != "0" ]]; then
        echo "INFO: User cancelled at dialog."
        exit 0
    fi

    # Post to the Web Enrollment page and capture the ReqID when it's finished.
    echo "INFO: Posting request to $PKI_DOMAIN"
    REQ_ID=$(/usr/bin/curl -s -k --ntlm -u "$__USERNAME:$AD_PASSWORD" -d CertRequest=${ENCODED_CSR} -d SaveCert=yes -d Mode=newreq -d CertAttrib=CertificateTemplate:"${CERT_TYPE_USER}" "$PKI_URL/certfnsh.asp" | grep -m 1 ReqID | sed -e 's/.*ReqID=\(.*\)&amp.*/\1/g')
    REQ_ID=$(echo "$REQ_ID" | cut -d " " -f 1)
    echo "INFO: The request ID is $REQ_ID"

    if [[ ! "$REQ_ID" ]]; then
        echo "ERROR: Failed to get back a request ID."
        showErrorMessage "Either the password was incorrect or the certificate service could not be contacted. Please try again."
        continue
    else
        break
    fi
done

# Download the certificate from the CA
echo "INFO: Downloading Certificate..."
/usr/bin/curl -sk -o "$PEM" -A "Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.9.0.5) Gecko/2008120122 Firefox/3.0.5" --ntlm -u "${__USERNAME}:${AD_PASSWORD}" "${PKI_URL}/certnew.cer?ReqID=${REQ_ID}&Enc=b64"

if [[ "$?" != "0" ]]; then
    echo "ERROR: Failed to download certificate."
    showErrorMessage "There was a problem downloading your certificate. Please try again later or contact the Service Desk for assistance."
    exit 20
fi

echo "INFO: Converting "
/usr/bin/openssl pkcs12 -export -in ${PEM} -inkey ${KEY} -out ${PK12} -name "$SYSTEM_HOSTNAME" -passout pass:pass

if [[ "$?" != "0" ]]; then
    echo "ERROR: Failed to download certificate."
    showErrorMessage "There was a problem converting your certificate. Please try again later or contact the Service Desk for assistance."
    exit 20
fi

# Check to see if profile is already installed
echo "INFO: Checking for the presence of the profile"
if [[ $OS_VERSION -ge 13 ]]; then
    /usr/bin/profiles list -user "$CURRENT_LOGGED_IN_USER" | grep "39134079-EF02-45A5-8150-466A57856F08" &> /dev/null
else
    /usr/bin/profiles -L -U "$CURRENT_LOGGED_IN_USER" | grep "39134079-EF02-45A5-8150-466A57856F08" &> /dev/null
fi

# If we get back a value of 0, the profile was found
if [[ "$?" == "0" ]]; then
    echo "INFO: Network profile is already installed. Removing."

    if [[ $OS_VERSION -ge 13 ]]; then
        /usr/bin/profiles remove -user "$CURRENT_LOGGED_IN_USER" -identifier "39134079-EF02-45A5-8150-466A57856F08"
    else
        /usr/bin/profiles -R -p "39134079-EF02-45A5-8150-466A57856F08" -U "$CURRENT_LOGGED_IN_USER"
    fi

    if [[ "$?" != "0" ]]; then
        echo "ERROR: Remove the exisiting profile. It likely came from the MDM Server."
        showErrorMessage "The network profile is already installed on your computer and could not removed. If you are having trouble connecting to the network, please contact the Service Desk."
        exit 45
    fi
fi



#39134079-EF02-45A5-8150-466A57856F08

# Generate the mobileconfig file needed
echo '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1">
  <dict>
    <key>PayloadUUID</key>
    <string>39134079-EF02-45A5-8150-466A57856F08</string>
    <key>PayloadType</key>
    <string>Configuration</string>
    <key>PayloadOrganization</key>
    <string>CompName</string>
    <key>PayloadIdentifier</key>
    <string>39134079-EF02-45A5-8150-466A57856F08</string>
    <key>PayloadDisplayName</key>
    <string>CompName Network Settings (SS)</string>
    <key>PayloadDescription</key>
    <string>This profile installs the required 802.1x Certificates and configures your network adapters to connect to the CompName network.</string>
    <key>PayloadVersion</key>
    <integer>1</integer>
    <key>PayloadEnabled</key>
    <true/>
    <key>PayloadRemovalDisallowed</key>
    <false/>
    <key>PayloadScope</key>
    <string>System</string>
    <key>PayloadContent</key>
    <array>
      <dict>
        <key>PayloadUUID</key>
        <string>3C3D1ECF-FB90-495A-ABCF-5F22862351A2</string>
        <key>PayloadType</key>
        <string>com.apple.security.pkcs12</string>
        <key>PayloadOrganization</key>
        <string>CompName</string>
        <key>PayloadIdentifier</key>
        <string>3C3D1ECF-FB90-495A-ABCF-5F22862351A2</string>
        <key>PayloadDisplayName</key>
        <string>AD Certificate</string>
        <key>PayloadDescription</key>
        <string>CompName X.509 Certificate</string>
        <key>PayloadVersion</key>
        <integer>1</integer>
        <key>Password</key>
        <string>pass</string>
        <key>PayloadContent</key>
        <data>
        </data>
      </dict>
      <dict>
        <key>PayloadUUID</key>
        <string>B528C178-4601-472B-A07E-415641F6DBBE</string>
        <key>PayloadType</key>
        <string>com.apple.wifi.managed</string>
        <key>PayloadOrganization</key>
        <string>CompName</string>
        <key>PayloadIdentifier</key>
        <string>B528C178-4601-472B-A07E-415641F6DBBE</string>
        <key>PayloadDisplayName</key>
        <string>WiFi (WirelessSSID)</string>
        <key>PayloadDescription</key>
        <string/>
        <key>PayloadVersion</key>
        <integer>1</integer>
        <key>PayloadEnabled</key>
        <true/>
        <key>HIDDEN_NETWORK</key>
        <false/>
        <key>EncryptionType</key>
        <string>WPA</string>
        <key>PayloadCertificateUUID</key>
        <string>3C3D1ECF-FB90-495A-ABCF-5F22862351A2</string>
        <key>AutoJoin</key>
        <true/>
        <key>CaptiveBypass</key>
        <false/>
        <key>ProxyType</key>
        <string>None</string>
        <key>EAPClientConfiguration</key>
        <dict>
          <key>AcceptEAPTypes</key>
          <array>
            <integer>13</integer>
          </array>
          <key>TTLSInnerAuthentication</key>
          <string>MSCHAPv2</string>
        </dict>
        <key>SSID_STR</key>
        <string>WirelessSSID</string>
        <key>Interface</key>
        <string>BuiltInWireless</string>
        <key>SetupModes</key>
        <array>
            <string>System</string>
        </array>
      </dict>
      <dict>
        <key>PayloadUUID</key>
        <string>F2119255-D796-4F66-8E69-0E07BFF9BC7B</string>
        <key>PayloadType</key>
        <string>com.apple.globalethernet.managed</string>
        <key>PayloadOrganization</key>
        <string>CompName</string>
        <key>PayloadIdentifier</key>
        <string>F2119255-D796-4F66-8E69-0E07BFF9BC7B</string>
        <key>PayloadDisplayName</key>
        <string>Network</string>
        <key>PayloadDescription</key>
        <string/>
        <key>PayloadVersion</key>
        <integer>1</integer>
        <key>PayloadEnabled</key>
        <true/>
        <key>HIDDEN_NETWORK</key>
        <false/>
        <key>AutoJoin</key>
        <true/>
        <key>ProxyType</key>
        <string>None</string>
        <key>EncryptionType</key>
        <string>Any</string>
        <key>AuthenticationMethod</key>
        <string/>
        <key>Interface</key>
        <string>AnyEthernet</string>
        <key>PayloadCertificateUUID</key>
        <string>3C3D1ECF-FB90-495A-ABCF-5F22862351A2</string>
        <key>EAPClientConfiguration</key>
        <dict>
          <key>AcceptEAPTypes</key>
          <array>
            <integer>13</integer>
          </array>
          <key>TTLSInnerAuthentication</key>
          <string>MSCHAPv2</string>
          <key>TLSCertificateIsRequired</key>
          <true/>
        </dict>
        <key>SetupModes</key>
        <array>
            <string>System</string>
        </array>
      </dict>
    </array>
  </dict>
</plist>
' > ${MOBILECONFIG}



## Use plistbuddy to insert the pkcs12 file into the mobileconfig.
echo "INFO: Applying certificate to Configuration Profile"
/usr/libexec/PlistBuddy -c "Import PayloadContent:0:PayloadContent ${PK12}" ${MOBILECONFIG}

# Set the IFS var to look for newlines as separators
OLD_IFS="$IFS"
IFS=$'\n'

# Loop through every identity found on the system
for IDENTITY in $(security find-identity | egrep -o -v '[A-Z0-9]{8}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{12}' | egrep '[A-Z0-9]{40}' | sort -u | cut -d '"' -f 2); do
    # Check to see if the identity came from our 802.1x environment
    security find-certificate -c "$IDENTITY" -p -Z | openssl x509 -noout -text | grep -om1 "pki.example.com/crl/CA" &> /dev/null

    # If it did, remove it
    if [[ "$?" == "0" ]]; then
        echo "INFO: Identity found for $IDENTITY. Removing."

        # Get the SHA-1 hash of the identity in question.
        CERT_HASH="$(security find-certificate -Z -c "$IDENTITY" | grep -e 'SHA-1 hash:' | awk -F': ' '{print $2}')"

        # Delete the dang thang
        security delete-certificate -Z "$CERT_HASH"
    fi
done

# Reset the IFS var
IFS="$OLD_IFS"

# Install the profile to the user
echo "INFO: Installing new profile."
if [[ $OS_VERSION -ge 13 ]]; then
    /usr/bin/profiles install -path "$MOBILECONFIG"
else
    /usr/bin/profiles -I -F "$MOBILECONFIG"
fi

if [[ "$?" != "0" ]]; then
    echo "ERROR: Failed to install profile."
    showErrorMessage "There was a problem installing the network profile. The profile may already exist. Please try again later or contact the Service Desk for assistance."
    exit 50
fi

# Update the certificate expiration
echo "INFO: Updating certificate expiration"
# Make sure the Example folder exists
[[ ! -d "/Library/Example" ]] && mkdir -p "/Library/Example"

# Remove legacy files if they exist
[[ -f "/Library/Example/cert_installation_time" ]] && rm "/Library/Example/cert_installation_time"
[[ -f "/Library/Example/cert_expiration_time" ]] && rm "/Library/Example/cert_expiration_time"

# Get the certificate expiration from the certificate file we made
CERTIFICATE_EXPIRATION="$(cat "$PEM" | openssl x509 -noout -enddate | awk -F= '{print $2}')"
echo "INFO: Certificate expiration date is $CERTIFICATE_EXPIRATION"
echo "$(date -j -f "%b %d %T %Y %Z" "$CERTIFICATE_EXPIRATION" "+%s")" > /Library/Example/cert_expiration_time

# Remove example-Visitor network
echo "INFO: Updating preferred wireless networks..."
/usr/sbin/networksetup -removepreferredwirelessnetwork $WI_FI_INTERFACE "example-Visitor"
/usr/sbin/networksetup -removepreferredwirelessnetwork $WI_FI_INTERFACE "Example-Visitor"
/usr/sbin/networksetup -removepreferredwirelessnetwork $WI_FI_INTERFACE "ExampleCorp"

#-------------------------------------------------
# Detailed comment on a piece of code.
#-------------------------------------------------

#------------------------------------------------------------------------------
# End Script
#------------------------------------------------------------------------------
exit 0
