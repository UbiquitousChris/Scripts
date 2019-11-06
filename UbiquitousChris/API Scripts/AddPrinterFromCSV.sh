#!/bin/sh
###############################################################################
#
#
#
# Author Name: Weinkauf, Chris
# Author Date: Feb 01 2019
# Purpose:
#
#
# Change Log:
# Feb 01 2019, UbiquitousChris
# - Initial Creation
###############################################################################

#-------------------
# Variables
#-------------------

SCRIPT_NAME=`basename $0`
SCRIPT_VERSION="1.0.0"

SS_ICON_ID=""

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

checkScriptArguments()
{
    # Check that a file was specified
    if [[ "$CSV_FILE" == "" ]] && [[ "$1" != "yes" ]]; then
        echo "ERROR: A CSV file must be specified with --csv or -f."
        exit 5
    elif [[ ! -f "$CSV_FILE" ]] && [[ "$1" != "yes" ]]; then
        echo "ERROR: The specified CSV file could not be found."
        exit 6
    fi

    # If a URL was not passed in, attempt to pull from the local machine
    if [[ "$JAMF_PRO_URL" == "" ]]; then
        echo "Jamf Pro URL was not specified. Attempting to get URL from local preferences."
        JAMF_PRO_URL="$(/usr/bin/defaults read "/Library/Preferences/com.jamfsoftware.jamf.plist" jss_url)"

        # If we couldn't pull from a local machine, error out
        if [[ "$?" != "0" ]]; then
            echo "ERROR: Jamf Pro URL needs to be specified with --jamfAddress"
            exit 10
        fi
    fi

    # If a username or password wasnt passed in, request it
    [[ "$API_USERNAME" == "" ]] && read -p "API Username: " API_USERNAME
    [[ "$API_PASSWORD" == "" ]] && read -s -p "API Password: " API_PASSWORD
}

resetAllPrinters()
{


    checkScriptArguments 'yes'

    while true; do
        read -p "WARNING: You're about to clear ALL printers and print policies from the JPS $JAMF_PRO_URL. Are you sure you want to do this? Type yes or no:" SELECTION

        if [[ "$SELECTION" == "yes" ]]; then
            break
        elif [[ "$SELECTION" == "no" ]]; then
            echo "Probably for the best. Bye."
            exit 0
        else
            echo "Type yes or no."
        fi
    done

    ALL_PRINTER_IDS="$(curl -sku "$API_USERNAME:$API_PASSWORD" -H "accept: text/xml" ${JAMF_PRO_URL}JSSResource/printers | xmllint --xpath '/printers/printer/id' - | tr -d '<id>' | tr '//' ' ')"

    for PRINTER_ID in $ALL_PRINTER_IDS; do
        echo "Deleting printer $PRINTER_ID"
        curl -sku "$API_USERNAME:$API_PASSWORD" -H "content-type: text/xml" ${JAMF_PRO_URL}JSSResource/printers/id/$PRINTER_ID -X DELETE
    done

    # return
    ALL_POLICY_IDS="$(curl -sku "$API_USERNAME:$API_PASSWORD" -H "accept: text/xml" ${JAMF_PRO_URL}JSSResource/policies | xmllint --xpath '/policies/policy/id' - | tr -d '<id>' | tr '//' ' ')"

    for POLICY in $ALL_POLICY_IDS; do
        echo "Checking if policy $POLICY is in Printers category"
        CATEGORY="$(curl -sku "$API_USERNAME:$API_PASSWORD" -H "accept: text/xml" ${JAMF_PRO_URL}JSSResource/policies/id/$POLICY | xmllint --xpath '/policy/general/category/name/text()' -)"

        echo "CATEGORY: $CATEGORY"

        if [[ "$CATEGORY" == "Printers" ]]; then
            echo "Policy $POLICY is a Printer policy. Deleting."
            curl -sku "$API_USERNAME:$API_PASSWORD" -H "content-type: text/xml" ${JAMF_PRO_URL}JSSResource/policies/id/$POLICY -X DELETE
        fi
    done



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
        --apiUser | -u)
            shift
            API_USERNAME="$1"
            shift
            ;;
        --apiPassword | -p)
            shift
            API_PASSWORD="$1"
            shift
            ;;
        --jamfAddress | -url)
            shift
            JAMF_PRO_URL="$1"
            shift
            ;;
        --csv | -f)
            shift
            CSV_FILE="$1"
            shift
            ;;
        --reset | -r)
            resetAllPrinters
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

