#!/bin/sh

#Copyright (c) 2020 Mapbox,  All rights reserved.

#Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

#    1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
#    2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
#    3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

#THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
#THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS
#BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
#GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
#LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

## Title: JAMF Passive Update prompt

# Author:
# Cole Johnson - Mapbox IT (https://www.linkedin.com/in/coleojohnson/) - 10/04/20

## Purpose of this script: 
## This script scans for pending updates, prompts users with context, and then sends them to Software Update in System Preferences
## It is designed for smaller macOS fleets / IT departments and is a self-service way to update macOS clients in your fleet without IT administrators having to package up and deploy updates themselves
## It can be used with JAMF's built-in policy-ability to send highly customizable prompts to users before forcing updates
## Note: If you use the script in this method, be sure to set the script priority to "Before" so that the script prompts users before updates are forced

# Use cases: This script can be used to only prompt users about pending updates, to prompt users and then send them to Software Updates panel in System Preferences, or to prompt users that updates are ABOUT to be installed (When used in a policy that forces updates). This script is not intended to apply updates itself.

# Why we created this script:
## We wanted a "native" approach to patching end users and wanted to spend a minimal amount of time maintaining software packages.
## For a smaller distributed workforce, re-packaging the same software updates that users were already downloading from Apple felt highly redundant.
## We realized that instead of deploying redundant update packages ourselves, a highly customized patch prompt with a button that sends users directly to a native Apple update experience would be just as effective. JAMF's off-the-shelf feature set does not allow for much prompt customization
## This also allowed us to have users update through the native Apple UI (as only using Apple's "softwareupdate" cli gave us mixed results).
## This also has the following added benefits:
## Users perform updates themselves in a self-service approach
## Users receive a highly customized prompt, giving them important context about each patch campaign or monthly patching effort
## Users perform updates on their own time
## Administrators can send different prompt wordings for slightly different scenarios. This additional explanation minimizes confusing scenarios
## Administrators can continuously update the prompt look/feel as the patch campaign goes on

## Other features:
## Allows JAMF admininistrators to decide whether or not to check for updates if the client has already met the desired OS version


## Who this script is not for:
## If you want any software updates making their ways to users to have been re-packaged by IT first, this solution is not for you
## Likely not for large enterprises and/or air-gapped environments

## Tested on: 
## macOS 10.13 (High Sierra) - macOS 10.15 (Catalina)

## Requirements: 
## This script is designed to be run from JAMF. However, the only JAMF dependency is the JAMF Helper ("/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"), i.e. the program used for the prompt itself. This script could easily be re-purposed to work with other prompt types that are not JAMF-dependent.

## Nice to have:
## - Public icon url (for customized patching prompts)


## How to use:
## 1. Set your company name in the variable directly below this section and save the script
## 2. (Optional) Upload a publicly-accessible icon to be used in the patching prompt
## 3. Upload the script to JAMF (Follow the steps in the next section for specifics)
## 4. Customize the parameter inputs to fit your needs
## 5. Put the script into a JAMF policy scoped to a JAMF computer group 
## 6. Ensure the computer group criteria checks against the same macOS version defined in your script parameter inputs
## 7. Deploy
## 8. Check logs in "/tmp/YOUR_COMPANY_NAME_HEREJamfPatchingDependencies"

companyName='YOUR_COMPANY_NAME_HERE' ## Leave the single quotations. Do not include spaces or special characters


