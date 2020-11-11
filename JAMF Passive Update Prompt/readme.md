# JAMF Passive Update prompt

# Author:
# Cole Johnson - Mapbox IT (https://www.linkedin.com/in/coleojohnson/) - 11/10/20

## Purpose of this script:
This open-sourced, licensed script scans for pending updates, prompts users with context, and then sends them to Software Update in System Preferences
It is designed for smaller macOS fleets / IT departments and is a self-service way to update macOS clients in your fleet without IT administrators having to package up and deploy updates themselves
It can be used with JAMF's built-in policy-ability to send highly customizable prompts to users before forcing updates
Note: If you use the script in this method, be sure to set the script priority to "Before" so that the script prompts users before updates are forced

## Use cases: This script can be used to only prompt users about pending updates, to prompt users and then send them to Software Updates panel in System Preferences, or to prompt users that updates are ABOUT to be installed (When used in a policy that forces updates). This script is not intended to apply updates itself.

## Why we (Mapbox IT) created this script:
We wanted a "native" approach to patching end users and wanted to spend a minimal amount of time maintaining software packages.
For a smaller distributed workforce, re-packaging the same software updates that users were already downloading from Apple felt highly redundant.
We realized that instead of deploying redundant update packages ourselves, a highly customized patch prompt with a button that sends users directly to a native Apple update experience would be just as effective. JAMF's off-the-shelf feature set does not allow for much prompt customization
This also allowed us to have users update through the native Apple UI (as only using Apple's "softwareupdate" cli gave us mixed results).
This also has the following added benefits:
Users perform updates themselves in a self-service approach
Users receive a highly customized prompt, giving them important context about each patch campaign or monthly patching effort
Users perform updates on their own time
Administrators can send different prompt wordings for slightly different scenarios. This additional explanation minimizes confusing scenarios
Administrators can continuously update the prompt look/feel as the patch campaign goes on

## Other features:
Allows JAMF administrators to decide whether or not to check for updates if the client has already met the desired OS version


## Who this script is not for:
If you want any software updates making their ways to users to have been re-packaged by IT first, this solution is not for you
Likely not for large enterprises with internal update repositories or air-gapped environments

## Tested on:
macOS 10.13 (High Sierra) - macOS 10.15 (Catalina)

## Requirements:
This script is designed to be run from JAMF. However, the only JAMF dependency is the JAMF Helper ("/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"), i.e. the program used for the prompt itself. This script could easily be re-purposed to work with other prompt types that are not JAMF-dependent.

## Nice to have:
Public icon url (for customized patching prompts)


## How to use:
1. Set your company name in the variable directly below this section and save the script
2. (Optional) Upload a publicly-accessible icon to be used in the patching prompt
3. Upload the script to JAMF (Follow the steps in the next section for specifics)
4. Customize the parameter inputs to fit your needs
5. Put the script into a JAMF policy scoped to a JAMF computer group
6. Ensure the computer group criteria checks against the same macOS version defined in your script parameter inputs
7. Deploy
8. Check logs in "/tmp/YOUR_COMPANY_NAME_HERE/JamfPatchingDependencies"