# Make sure all the proper values have been passed in
checkScriptArguments

echo "${JAMF_PRO_URL}JSSResource/categories/name/Printers"
curl -sku "$API_USERNAME:$API_PASSWORD" -H "accept: text/xml" ${JAMF_PRO_URL}JSSResource/categories/name/Printers | xmllint --xpath '/category/id/text()' -

CATEGORY_ID="$(curl -sku "$API_USERNAME:$API_PASSWORD" -H "accept: text/xml" ${JAMF_PRO_URL}JSSResource/categories/name/Printers | xmllint --xpath '/category/id/text()' -)"
echo "CATEGORY_ID: $CATEGORY_ID"

DE_GROUP_ID="$(curl -sku "$API_USERNAME:$API_PASSWORD" -H "accept: text/xml" ${JAMF_PRO_URL}JSSResource/computergroups/name/Desktop%20Engineering | xmllint --xpath '/computer_group/id/text()' -)"
echo "DE_GROUP_ID: $DE_GROUP_ID"

# MASS_ID="$(curl -sku "$API_USERNAME:$API_PASSWORD" -H "accept: text/xml" ${JAMF_PRO_URL}JSSResource/computergroups/name/Mergers%20and%20Acquisitions%20Sequestered%20Site | xmllint --xpath '/computer_group/id/text()' -)"
# echo "MASS_ID: $MASS_ID"