## Steps to upload into JAMF via the JAMF console
## 1. Upload this script to JAMF scripts by going to JAMF console -> Settings -> Computer Management -> Scripts -> New
## 2. Copy the entire script here 
## 3. Paste the script contents into the JAMF script editor
## 4. Click the "Options" tab 
## 5. Set the parameters as follows (Starting at parameter "4"):
## Parameter 4: 
## "Desired OS Version (i.e. 10.15.5, if you want to make sure all computers are updated to 10.15.5 ) - REQUIRED"
## Parameter 5:
## "Open Software Update in System Preferences if machine is out of compliance and has pending updates? Ex: "true" OR "false" without quotes. Script validates this parameter. - REQUIRED" 
## Parameter 6: 
## "Do you want the script to still check for updates for machines whose OS version is already up to date with the "Desired OS Version"? (i.e. Do you want to check for supplemental updates?) (Ex: "true" OR "false") without quotes. - REQUIRED"
## Parameter 7: 
## "Prompt heading text -  (The banner text at the top banner of the pop-up. This is not the title above the body text) Ex: "(YOUR COMPANY NAME) IT Software Update Required" - without quotes - REQUIRED"
## Parameter 8:
## "Prompt body title - (The title of the pop-up body. This goes above the message text. This is not the banner title) Ex: "Software Updates" - without quotes - REQUIRED"
## Parameter 9: 
## "Prompt message body text - (The message in the pop-up you want users to see) Ex: "Your computer is missing critical updates. You have 1 hour to close all applications." - without quotes - REQUIRED"
## Parameter 10:
## "Prompt icon url - (Public link to the company patching icon. This icon will be displayed in the prompt.) - Not required"
## Parameter 11:
## "Prompt timeout seconds - (Timer until prompt closes and JAMF policy proceeds next actions, if any) - Default prompt timer: 3 hours (10800 seconds)." - Not required"

## How it works (high overview):
## Takes the "desired OS version" from your parameter input
## Retrieves the OS version of the client - parsing out the results to retrieve the major, minor, and build revision numbers
## Runs softwareupdate to see if any updates are pending
## If the local OS Version does not meet or exceed the desired OS Version from your input parameters and there are pending updates, prompt the user
## If the local OS Version meets or exceeds the desired OS Version from your input parameters, but have specified to still check for updates, and pending updates are found, prompt the user
## If specified in your parameter inputs, take the user directly to Software Update in System Preferences once the user dimisses or force-closes the patch prompt
## Exit the script

echo "Starting script.. Date: $(date +"%Y-%b-%d %T")"

#################### Validate required inputs #####

echo "####################"
echo "Validating required parameters.."
if [ ! -n "$4" ]; then
    echo "Error! 1st JAMF input variable null.  Please define the desired OS version. Exiting script.."
    exit 1
fi

if [ ! -n "$5" ]; then
    echo "Error! 2nd JAMF input variable null. Please enter 'true' or 'false' for to specify the 'openSoftwareUpdatesInSystemPreferences' variable. If true, both a message prompt AND take the user to the built in macOS softwareupdates page in System Preferences to check for updates. Warning will ONLY prompt the user. Forced patching itself should be handled via the JAMF policy UI. Warning mode will not automatically install patches. Exiting script.."    exit 1
    exit 1
fi

if [ ! -n "$6" ]; then
    echo "Error! 3rd JAMF input variable null. Please define whether or not to check for updates if OS version already up to date (input 'true' or 'false'). Exiting script.."
    exit 1
fi

if [ ! -n "$7" ]; then
    echo "Error! 4th JAMF input variable null. Please define prompt banner heading. Exiting script.."
    exit 1
fi

if [ ! -n "$8" ]; then
    echo "Error! 5th JAMF input variable null. Please define prompt message title. Exiting script.."
    exit 1
fi

if [ ! -n "$9" ]; then
    echo "Error! 6th JAMF input variable null. Please define prompt message body. Exiting script.."
    exit 1
fi

echo "Required parameters validated. Proceeding.."


#################### End validate required inputs



#################### Icon parameter and additional logic #####
## check to see if prompt icon url parameter has been set. If not, use default value
if [ ! -n "${10}" ]; then
    echo "7th JAMF input variable (JAMF prompt icon url) not set. Defaulting prompt icon url to default url." 
    #default url to specify in case JAMF admin does not specify a url. Update this if the default icon location ever changes
    promptIconUrl='https://your_public_url.com/your_patch_prompt_icon.png'
    echo "Prompt icon url not specified in parameters. Setting to default url: ${promptIconUrl}";
else
    promptIconUrl=${10} # 11 character limit. What the button itself on the prompt says. (ex: 'ok' or 'proceed' etc. etc.)
    echo "Prompt icon url specified by JAMF input parameter: ${promptIconUrl}"
