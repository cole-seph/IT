# JAMF Passive Update prompt

# Summary:
This is a simple plug-n-play script to prompt your JAMF users and send them to System Preferences to update if they either have pending updates or are not up to date with a certain version of macOS. It is highly customizable and makes use of JAMF's built-in jamfhelper prompt.

### Author:
### Cole Johnson - Mapbox IT (https://www.linkedin.com/in/coleojohnson/) - 11/10/20

### The prompt:
![image](https://github.com/cole-seph/IT/blob/master/JAMF%20Passive%20Update%20Prompt/IMAGE%202020-11-11%2014:30:36.jpg?raw=true)
### Clicking 'Ok' (optionally) takes you to Software Update in System Preferences
![image](https://github.com/cole-seph/IT/blob/master/JAMF%20Passive%20Update%20Prompt/IMAGE%202020-11-11%2014:30:31.jpg?raw=true)
## The completed policy then leaves you with a straightforward log in JAMF
![image](https://github.com/cole-seph/IT/blob/master/JAMF%20Passive%20Update%20Prompt/IMAGE%202020-11-11%2014:30:40.jpg?raw=true)

## How to use:
1. Set your company name in the "your_company_name" variable and save the script
2. (Optional) Upload a publicly-accessible icon to be used in the patching prompt
3. Upload the script to JAMF in the JAMF Settings -> Scripts section
4. Customize the parameter inputs to fit your needs
5. Put the script into a JAMF policy and scope it according to your needs
6. Ensure the computer group criteria checks against the same macOS version defined in your script parameter inputs
7. Deploy
8. Check logs in "/tmp/YOUR_COMPANY_NAME_HERE/JamfPatchingDependencies"


## Purpose of this script:
This script is designed as a self-service way to update macOS clients in your fleet without requiring IT administrators to have to re-package and deploy updates.
It can be used with JAMF's built-in policy-ability to send highly customizable prompts to users before forcing updates.
Note: If you use the script in this method, be sure to set the script priority in JAMF script settings to "Before" so that the script prompts users before updates are forced.

## Use cases: 
This script can be used to only prompt users about pending updates, to prompt users and then send them to Software Updates panel in System Preferences, or to prompt users that updates are _about_ to be installed (when used in a policy that forces updates). This script is not intended to apply updates itself.

## Why we (Mapbox IT) created this script:
We wanted a "native" approach to patching end users and wanted to spend a minimal amount of time maintaining software packages.
For a smaller distributed workforce, re-packaging the same software updates that users were already downloading from Apple felt highly redundant.
We realized that instead of deploying redundant update packages ourselves, a highly customized patch prompt with a button that sends users directly to a native Apple update experience would be just as effective. JAMF's off-the-shelf feature set does not allow for much prompt customization.
This also allowed us to have users update through the native Apple UI (as only using Apple's "softwareupdate" cli gave us mixed results).
This also has the following added benefits:
 - Users perform updates themselves in a self-service approach
 - Users receive a highly customized prompt, giving them important context about each patch campaign or monthly patching effort
 - Users perform updates on their own time
 - Administrators can send different prompt wordings for slightly different scenarios. This additional explanation minimizes confusing scenarios
 - Administrators can continuously update the prompt look/feel as the patch campaign goes on

## Other features:
Allows JAMF administrators to decide whether or not to check for updates if the client has already met the desired OS version


## Who this script is not for:
If you want any software updates making their ways to users to have been re-packaged or further customized by IT first, this solution is not for you.
This is also likely not for large enterprises with internal update repositories or air-gapped environments.

## Tested on:
macOS 10.13 (High Sierra) - macOS 10.15 (Catalina)

## Requirements:
This script is designed to be run from JAMF. However, the only JAMF dependency is the JAMF Helper ("/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"), i.e. the program used for the prompt itself. This script could easily be re-purposed to work with other prompt types that are not JAMF-dependent.

## Parameters:
**Parameter 4:**

"Desired OS Version (i.e. 10.15.5, if you want to make sure all computers are updated to 10.15.5 ) - REQUIRED"

**Parameter 5:**

"Open Software Update in System Preferences if machine is out of compliance and has pending updates? Ex: "true" OR "false" without quotes. Script validates this parameter. - REQUIRED" 

**Parameter 6:**

"Do you want the script to still check for updates for machines whose OS version is already up to date with the "Desired OS Version"? (i.e. Do you want to check for supplemental updates?) (Ex: "true" OR "false") without quotes. - REQUIRED"

**Parameter 7:**

"Prompt heading text -  (The banner text at the top banner of the pop-up. This is not the title above the body text) Ex: "(YOUR COMPANY NAME) IT Software Update Required" - without quotes - REQUIRED"

**Parameter 8:**

"Prompt body title - (The title of the pop-up body. This goes above the message text. This is not the banner title) Ex: "Software Updates" - without quotes - REQUIRED"

**Parameter 9:**

"Prompt message body text - (The message in the pop-up you want users to see) Ex: "Your computer is missing critical updates. You have 1 hour to close all applications." - without quotes - REQUIRED"

**Parameter 10:**

"Prompt icon url - (Public link to the company patching icon. This icon will be displayed in the prompt.) - Not required"

**Parameter 11:**

"Prompt timeout seconds - (Timer until prompt closes and JAMF policy proceeds next actions, if any) - Default prompt timer: 3 hours (10800 seconds)." - Not required"


## Optional:
Public icon url (for customized patching prompts)

### Note:
An extended version of this readme can be found within the script itself.


