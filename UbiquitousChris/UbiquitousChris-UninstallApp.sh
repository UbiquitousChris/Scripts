#!/bin/zsh
###############################################################################
# 
# 
#
# Author Name: Weinkauf, Chris
# Author Date: Oct 13 2019
# Purpose: Uninstalls a user selected app bundle and all associated files
#
#
# Change Log:
# Oct 13 2019, UbiquitousChris
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

UNREMOVABLE_CFBUNDLEIDS=(CbDefense
com.commvault.LaunchEdgeMonitor
com.forescout.secure_connector
com.commvault.processmanager
com.qualys.cloud-agent
com.netskope.ui.utils.Remove-Netskope-Client
com.jamfsoftware.selfservice.mac
com.jamf.management.Jamf
com.jamf.management.jamfAAD
com.jamfsoftware.Management-Action
com.jamfsoftware.jamfHelper
com.example.AdministrativePrivilegesActive
com.netskope.client.Netskope-Client
com.github.sheagcraig.yo
com.microsoft.autoupdate2
com.microsoft.OneDrive
com.microsoft.CompanyPortal)

BUILTIN_APP_IDENTIFIERS=(com.apple.AppStore
com.apple.Automator
com.apple.iBooksX
com.apple.calculator
com.apple.iCal
com.apple.Chess
com.apple.AddressBook
com.apple.Dictionary
com.apple.FaceTime
com.apple.findmy
com.apple.FontBook
com.apple.Home
com.apple.Image_Capture
com.apple.launchpad.launcher
com.apple.mail
com.apple.Maps
com.apple.iChat
com.apple.exposelauncher
com.apple.Music
com.apple.news
com.apple.Notes
com.apple.PhotoBooth
com.apple.Photos
com.apple.podcasts
com.apple.Preview
com.apple.QuickTimePlayerX
com.apple.reminders
com.apple.siri.launcher
com.apple.Stickies
com.apple.stocks
com.apple.systempreferences
com.apple.TV
com.apple.TextEdit
com.apple.backup.launcher
com.apple.ActivityMonitor
com.apple.airport.airportutility
com.apple.audio.AudioMIDISetup
com.apple.BluetoothFileExchange
com.apple.bootcampassistant
com.apple.ColorSyncUtility
com.apple.Console
com.apple.DigitalColorMeter
com.apple.DiskUtility
com.apple.grapher
com.apple.keychainaccess
com.apple.MigrateAssistant
com.apple.screenshot.launcher
com.apple.ScriptEditor2
com.apple.SystemProfiler
com.apple.Terminal
com.apple.VoiceOverUtility
com.apple.AVB-Audio-Configuration
com.apple.print.add
com.apple.AddressBook.UrlForwarder
com.apple.AirPlayUIAgent
com.apple.AirPortBaseStationAgent
com.apple.AppleFileServer
com.apple.AppleScriptUtility
com.apple.AutomatorInstaller
com.apple.BluetoothSetupAssistant
com.apple.BluetoothUIServer
com.apple.CalendarFileHandler
com.apple.CaptiveNetworkAssistant
com.apple.CertificateAssistant
com.apple.controlstrip
com.apple.CoreLocationAgent
com.apple.coreservices.uiagent
com.apple.databaseevents
com.apple.DiscHelper
com.apple.DiskImageMounter
com.apple.dock
com.apple.DwellControl
com.apple.EscrowSecurityAlert
com.apple.ExpansionSlotUtility
com.apple.finder
com.apple.FolderActionsDispatcher
com.apple.gamecenter
com.apple.helpviewer
com.apple.imageevents
com.apple.dt.CommandLineTools.installondemand
com.apple.PackageKit.Install-in-Progress
com.apple.Installer-Progress
com.apple.installer
com.apple.JarLauncher
com.apple.JavaWebStart
com.apple.KeyboardAccessAgent
com.apple.KeyboardSetupAssistant
com.apple.security.Keychain-Circle-Notification
com.apple.Language-Chooser
com.apple.locationmenu
com.apple.ManagedClient
com.apple.MemorySlotUtility
com.apple.NetAuthAgent
com.apple.notificationcenterui
com.apple.NowPlayingTouchUI
com.apple..NowPlayingWidgetContainer
com.apple.OBEXAgent
com.apple.ODSAgent
com.apple.OSDUIHelper
com.apple.PIPAgent
com.apple.PairedDevices
com.apple.Pass-Viewer
com.apple.PhotoLibraryMigrationUtility
com.apple.podcasts.PodcastsAuthAgent
com.apple.PowerChime
com.apple.ProblemReporter
com.apple.RapportUIAgent
com.apple.pluginIM.pluginIMRegistrator
com.apple.ReportPanic
com.apple.ScreenSaver.Engine
com.apple.ScriptMenuApp
com.apple.ScriptMonitor
com.apple.SetupAssistant
com.apple.Siri
com.apple.SocialPushAgent
com.apple.SoftwareUpdate
com.apple.SpacesTouchBarAgent
com.apple.Spotlight
com.apple.stocks-widget-container
com.apple.systemevents
com.apple.systemuiserver
com.apple.TextInputMenuAgent
com.apple.TextInputSwitcher
com.apple.ThermalTrap
com.apple.UIKitSystemApp
com.apple.UniversalAccessControl
com.apple.UnmountAssistantAgent
com.apple.UserNotificationCenter
com.apple.VoiceOver
com.apple.weather
com.apple.wifi.WiFiAgent
com.apple.CloudKit.ShareBear
com.apple.loginwindow
com.apple.rcd
com.apple.screencaptureui)