fi

#If jamf patch dependency directory already exists, delete it and start over
## Use the /tmp directory as it clears on reboot and therefore doesn't leave junk lying around on endpoints
iconDirectory="/tmp/${companyName}JamfPatchingDependencies"
if [ -d "$iconDirectory" ]; then
echo "Temp JAMF Patching Dependencies folder already exists.. Deleting the folder and its contents and creating a fresh new directory.."
rm -rf "$iconDirectory" || {
echo "Error removing old temporary directory"
exit 1
}
fi

#Create temp directory
mkdir "$iconDirectory"
echo "$iconDirectory has been created.. "

# Grab icon from a publicly-accessible url
echo "Downloading latest patching prompt icon.."
curl -L "$promptIconUrl" -o "${iconDirectory}/jamf${companyName}IconFile.png"
iconFile="${iconDirectory}/jamf${companyName}IconFile.png"


#################### End Icon parameter and additional logic #####


## check to see if custom prompt timeout has been set. If not, use default value
if [ ! -n "${11}" ]; then
    promptTimeoutSeconds='10800'
    echo "8th JAMF input variable (JAMF prompt timeout) not set. Defaulting prompt timeout to 3 hours (10800 seconds)." 
    echo "JAMF prompt timeout (in seconds): ${promptTimeoutSeconds}"
else
    promptTimeoutSeconds=${11}
    echo "JAMF prompt timeout set to: ${promptTimeoutSeconds}";
fi

# Convert JAMF variables to named variables from positional parameter variables
desiredOSVersionFullString=$4  # (i.e. 10.15.5, if you want to make sure all computers are updated to 10.15.5 )
openSoftwareUpdatesInSystemPreferences=$5 # Decides whether or not the script will automatically open the Software Update pane in System Preferences, IF updates are found 
additionalCheckForUpdates=$6 # (Do you want the script to still check for updates for machines whose OS is already up to date? (Matters only if machine already on the lowest acceptable version above))
promptHeading=$7 # The banner text at the top banner of the pop-up (This is not the title above the body text)
promptMessageTitle=$8 # The title of the pop-up body. This goes above the message text (This is not the banner title)
promptMessageBodyText=$9  # The message in the pop-up you want users to see


## parse jamf variables for processing
desiredOSMajorVersion=$(echo "$desiredOSVersionFullString" | awk -F '.' '{print $1}')  # (i.e. OS 10)
desiredOSMinorVersion=$(echo "$desiredOSVersionFullString" | awk -F '.' '{print $2}') # highest OS minor release supported, 10.15 (Catalina)
desiredOSRevisionBuildNumber=$(echo "$desiredOSVersionFullString" | awk -F '.' '{print $3}') # (Patch version)

# valide true false input
# Allow jamf technician some leeway when checking the "additionalCheckForUpdates" variable from the JAMF script paramter that was input in the console. Check for multiple "true" "false" values
if [[ $openSoftwareUpdatesInSystemPreferences = "true" || $openSoftwareUpdatesInSystemPreferences = "TRUE" || $openSoftwareUpdatesInSystemPreferences = "T" || $openSoftwareUpdatesInSystemPreferences = "t"  ]]; then
    openSoftwareUpdatesInSystemPreferences='true'
elif [[ $openSoftwareUpdatesInSystemPreferences = "false" || $openSoftwareUpdatesInSystemPreferences = "FALSE" || $openSoftwareUpdatesInSystemPreferences = "F" || $openSoftwareUpdatesInSystemPreferences = "f"  ]]; then
    openSoftwareUpdatesInSystemPreferences='false'
else 
    echo "Error! 'openSoftwareUpdatesInSystemPreferences' variable set to invalid value. 'openSoftwareUpdatesInSystemPreferences' variable value: ${openSoftwareUpdatesInSystemPreferences}. Please set variable to: 'true' or 'false'. Exiting script.." && exit 1;
fi

