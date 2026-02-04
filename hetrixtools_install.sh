#!/bin/bash
#
#
#	HetrixTools Server Monitoring Agent - macOS Install Script
#	Copyright 2015 - 2026 @  HetrixTools
#	For support, please open a ticket on our website https://hetrixtools.com
#
#
#		DISCLAIMER OF WARRANTY
#
#	The Software is provided "AS IS" and "WITH ALL FAULTS," without warranty of any kind, 
#	including without limitation the warranties of merchantability, fitness for a particular purpose and non-infringement. 
#	HetrixTools makes no warranty that the Software is free of defects or is suitable for any particular purpose. 
#	In no event shall HetrixTools be responsible for loss or damages arising from the installation or use of the Software, 
#	including but not limited to any indirect, punitive, special, incidental or consequential damages of any character including, 
#	without limitation, damages for loss of goodwill, work stoppage, computer failure or malfunction, or any and all other commercial damages or losses. 
#	The entire risk as to the quality and performance of the Software is borne by you, the user.
#
#		END OF DISCLAIMER OF WARRANTY

# Set PATH
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/homebrew/bin:/opt/homebrew/sbin

# Branch
BRANCH="main"

# Check if first argument is branch or SID
if [ ${#1} -ne 32 ]
then
	BRANCH=$1
	shift
fi

# Check if install script is run by root
echo "Checking root privileges..."
if [ "$EUID" -ne 0 ]
	then echo "ERROR: Please run the install script as root."
	exit 1
fi
echo "... done."

# Check if this is macOS
echo "Checking operating system..."
if [ "$(uname)" != "Darwin" ]
	then echo "ERROR: This installer is for macOS only."
	exit 1
fi
echo "... done."

# Check if the selected branch exists
echo "Checking branch..."
if curl -sf --head "https://raw.githubusercontent.com/hetrixtools/agent-macos/$BRANCH/hetrixtools_agent.sh" > /dev/null 2>&1
then
	echo "Installing from $BRANCH branch..."
else
	echo "ERROR: Branch $BRANCH does not exist."
	exit 1
fi

# Fetch Server Unique ID
SID=$1

# Make sure SID is not empty
echo "Checking Server ID (SID)..."
if [ -z "$SID" ]
	then echo "ERROR: First parameter missing."
	exit 1
fi
echo "... done."

# Check if user has selected to run agent as 'root' or not
if [ -z "$2" ]
	then echo "ERROR: Second parameter missing."
	exit 1
fi

# Check for required system utilities
echo "Checking system utilities..."
for cmd in curl top vm_stat sysctl netstat df ifconfig; do
	command -v "$cmd" >/dev/null 2>&1 || { echo "ERROR: $cmd is required to run this agent." >&2; exit 1; }
done
echo "... done."

# Remove old agent (if exists)
echo "Checking if there's any old hetrixtools agent already installed..."
if [ -d /opt/hetrixtools ]
then
	echo "Old hetrixtools agent found, deleting it..."
	rm -rf /opt/hetrixtools
else
	echo "No old hetrixtools agent found..."
fi
echo "... done."

# Creating agent folder
echo "Creating the hetrixtools agent folder..."
mkdir -p /opt/hetrixtools
echo "... done."

# Fetching the agent
echo "Fetching the agent..."
if ! curl -sf -o /opt/hetrixtools/hetrixtools_agent.sh "https://raw.githubusercontent.com/hetrixtools/agent-macos/$BRANCH/hetrixtools_agent.sh"
then
	echo "ERROR: Failed to download the agent script from GitHub."
	exit 1
fi
echo "... done."

# Fetching the config file
echo "Fetching the config file..."
if ! curl -sf -o /opt/hetrixtools/hetrixtools.cfg "https://raw.githubusercontent.com/hetrixtools/agent-macos/$BRANCH/hetrixtools.cfg"
then
	echo "ERROR: Failed to download the agent configuration from GitHub."
	exit 1
fi
echo "... done."

# Fetching the wrapper script
echo "Fetching the wrapper script..."
if ! curl -sf -o /opt/hetrixtools/run_agent.sh "https://raw.githubusercontent.com/hetrixtools/agent-macos/$BRANCH/run_agent.sh"
then
	echo "ERROR: Failed to download the wrapper script from GitHub."
	exit 1
fi
echo "... done."

# Setting permissions
echo "Setting permissions..."
chmod +x /opt/hetrixtools/hetrixtools_agent.sh
chmod +x /opt/hetrixtools/run_agent.sh
chmod 600 /opt/hetrixtools/hetrixtools.cfg
echo "... done."

# Inserting Server ID (SID) into the agent config
echo "Inserting Server ID (SID) into agent config..."
sed -i '' "s/SID=\"\"/SID=\"$SID\"/" /opt/hetrixtools/hetrixtools.cfg
echo "... done."

# Check if any services are to be monitored
echo "Checking if any services should be monitored..."
if [ "$3" != "0" ]
then
	echo "Services found, inserting them into the agent config..."
	sed -i '' "s/CheckServices=\"\"/CheckServices=\"$3\"/" /opt/hetrixtools/hetrixtools.cfg
fi
echo "... done."

# Check if software RAID should be monitored
echo "Checking if software RAID should be monitored..."
if [ "$4" -eq "1" ] 2>/dev/null
then
	echo "Enabling software RAID monitoring in the agent config..."
	sed -i '' "s/CheckSoftRAID=0/CheckSoftRAID=1/" /opt/hetrixtools/hetrixtools.cfg
fi
echo "... done."

# Check if Drive Health should be monitored
echo "Checking if Drive Health should be monitored..."
if [ "$5" -eq "1" ] 2>/dev/null
then
	echo "Enabling Drive Health monitoring in the agent config..."
	sed -i '' "s/CheckDriveHealth=0/CheckDriveHealth=1/" /opt/hetrixtools/hetrixtools.cfg
fi
echo "... done."

# Check if 'View running processes' should be enabled
echo "Checking if 'View running processes' should be enabled..."
if [ "$6" -eq "1" ] 2>/dev/null
then
	echo "Enabling 'View running processes' in the agent config..."
	sed -i '' "s/RunningProcesses=0/RunningProcesses=1/" /opt/hetrixtools/hetrixtools.cfg
fi
echo "... done."

# Check if any ports to monitor number of connections on
echo "Checking if any ports to monitor number of connections on..."
if [ "$7" != "0" ]
then
	echo "Ports found, inserting them into the agent config..."
	sed -i '' "s/ConnectionPorts=\"\"/ConnectionPorts=\"$7\"/" /opt/hetrixtools/hetrixtools.cfg
fi
echo "... done."

# Killing any running hetrixtools agents
echo "Making sure no hetrixtools agent scripts are currently running..."
pkill -f hetrixtools_agent.sh 2>/dev/null
echo "... done."

# Checking if _hetrixtools user exists (macOS uses underscore prefix for service accounts)
echo "Checking if _hetrixtools user already exists..."
if id -u _hetrixtools >/dev/null 2>&1
then
	echo "The _hetrixtools user already exists, killing its processes..."
	pkill -9 -u _hetrixtools 2>/dev/null
	echo "Deleting _hetrixtools user..."
	dscl . -delete /Users/_hetrixtools 2>/dev/null
fi
if [ "$2" -ne "1" ] 2>/dev/null
then
	echo "Creating the _hetrixtools user..."
	# Find an available UID in the service account range (400-499)
	HTUID=400
	while dscl . -list /Users UniqueID 2>/dev/null | awk '{print $2}' | grep -q "^${HTUID}$"; do
		HTUID=$((HTUID + 1))
	done
	dscl . -create /Users/_hetrixtools
	dscl . -create /Users/_hetrixtools UniqueID "$HTUID"
	dscl . -create /Users/_hetrixtools PrimaryGroupID 20
	dscl . -create /Users/_hetrixtools UserShell /usr/bin/false
	dscl . -create /Users/_hetrixtools NFSHomeDirectory /opt/hetrixtools
	dscl . -create /Users/_hetrixtools RealName "HetrixTools Agent"
	# Hide the user from the login window
	dscl . -create /Users/_hetrixtools IsHidden 1
	echo "Assigning permissions for the _hetrixtools user..."
	chown -R _hetrixtools:staff /opt/hetrixtools
	chmod -R 700 /opt/hetrixtools
else
	echo "Agent will run as 'root' user..."
	chown -R root:wheel /opt/hetrixtools
	chmod -R 700 /opt/hetrixtools
fi
echo "... done."

# Removing old launchd job (if exists)
echo "Removing any old hetrixtools launchd job, if exists..."
if launchctl list 2>/dev/null | grep -q "com.hetrixtools.agent"
then
	launchctl unload /Library/LaunchDaemons/com.hetrixtools.agent.plist 2>/dev/null
fi
rm -f /Library/LaunchDaemons/com.hetrixtools.agent.plist 2>/dev/null
echo "... done."

# Removing old crontab entry (if exists)
echo "Removing any old hetrixtools crontab entry, if exists..."
crontab -l 2>/dev/null | grep -v 'hetrixtools' | crontab - 2>/dev/null
echo "... done."

# Setting up the launchd job to run the agent every minute
echo "Setting up the launchd job..."
if [ "$2" -eq "1" ] 2>/dev/null
then
	AGENT_USER="root"
else
	AGENT_USER="_hetrixtools"
fi
cat > /Library/LaunchDaemons/com.hetrixtools.agent.plist << PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>com.hetrixtools.agent</string>
	<key>ProgramArguments</key>
	<array>
		<string>/bin/bash</string>
		<string>/opt/hetrixtools/run_agent.sh</string>
	</array>
	<key>WorkingDirectory</key>
	<string>/opt/hetrixtools</string>
	<key>UserName</key>
	<string>${AGENT_USER}</string>
	<key>StartCalendarInterval</key>
	<dict>
		<key>Second</key>
		<integer>0</integer>
	</dict>
	<key>RunAtLoad</key>
	<true/>
	<key>AbandonProcessGroup</key>
	<true/>
</dict>
</plist>
PLIST_EOF
launchctl load /Library/LaunchDaemons/com.hetrixtools.agent.plist 2>/dev/null
echo "... done."

# Cleaning up install file
echo "Cleaning up the installation file..."
if [ -f "$0" ]
then
	rm -f "$0"
fi
echo "... done."

# Let HetrixTools platform know install has been completed
echo "Letting HetrixTools platform know the installation has been completed..."
POST="v=install&s=$SID"
curl -s --retry 3 --retry-delay 1 --max-time 15 --data "$POST" https://sm.hetrixtools.net/ > /dev/null 2>&1
echo "... done."

# Start the agent
if [ "$2" -eq "1" ] 2>/dev/null
then
	echo "Starting the agent under the 'root' user..."
	bash /opt/hetrixtools/hetrixtools_agent.sh > /dev/null 2>&1 &
else
	echo "Starting the agent under the '_hetrixtools' user..."
	sudo -u _hetrixtools bash /opt/hetrixtools/hetrixtools_agent.sh > /dev/null 2>&1 &
fi
echo "... done."

# All done
echo "HetrixTools agent installation completed."