while IFS='\n' read -r PRINTER_LINE || [[ -n "$PRINTER_LINE" ]]; do
    echo "_________________________________________________________"
    PRT_SERVER="$(echo "$PRINTER_LINE" | awk -F, '{print $1}')"
    PRT_QUEUE="$(echo "$PRINTER_LINE" | awk -F, '{print $2}')"
    PRT_LOCATION="$(echo "$PRINTER_LINE" | awk -F, '{print $3}' | tr '/' ', ')"
    PRT_MODEL="$(echo "$PRINTER_LINE" | awk -F, '{print $4}')"
    PRT_PPD="$(echo "$PRINTER_LINE" | awk -F, '{print $5}')"
    BUILDING="$(echo "$PRINTER_LINE" | awk -F, '{print $6}')"

    PRT_QUEUE_NAME="$PRT_QUEUE - $PRT_LOCATION"

    HTML_SAFE_BUILDING="$(echo "${BUILDING// /%20}")"
    HTML_SAFE_BUILDING=${HTML_SAFE_BUILDING%$'\r'}
    CUPS_SAFE_QUEUE="$(echo $PRT_QUEUE | tr -d ' ')"

    HTML_SAFE_PRT_QUEUE=${PRT_QUEUE// /%20}
    HTML_SAFE_PRT_QUEUE=${HTML_SAFE_PRT_QUEUE//,/%2C}
    HTML_SAFE_PRT_QUEUE=${HTML_SAFE_PRT_QUEUE%$'\r'}
    echo "HTML_SAFE_PRT_QUEUE: $HTML_SAFE_PRT_QUEUE"

    [[ "$PRT_SERVER" == "server" ]] && continue

    [[ "$PRT_MODEL" == "" ]] && PRT_MODEL="Generic PostScript Printer"
    [[ "$PRT_PPD" == "" ]] && PRT_PPD="/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/PrintCore.framework/Resources/Generic.ppd"
    BUILDING_ID="$(curl -sku "$API_USERNAME:$API_PASSWORD" -H "accept: text/xml" ${JAMF_PRO_URL}JSSResource/buildings/name/$HTML_SAFE_BUILDING | xmllint --xpath '/building/id/text()' -)"
    echo "PRT_SERVER: $PRT_SERVER"
    echo "PRT_QUEUE: $PRT_QUEUE"
    echo "PRT_LOCATION: $PRT_LOCATION"
    echo "PRT_MODEL: $PRT_MODEL"
    echo "PRT_PPD: $PRT_PPD"
    echo "BUILDING: $BUILDING"
    echo "HTML_SAFE_BUILDING: $HTML_SAFE_BUILDING"
    echo "HTML_SAFE_PRT_QUEUE: $HTML_SAFE_PRT_QUEUE"
    echo "BUILDING_ID: $BUILDING_ID"

    if [[ "$PRT_MODEL" != "Generic PostScript Printer" ]]; then
        USE_GENERIC="false"
    else
        USE_GENERIC="true"
    fi


    echo "Generating PPD file."
    lpadmin -p "$CUPS_SAFE_QUEUE($PRT_SERVER)" -L "$PRT_LOCATION" -E -v "smb://$PRT_SERVER.example.com/$HTML_SAFE_PRT_QUEUE" -m "$PRT_PPD" -o auth-info-required=negotiate

    echo "Submitting a test print job."

    echo "PRT_SERVER: $PRT_SERVER
    PRT_QUEUE: $PRT_QUEUE
    PRT_LOCATION: $PRT_LOCATION
    PRT_MODEL: $PRT_MODEL
    PRT_PPD: $PRT_PPD
    BUILDING: $BUILDING
    HTML_SAFE_BUILDING: $HTML_SAFE_BUILDING
    HTML_SAFE_PRT_QUEUE: $HTML_SAFE_PRT_QUEUE
    BUILDING_ID: $BUILDING_ID" > /tmp/testprint.txt

    lpr -P "$CUPS_SAFE_QUEUE($PRT_SERVER)" /tmp/testprint.txt

    if [[ "$?" != "0" ]]; then
        echo "WARNING: TEST PRINT JOB FAILED!!!"
    fi

done < "$CSV_FILE"

read -p "Add print queues to JPS via Jamf Admin. Press enter to start adding policies when done." SELECTION

while IFS='\n' read -r PRINTER_LINE || [[ -n "$PRINTER_LINE" ]]; do
    echo "_________________________________________________________"
    PRT_SERVER="$(echo "$PRINTER_LINE" | awk -F, '{print $1}')"
    PRT_QUEUE="$(echo "$PRINTER_LINE" | awk -F, '{print $2}')"
    PRT_LOCATION="$(echo "$PRINTER_LINE" | awk -F, '{print $3}' | tr '/' ', ')"
    PRT_MODEL="$(echo "$PRINTER_LINE" | awk -F, '{print $4}')"
    PRT_PPD="$(echo "$PRINTER_LINE" | awk -F, '{print $5}')"
    BUILDING="$(echo "$PRINTER_LINE" | awk -F, '{print $6}')"

    CUPS_SAFE_QUEUE="$(echo $PRT_QUEUE | tr -d ' ')"

    PRT_QUEUE_NAME="$CUPS_SAFE_QUEUE($PRT_SERVER)"

    HTML_SAFE_BUILDING="$(echo "${BUILDING// /%20}")"
    HTML_SAFE_BUILDING=${HTML_SAFE_BUILDING%$'\r'}




    [[ "$PRT_SERVER" == "server" ]] && continue

    [[ "$PRT_MODEL" == "" ]] && PRT_MODEL="Generic PostScript Printer"
    [[ "$PRT_PPD" == "" ]] && PRT_PPD="/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/PrintCore.framework/Resources/Generic.ppd"
    BUILDING_ID="$(curl -sku "$API_USERNAME:$API_PASSWORD" -H "accept: text/xml" ${JAMF_PRO_URL}JSSResource/buildings/name/$HTML_SAFE_BUILDING | xmllint --xpath '/building/id/text()' -)"
    echo "PRT_SERVER: $PRT_SERVER"
    echo "PRT_QUEUE: $PRT_QUEUE"
    echo "CUPS_SAFE_QUEUE: $CUPS_SAFE_QUEUE"
    echo "PRT_LOCATION: $PRT_LOCATION"
    echo "PRT_MODEL: $PRT_MODEL"
    echo "PRT_PPD: $PRT_PPD"
    echo "BUILDING: $BUILDING"
    echo "HTML_SAFE_BUILDING: $HTML_SAFE_BUILDING"
    echo "BUILDING_ID: $BUILDING_ID"

    if [[ "$PRT_MODEL" != "Generic PostScript Printer" ]] && [[ "$PRT_MODEL" != "Generic PCL Laser Printer" ]]; then
        USE_GENERIC="false"
        SCRIPT="<scripts>
          <size>1</size>
          <script>
            <id>376</id>
            <name>Jamf-RunAPolicy.sh</name>
            <priority>Before</priority>
            <parameter4>CanonImageRunnerDrivers</parameter4>
            <parameter5/>
            <parameter6/>
            <parameter7/>
            <parameter8/>
            <parameter9/>
            <parameter10/>
            <parameter11/>
          </script>
        </scripts>"
    else
        USE_GENERIC="true"
        SCRIPT="<scripts></scripts>"
    fi


    HTML_SAFE_PRT_QUEUE=${PRT_QUEUE_NAME// /%20}
    HTML_SAFE_PRT_QUEUE=${HTML_SAFE_PRT_QUEUE//,/%2C}
    HTML_SAFE_PRT_QUEUE=${HTML_SAFE_PRT_QUEUE%$'\r'}
    echo "HTML_SAFE_PRT_QUEUE: $HTML_SAFE_PRT_QUEUE"


    PRT_ID="$(curl -sku "$API_USERNAME:$API_PASSWORD" -H "accept: text/xml" ${JAMF_PRO_URL}JSSResource/printers/name/$HTML_SAFE_PRT_QUEUE | xmllint --xpath '/printer/id/text()' -)"
    echo "PRT_ID: $PRT_ID"


    echo "Generating policy XML"
    POLICY_XML="<policy>
  <general>
    <name>$PRT_QUEUE(${PRT_SERVER%$'\r'})</name>
    <enabled>true</enabled>
    <trigger>USER_INITIATED</trigger>
    <trigger_checkin>false</trigger_checkin>
    <trigger_enrollment_complete>false</trigger_enrollment_complete>
    <trigger_login>false</trigger_login>
    <trigger_logout>false</trigger_logout>
    <trigger_network_state_changed>false</trigger_network_state_changed>
    <trigger_startup>false</trigger_startup>
    <trigger_other/>
    <frequency>Ongoing</frequency>
    <location_user_only>false</location_user_only>
    <target_drive>/</target_drive>
    <offline>false</offline>
    <category>
      <id>$CATEGORY_ID</id>
      <name>Printers</name>
    </category>
    <date_time_limitations>
      <activation_date/>
      <activation_date_epoch>0</activation_date_epoch>
      <activation_date_utc/>
      <expiration_date/>
      <expiration_date_epoch>0</expiration_date_epoch>
      <expiration_date_utc/>
      <no_execute_on/>
      <no_execute_start/>
      <no_execute_end/>
    </date_time_limitations>
    <network_limitations>
      <minimum_network_connection>No Minimum</minimum_network_connection>
      <any_ip_address>true</any_ip_address>
      <network_segments/>
    </network_limitations>
    <override_default_settings>
      <target_drive>default</target_drive>
      <distribution_point/>
      <force_afp_smb>false</force_afp_smb>
      <sus>default</sus>
      <netboot_server>current</netboot_server>
    </override_default_settings>
    <network_requirements>Any</network_requirements>
    <site>
      <id>-1</id>
      <name>None</name>
    </site>
  </general>
  <scope>
    <all_computers>false</all_computers>
    <computers/>
    <computer_groups>
      <computer_group>
        <id>$DE_GROUP_ID</id>
        <name>Desktop Engineering</name>
      </computer_group>
    </computer_groups>
    <buildings>
      <building>
        <id>$BUILDING_ID</id>
        <name>$BUILDING</name>
      </building>
    </buildings>
    <departments/>
    <limit_to_users>
      <user_groups/>
    </limit_to_users>
    <limitations>
      <users/>
      <user_groups/>
      <network_segments/>
      <ibeacons/>
    </limitations>
    <exclusions>
      <computers/>
      <computer_groups/>
      <buildings/>
      <departments/>
      <users/>
      <user_groups/>
      <network_segments/>
      <ibeacons/>
    </exclusions>
  </scope>
  $SCRIPT
  <self_service>
    <use_for_self_service>true</use_for_self_service>
    <self_service_display_name>$PRT_QUEUE</self_service_display_name>
    <install_button_text>Install</install_button_text>
    <reinstall_button_text>Reinstall</reinstall_button_text>
    <self_service_description>This will add the $PRT_QUEUE printer located in $PRT_LOCATION, to your Mac. Additional drivers and support will be installed if required by this printer.</self_service_description>
    <force_users_to_view_description>false</force_users_to_view_description>
    <self_service_icon>
      <id>$SS_ICON_ID</id>
      <filename>GenericPrinterIcon.png</filename>
      <uri>https://dev.example.com:8443//iconservlet/?id=$SS_ICON_ID</uri>
    </self_service_icon>
    <feature_on_main_page>false</feature_on_main_page>
    <self_service_categories>
      <category>
        <id>$CATEGORY_ID</id>
        <name>Printers</name>
        <display_in>true</display_in>
        <feature_in>false</feature_in>
      </category>
    </self_service_categories>
    <notification>false</notification>
    <notification>Self Service</notification>
    <notification_subject>$PRT_QUEUE</notification_subject>
    <notification_message/>
  </self_service>
  <printers>
    <size>1</size>
    <leave_existing_default/>
    <printer>
      <id>$PRT_ID</id>
      <name>$PRT_QUEUE_NAME</name>
      <action>install</action>
      <make_default>true</make_default>
    </printer>
  </printers>
  <reboot>
    <message>This computer will restart in 5 minutes. Please save anything you are working on and log out by choosing Log Out from the bottom of the Apple menu.</message>
    <startup_disk>Current Startup Disk</startup_disk>
    <specify_startup/>
    <no_user_logged_in>Restart if a package or update requires it</no_user_logged_in>
    <user_logged_in>Restart if a package or update requires it</user_logged_in>
    <minutes_until_reboot>5</minutes_until_reboot>
    <start_reboot_timer_immediately>false</start_reboot_timer_immediately>
    <file_vault_2_reboot>false</file_vault_2_reboot>
  </reboot>
  <files_processes>
    <search_by_path/>
    <delete_file>false</delete_file>
    <locate_file/>
    <update_locate_database>false</update_locate_database>
    <spotlight_search/>
    <search_for_process/>
    <kill_process>false</kill_process>
    <run_command>/usr/sbin/lpadmin -p '$CUPS_SAFE_QUEUE(${PRT_SERVER%$'\r'})' -o auth-info-required=negotiate</run_command>
  </files_processes>
  <user_interaction>
    <message_start/>
    <allow_users_to_defer>false</allow_users_to_defer>
    <allow_deferral_until_utc/>
    <message_finish>$PRT_QUEUE has been added to your computer.</message_finish>
  </user_interaction>
</policy>"


echo "Posting Policy XML"
curl -sku "$API_USERNAME:$API_PASSWORD" -H "content-type: text/xml" ${JAMF_PRO_URL}JSSResource/policies/id/0 -X POST -d "$POLICY_XML"

lpadmin -x "$CUPS_SAFE_QUEUE($PRT_SERVER)"


done < "$CSV_FILE"

#-------------------------------------------------
# Detailed comment on a piece of code.
#-------------------------------------------------

#------------------------------------------------------------------------------
# End Script
#------------------------------------------------------------------------------
exit 0