#-------------------
# Functions
#-------------------

displayErrorMessage()
{
    echo "ERROR: Displaying error message to user."
    echo "ERROR: $1"
    /usr/bin/osascript -e 'tell application "System Events" to display dialog "'"$1"'\n\nFor further assistance, contact the Service Desk." buttons {"Okay"} default button 1 with icon file "System:Library:CoreServices:CoreTypes.bundle:Contents:Resources:AlertStopIcon.icns" with title "Uninstall Application" giving up after (86400)'

    exit $2
}

getApplicationBundle()
{
    # Ask the user to specifiy the .app bundle they would like to remove
    APP_BUNDLE=$(osascript -e 'tell application "System Events"' -e 'activate' -e 'POSIX path of(choose file with prompt "Select the Application you would like to remove from your Mac." of type {"APP"} default location "/Applications")' -e 'end tell')

    if [[ "$?" != "0" ]]; then
        echo "INFO: User chose to quit at app selection screen."
        exit 0
    fi

    BUNDLE_IDENTIFIER="$(/usr/bin/defaults read "$APP_BUNDLE/Contents/Info.plist" CFBundleIdentifier)"
    echo "INFO: CFBundleIdentifier=$BUNDLE_IDENTIFIER"
    BUNDLE_NAME="$(/usr/bin/defaults read "$APP_BUNDLE/Contents/Info.plist" CFBundleName)"
    echo "INFO: CFBundleName=$BUNDLE_NAME"
    BASE_NAME="$(basename "$APP_BUNDLE")"
    echo "INFO: basename=$BASE_NAME"
    DIR_NAME="$(/usr/bin/dirname $APP_BUNDLE)"
    echo "INFO: dirname=$DIR_NAME"
    EXECUTABLE_NAME="$(/usr/bin/defaults read "$APP_BUNDLE/Contents/Info.plist" CFBundleExecutable)"
    echo "INFO: CFBundleExecutable=$EXECUTABLE_NAME"

    if [[ -z "$BUNDLE_IDENTIFIER" ]]; then
        displayErrorMessage "This does not appear to be a valid application bundle." 5
    fi

    [[ -z "$BUNDLE_NAME" ]] && BUNDLE_NAME="$BASE_NAME"

    checkBundleForBlock
}

checkBundleForBlock()
{
    # Check the built in apps bundle list
    for IDENTIFIER in $BUILTIN_APP_IDENTIFIERS; do
        #echo "INFO: Checking $IDENTIFIER"
        [[ "$IDENTIFIER" == "$BUNDLE_IDENTIFIER" ]] && displayErrorMessage "The app '$BUNDLE_NAME' is a built-in app and cannot be uninstalled using this utility." 7
    done
    echo "INFO: $BUNDLE_IDENTIFIER not found in built in app identifier list"

    # Check for example require apps or apps that cant be uninstalled with
    # this utility
    for IDENTIFIER in $UNREMOVABLE_CFBUNDLEIDS; do
        #echo "INFO: Checking $IDENTIFIER"
        [[ "$IDENTIFIER" == "$BUNDLE_IDENTIFIER" ]] && displayErrorMessage "The app '$BUNDLE_NAME' is required by CompName and cannot be uninstalled using this utility." 8
    done
    echo "INFO: $BUNDLE_IDENTIFIER not found in unremovable app identifier list"
}