# valide true false input
# Allow jamf technician some leeway when checking the "additionalCheckForUpdates" variable from the JAMF script paramter that was input in the console. Check for multiple "true" "false" values
if [[ $additionalCheckForUpdates = "true" || $additionalCheckForUpdates = "TRUE" || $additionalCheckForUpdates = "T" || $additionalCheckForUpdates = "t"  ]]; then
    additionalCheckForUpdates='true'
elif [[ $additionalCheckForUpdates = "false" || $additionalCheckForUpdates = "FALSE" || $additionalCheckForUpdates = "F" || $additionalCheckForUpdates = "f"  ]]; then
    additionalCheckForUpdates='false'
else 
    echo "Error! 'additionalCheckForUpdates' variable set to invalid value. 'additionalCheckForUpdates' variable value: ${additionalCheckForUpdates}. Please set variable to: 'true' or 'false'. Exiting script.." && exit 1;
fi


#################### Static script variables #####
promptButtonText='Ok' # 11 character limit. What the button itself on the prompt says. (ex: 'ok' or 'proceed' etc. etc.)
#################### End static script variables #####


# print variables to console for debugging / sanity check
echo "####################"
echo "JAMF-Defined OS variables:"
echo "'Additional check for updates' variable set to: $additionalCheckForUpdates"
echo "'Open Software Update pane in System Preferences' variable set to: $openSoftwareUpdatesInSystemPreferences"
echo "JAMF admin has defined the desired OS version as: $desiredOSVersionFullString"
echo "Lowest acceptable OS Major version is: $desiredOSMajorVersion"
echo "Lowest acceptable OS Minor version is: $desiredOSMinorVersion"
echo "Lowest acceptable OS Build Revision version is: $desiredOSRevisionBuildNumber"
echo "####################"
echo "JAMF-Defined OS prompt variables:"
echo "JAMF prompt heading : $promptHeading"
echo "JAMF prompt message title : $promptMessageTitle"
echo "JAMF prompt message body text : $promptMessageBodyText"
echo "JAMF prompt button text : $promptButtonText"
echo "####################"

#################### End variable declaration and validation logic #####


#################### Prompting Workflow logic #####

## Determine Local OS version
osVersionFullString=`sw_vers -productVersion`
## Parse out major, minor, and build revision versions from os version full string
osMajor=$(echo "$osVersionFullString" | awk -F '.' '{print $1}')
osMinor=$(echo "$osVersionFullString" | awk -F '.' '{print $2}')
osBuildRevision=$(echo "$osVersionFullString" | awk -F '.' '{print $3}')


## Get the currently logged in user, if any.
LoggedInUser=`who | grep console | awk '{print $1}'`

# print variables to console for debugging / sanity check
echo "Local OS version is: $osVersionFullString"
echo "Local OS Major version is: $osMajor"
echo "Local OS Minor version is: $osMinor"
echo "Local OS Build Revision version is: $osBuildRevision"
echo "Logged in user is: $LoggedInUser"


## Test variables
## OS Test Variables
## For testing input variables and / or variable validation
# osVersionFullString='10.15.4'
# osMajor='10'
# osMinor='15'
# osBuildRevision='4'

## Prompt Test Variables 
## Define prompt text
# title='(YOUR COMPANY NAME) IT Software Update Required'
# heading='Software Update'
# description="Your OS version is up to date but you are still missing critical security updates. You have until this timer expires to save your work and close your applications. These updates may take up to 45 minutes install. CLICKING 'Ok' WILL INSTALL THESE UPDATES AND MAY REBOOT YOUR COMPUTER."
# button1="Ok"
## End test Variables #

