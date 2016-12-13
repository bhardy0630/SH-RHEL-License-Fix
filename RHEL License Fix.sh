#!/bin/bash
# --------------Description--------------------
# 
# RHEL licensing "systemID" to subscription-manager" fixer - written for SingleHop, LLC by bhardy.
# Should be a "wget and run" type script for fixing RHEL licensing - since we're using the new licensing system 
# then we might as well make it as automated as possible.
# 
# ---------------Begin Init--------------------
# 
# defining "print" type function called "pause":
# ---------------------------------------------
function pause(){
	read -p -r "$*" # may need a semicolon after if not working.
}
# Logging function! Logs to file /root/rhellicensefix.txt
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
# ---------------Begin Main AKA (spaghetti.sh)--------------------
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
	echo "Looks registered - Grab the UUID for this server($HOSTNAME) in the RHN portal. If there's duplicates, delete the non-matching UUID." | log
	pause "$PS2 Press [ENTER] when ready to proceed...."
# Assign the UUID to a variable "UUID"
	read -p -r "$PS2 Enter the UUID to (re)register: " UUID
	printf "User entered UUID $UUID \n" > /root/rhellicensefix.txt
# Now, cleaning, then registering the UUID.
	echo "Removing old/corrupted license data..." | log
	subscription-manager clean | log
# Disabling the RHN plugin so the client doesn't get a confusing error message. 
# I turned this into a function but keeping it here just in case.
# --------------------------Oh God I Called It Twice So It Needs To Be A Function-----------------
#	echo "Disabling classic style RHN plugin..." | log
#	sed -i 's/enabled = 1/enabled = 0/g' /etc/yum/pluginconf.d/rhnplugin.conf
#	PLGST=$(< /etc/yum/pluginconf.d/rhnplugin.conf | grep enabled)
#	echo "Status of plugin is $PLGST , should be enabled = 0" | log
# --------------------------Next Line Is Function-------------------------------------------------
	disableplugin
	echo -e "Registering using UUID:\e[1;4;32m$UUID...\e[0m"
	subscription-manager register --consumerid="$UUID" | log
# Cleaning Repo cache	
	echo "Cleaning repo data..." | log
	yum clean all >> /etc/yum/pluginconf.d/rhnplugin.conf
# Usually not needed, but just in case.
	echo "Updating subscriptions..." | log
	subscription-manager subscribe --auto
# One last verification that we are indeed subscribed.
	echo "Confirming we're registered properly now..."
	subscription-manager identity | grep -v org  | log
elif [[ $REPLY =~ ^[Nn]$ ]] # You pressed "n" for no.
then
	echo "Looks like it's unregistered, or registered as Classic scheme. Fixing." | log
# Removing classic license file (backed up earlier on)	
	rm -f /etc/sysconfig/rhn/systemid
# Disabling plugin
	disableplugin
# Get them SS creds ready...
	echo "You'll need the RHN credentials to proceed further" | log
	pause "$PS2 Press [ENTER] when you have them available." | log
# Now enter them, cause we're not hard-coding them into this script.
	subscription-manager register | log
# Normal setup is easy - enter the credentials and it registers you.
	echo "Now we should be registered. Confirming..." | log
# And then confirming that it's good.
	subscription-manager identity | log
	echo "Updating subscriptions..." | log
	subscription-manager subscribe --auto
# Seriously. Something has gone terribly wrong.
	echo "If you're not registered now, then something has gone very, very wrong - Escalate."
# Clearing Yum Cache, as we may have changed some information.
	echo "Final testing/cleanup..."
	yum clean all | log
# Basically, a transaction test. Cross your fingers.
	echo "Determining whether there are any updates available (I.E. can we hit the repos successfully?)"
	yum check-update
	echo "Finished!"
else
	echo "Exiting!"
	fi
