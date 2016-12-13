#!/bin/bash
# ---------------Begin Init--------------------
# 
# defining "print" type function called "pause":
# ---------------------------------------------
function pause(){
	read -p -r "$*" # may need a semicolon after if not working.
}
# Logging function - Logs to file /root/rhellicensefix.txt
function log(){
	tee -a /root/rhellicensefix.txt; printf "\n";
} 
# Function that disables Red Hat Network Classic/Satellite plugin.
function disableplugin(){
	echo "Disabling classic style RHN plugin..." | log; 
	sed -i 's/enabled = 1/enabled = 0/g' /etc/yum/pluginconf.d/rhnplugin.conf; 
	PLGST=$(< /etc/yum/pluginconf.d/rhnplugin.conf | grep enabled); 
	echo "Status of plugin is $PLGST , should read as enabled = 0" | log;
}
# ------------------------Begin----------------------------
# 
echo #
echo -e "\e[1;101m <<<License fix for RHEL version 5/6>>> \e[0m"
# Making logfile.
touch /root/rhellicensefix.txt
# Back up original "classic" license file
echo "Backing up RHN Classic entitlements to /root/systemid.bak..." | log
cp /etc/sysconfig/rhn/systemid /root/systemid.bak
# Checking to ensure we're not already licensed (can probably just grep for this.)
echo "Checking current subscription-manager status..." | log
subscription-manager identity | grep -v org | log
read -p "$PS2 Do you see UUID registration? (if Classic, type N)? [Yes/No/OtherKeysQuit]." -n 1 -r
echo #
# If we do see a valid registration, then we can re-register the UUID and ensure the RHN plugin is disabled.
if [[ $REPLY =~ ^[Yy]$ ]]
then
	echo "Looks registered - Grab the UUID for this server (This should appear as $HOSTNAME ) in your Red Hat Network portal." | log
	echo "If there exist duplicates, delete the non-matching UUID." | log
	pause "$PS2 Press [ENTER] when ready to proceed...."
# Assign the UUID to a variable "UUID"
	read -p -r "$PS2 Enter the UUID to (re)register: " UUID
# This following line is *only logged*, not actually displayed while running the script.
	echo -e "\e[1;101m Received UUID $UUID \e[0m" >> /root/rhellicensefix.txt
# Now, cleaning, then registering the UUID.
	echo "Removing old/corrupted license data..." | log
	subscription-manager clean | log
# Disabling the RHN plugin so the client doesn't get a confusing error message. 
# I turned this into a function but keeping it here just in case.
# ------------This is now "disableplugin" function-----------------
#	echo "Disabling classic style RHN plugin..." | log
#	sed -i 's/enabled = 1/enabled = 0/g' /etc/yum/pluginconf.d/rhnplugin.conf
#	PLGST=$(< /etc/yum/pluginconf.d/rhnplugin.conf | grep enabled)
#	echo "Status of plugin is $PLGST , should be enabled = 0" | log
# -------------End of pre-function code-----------------------------
	disableplugin
	echo -e "Registering using UUID:\e[1;4;32m$UUID...\e[0m"
	subscription-manager register --consumerid="$UUID" | log
# Cleaning Repo cache, updating subscriptions...
	echo "Cleaning repo data..." | log
	yum clean all >> /etc/yum/pluginconf.d/rhnplugin.conf
	echo "Updating subscriptions..." | log
	subscription-manager subscribe --auto
# One last verification that we are actually subscribed.
	echo "Confirming we're registered properly now..."
	subscription-manager identity | grep -v org  | log
elif [[ $REPLY =~ ^[Nn]$ ]] # You pressed "n" for no.
then
	echo "Looks like it's unregistered, or registered as Classic scheme. Fixing." | log
# Removing classic license file (backed up earlier on)	
	rm -f /etc/sysconfig/rhn/systemid
# Disabling plugin
	disableplugin
# Get them RHEL license creds ready, then enter them to register with new entitlements.
	echo "You'll need the RHN credentials to proceed further" | log
	pause "$PS2 Press [ENTER] when you have them available." | log
	subscription-manager register | log
	echo "Now we should be registered. Confirming..." | log
# confirming that it's good.
	subscription-manager identity | log
	echo "Updating subscriptions..." | log
	subscription-manager subscribe --auto
# My idea of "error handling".
	echo "If you're not registered now, then something has gone very, very wrong - contact support."
# Clear repo cache, transation test.
	echo "Final testing/cleanup..."
	yum clean all | log
	echo "Determining whether we can hit the Red Hat repositories successfully..."
	yum check-update | log
	echo "Finished."
	echo "Check the file /root/rhellicensefix.txt for additional data."
else
	echo "Quitting - Reverting files created during init..."
	rm -f /root/systemid.bak
	rm -f /root/rhellicensefix.txt
	echo "Nothing done - exiting."
	fi