function checkForUpdatesAndPrompt {
    echo "JAMF admin has defined the desired OS version as: $desiredOSVersionFullString"
    echo "Local OS version is: $osVersionFullString"

    ## Check for updates. Parse out ones that require a restart and ones that do not.
    updates=`softwareupdate -l`
    echo "Updates that were found were: $updates"
    updatesNoRestart=`echo $updates | grep recommended | grep -v restart`
    [[ -z $updatesNoRestart ]] && updatesNoRestart="none"
    restartRequired=`echo $updates | grep restart | grep -v '\*' | cut -d , -f 1`
    [[ -z $restartRequired ]] && restartRequired="none"
    shutDownRequired=`echo $updates | grep shutdown | grep -v '\*' | cut -d , -f 1`
    [[ -z $shutDownRequired ]] && shutDownRequired="none"

    ## Test Variables #
    ## Reboot State Test Variables 
    # shutDownRequired='true'
    # updatesNoRestart='true'
    # restartRequired='true'
    ## End test Variables #


    ## If there are no system updates, quit
    if [[ $updatesNoRestart = "none" && $restartRequired = "none" && $shutDownRequired = "none" ]]; then
        echo "No updates found at this time. Exiting script with success code."
        exit 0
    else

    # There are pending updates. So prompt the user..
    prompt=`"/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper" -windowType hud -title "$promptHeading" -heading "$promptMessageTitle" -alignHeading justified -description "$promptMessageBodyText" -alignDescription left -button1 "$promptButtonText" -timeout $promptTimeoutSeconds -countdown -lockHUD -icon $iconFile`
    echo "User prompt button equaled: $prompt. ( Guide for what each user action equals: 0=start (user clicked 'ok'), 1=failed to prompt, 2=canceled, 239=exited. )"
        ## leaving this bit in the script. If you want to define actions ONLY if a user clicks the 'ok' prompt button, use the following lines:
        # if [[$prompt -eq '0']] .. etc etc..
        if [[ $openSoftwareUpdatesInSystemPreferences = "true" ]]; then
        echo "JAMF admin opted to open Software Update panel in System Preferences. Opening Software Update panel.."
        # Open Software Update pane in system preferences
        open "x-apple.systempreferences:com.apple.preferences.softwareupdate?client=softwareupdateapp"
        else 
            echo "Updates were found but JAMF admin opted NOT to open Software Update panel in System Preferences."
        exit 0;
        fi
        ## script will now take user to JAMF policy built-in Software Update component. IF FORCING UPDATES WITH THIS SCRIPT, MAKE SURE SCRIPT PRIORITY IS SET TO 'BEFORE'!
    fi
}


# If OS is already up to date but additional check for updates has been marked "yes" in JAMF parameters, still look for updates. Alter notification message if updates found
## Note the following conditions do not specifically check to see if the OS version EXCEEDS desiredOSVersionFullString requirements
# This is because this script should never be deployed to update machines with OS versions that both fall short of and exceed os version requirements
# In other words, you should not be deploying patching efforts to bring computers up to date to an OS version like 10.0.0 and still be updating machines with OS Version 10.0.1
# If this is your scenario, your desiredOSVersionFullString should simply be 10.0.1, not 10.0.0 
if [ "${osVersionFullString}" == "${desiredOSVersionFullString}" ] && [ "${additionalCheckForUpdates}" == 'true' ];then 
    echo "OS version meets minimum version requirements but JAMF admin has specified to STILL CHECK for further updates. Checking for further updates.."
    checkForUpdatesAndPrompt
    exit 0

# If the major, minor, or build revision version of the current OS is LESS than what the minimum accepted OS version is, the OS is out of date, proceed to check for updates.
elif [ "${osMajor}" -lt "${desiredOSMajorVersion}" ] || [ "${osMinor}" -lt "${desiredOSMinorVersion}" ] || [ "${osBuildRevision}" -lt "${desiredOSRevisionBuildNumber}" ]; then
    echo "Computer OS version does NOT meet minimal requirements. Checking for further updates.."
    checkForUpdatesAndPrompt
    exit 0

else
    echo "Computer OS version meets minimum version requirements and JAMF admin has specified NOT to still check for updates. Nothing to do here. Exiting script with success code.."
    echo "Additional check for updates: $additionalCheckForUpdates"
    echo "JAMF admin has defined lowest acceptable OS as: $desiredOSVersionFullString"
    echo "Local OS version is: $osVersionFullString"
    exit 0;
fi

#################### End Prompting Workflow logic #####