getAssociatedFiles()
{
    # Try to find all associated files to be uninstalled
    FILES_TO_UNINSTALL=("$APP_BUNDLE")

    #[[ "$DIR_NAME" != "/Applications" ]] && FILES_TO_UNINSTALL+=("$DIR_NAME")

    # Find root level items
    FILES_TO_UNINSTALL+=($( ls -d /Library/Preferences/$BUNDLE_IDENTIFIER*))
    FILES_TO_UNINSTALL+=($( ls -d /Library/LaunchAgents/$BUNDLE_IDENTIFIER*))
    FILES_TO_UNINSTALL+=($( ls -d /Library/LaunchDaemons/$BUNDLE_IDENTIFIER*))
    FILES_TO_UNINSTALL+=($( ls -d /Library/Containers/$BUNDLE_IDENTIFIER*))
    FILES_TO_UNINSTALL+=($( ls -d /Library/PrivilegedHelperTools/$BUNDLE_IDENTIFIER*))
    FILES_TO_UNINSTALL+=($( ls -d /Library/PrivilegedHelperTools/$BUNDLE_NAME))
    FILES_TO_UNINSTALL+=($( ls -d /Library/GroupContainers/$BUNDLE_IDENTIFIER*))

    FILES_TO_UNINSTALL+=("$( ls -d /Library/Application\ Support/$BUNDLE_NAME)")

    for IUSER in $(/usr/bin/dscl . list Users UniqueID | awk '$2 > 500 {print $1}'); do
        echo "INFO: $IUSER"
        HOME_DIRECTORY="$(/usr/bin/dscl . -read /Users/$IUSER NFSHomeDirectory | awk '{print $2}')"

        FILES_TO_UNINSTALL+=($( ls -d $HOME_DIRECTORY/Library/Preferences/$BUNDLE_IDENTIFIER*))
        FILES_TO_UNINSTALL+=($( ls -d $HOME_DIRECTORY/Library/Containers/$BUNDLE_IDENTIFIER*))
        FILES_TO_UNINSTALL+=($( ls -d $HOME_DIRECTORY/Library/GroupContainers/$BUNDLE_IDENTIFIER*))
        FILES_TO_UNINSTALL+=($( ls -d $HOME_DIRECTORY/Library/LaunchAgents/$BUNDLE_IDENTIFIER*))
        FILES_TO_UNINSTALL+=("$( ls -d $HOME_DIRECTORY/Library/Application\ Support/$BUNDLE_NAME)")



    done




}

displayVerification()
{
    for FILEX in $FILES_TO_UNINSTALL; do
        FORMATTED+='"'"$FILEX"'",'
    done
    FORMATTED+='""'


    RESULT=$(/usr/bin/osascript -e 'tell application "System Events"' -e 'choose from list {'$FORMATTED'} with prompt "You are about to uninstall '"$BUNDLE_NAME"' and the discovered components listed below.\n\nAre you sure you want to do this?" OK button name {"Uninstall"} cancel button name {"Cancel"}' -e 'end tell')

    if [[ "$RESULT" == "false" ]]; then
        echo "INFO: User chose to quit at file verification dialog."
        exit 0
    else
        uninstallApplication
    fi
}

uninstallApplication()
{
    killall -9 "$EXECUTABLE_NAME"

    for FILEX in $FILES_TO_UNINSTALL; do
        echo "INFO: Removing $FILEX..."
        /bin/rm -Rf "$FILEX"

        [[ "$?" != "0" ]] && FAILED_FILE+=("$FILEX")
    done

    if [[ ! -z $FAILED_FILE ]]; then
        echo "INFO: One or more files could not be removed."
        echo "INFO: $FAILED_FILE"
        /usr/bin/osascript -e 'tell application "System Events" to display dialog "The uninstall completed, but one or more associated files could not be removed by this tool.\n\nFor further assistance, contact the Service Desk." buttons {"Okay"} default button 1 with icon file "System:Library:CoreServices:CoreTypes.bundle:Contents:Resources:AlertCautionIcon.icns" with title "Uninstall Application" giving up after (86400)'
    else
        /usr/bin/osascript -e 'tell application "System Events" to display dialog "The application '"$APP_BUNDLE"' was successfully removed from your Mac.\n\nIt is reccomended that you restart your computer to ensure all associated processes are closed and removed." buttons {"Okay"} default button 1 with icon file "System:Library:CoreServices:CoreTypes.bundle:Contents:Resources:TrashIcon.icns" with title "Uninstall Application" giving up after (86400)'
    fi
}
#------------------------------------------------------------------------------
# Start Script
#------------------------------------------------------------------------------

getApplicationBundle
getAssociatedFiles
displayVerification

#-------------------------------------------------
# Detailed comment on a piece of code.
#-------------------------------------------------

#------------------------------------------------------------------------------
# End Script
#------------------------------------------------------------------------------
exit 0
