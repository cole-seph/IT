#!/bin/bash

#Copyright (c) 2018 Pandora Media, Inc.,  All rights reserved.

#Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

#    1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
#    2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
#    3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

#THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
#THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS
#BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
#GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
#LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#Universal .dmg / .pkg installer
#Bash script to retrieve .pkg or .dmg from a url, install it appropriately based on filetype retrieved from url, and delete cached contents
#Pandora Media Inc. - Cole Johnson (https://www.linkedin.com/in/coleojohnson/), Jess McLaughlin 10-12-18
#Intended for macOS administration with administrative programs like JAMF or Apple DEP


# $4 - URL from which to download (If no download repository is available for the app, this link can often be pulled from a "Download Now" button on a trusted-company-website.
# $5 - Friendly name to use for the installer. Ex: VLC - (Would not advise using spaces with this)

#Notes
#The installer and installer contents are cached in a temporarily created directory using the $package_friendly_name variable
#Ex: /tmp/VLC/(cached contents)
#This script was designed to utilize args[4] and args[5] parameters in JAMF

#Begin Script Workflow..

#Set default args variables as friendly-names
installer_url=$4
package_friendly_name=$5

echo "Retrieving dependency from: $installer_url.."
echo "Using temporary app name: $package_friendly_name"

echo "Downloading installer and installing $package_friendly_name.."

# Create temporary directory path variable
tempdir="/tmp/$package_friendly_name"
echo "temp directory: $tempdir"
#Create temp directory
mkdir "$tempdir"
echo "$tempdir has been created.. "

#Download the installer to the temporary directory using the installer url variable
cd "$tempdir" || return
echo "changed directories to $tempdir .. "

echo "downloading installer from $installer_url"

curl -L "$installer_url" -o installer

#Find name of what was downloaded and cast name to variable
installer="$(ls "$tempdir")"
echo "installer = $installer"
installer_type="$(file -I "$tempdir/$installer")"
echo "Installer type = $installer_type"

#application/x-xar = .pkg
#application/zlib = .dmg
#application/x-bzip2 = .dmg

echo "Checking installer for supported types.."
if [[ $installer_type == *"application/x-xar"* ]]; then

  #PKG INSTALLER
  echo "Installer is a .pkg. Installing .pkg to disk.."

  #rename installer to installer.pkg so the file may be processed properly
  mv "$tempdir/installer" "$tempdir/installer.pkg"

  #install pkg to disk
  installer -allowUntrusted -verboseR -pkg "$tempdir/installer.pkg" -target /

elif [[ $installer_type == *"application/x-bzip2;"* ]] || [[ $installer_type == *"application/zlib"* ]] || [[ $installer_type == *"application/octet-stream"* ]] ; then


    echo "Installer is a .dmg. Installing .dmg to disk.."

    #Mount dmg
    #Note, it is not necessary when mounting a .dmg to first ensure the file has a .dmg extension
    mountpoint="/Volumes/$package_friendly_name"
    hdiutil attach "$tempdir/installer" -mountpoint "$mountpoint"

    app_to_copy="$(find "$mountpoint" -name '*.app' -maxdepth 1)"

    echo "App to copy to Applications: $app_to_copy"

    echo "path to copy from: $app_to_copy"

    #Copy app to Applications folder
    cp -r "$app_to_copy" "/Applications"
    #Unmount dmg
    hdiutil detach "$mountpoint"

  else
    echo "Error: Unknown installer type. Exiting script.."

fi

#Cleanup temp contents
rm -r "$tempdir"
