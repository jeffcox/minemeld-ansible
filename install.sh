#! /usr/bin/env bash
# Determine host OS and if possible perform the steps for a Minemeld install

# TODO: Figure out something more elegant for privelege escalation
# Littering this with sudos is dumb

# Init and user prompts
echo "This script will attempt to install Minemeld for your distro"

echo "Palo Alto Networks recommends using the develop branch."
echo "Would you like to use develop or master?"

# Apt based?
# Needs testing
if [[ -x $(which apt-get) ]]; then
    if [ $(lsb_release -is) == "Ubuntu" ]; then
        echo -e "Detectd Ubuntu"
        if [ $(lsb_release -rs) ==  "14.04"]; then
            echo -e "Version 14.04 is supported, proceeding"
            sudo apt-get update
            sudo apt-get upgrade
            sudo apt-get install -y gcc git python2.7-dev libffi-dev libssl-dev make
        elif [ $(lsb_release -rs) ==  "16.04"]; then
            echo -ne "Version 16.04 is supported, proceeding"
            sudo apt-get update
            sudo apt-get upgrade
            sudo apt-get install -y gcc git python-minimal python2.7-dev libffi-dev libssl-dev make
        else; then
            echo "Sorry, did not detect a supported version"
        fi
    elif [ $(lsb_release -is) == "Debian" ]; then
        echo -e "Detected Debian"
        if [ $(lsb_release -rs) ==  "7" ] or [ $(lsb_release -rs) ==  "9" ]; then
            echo -e "Debian 7 and 9 are supported, proceeding"
            sudo apt-get update
            sudo apt-get upgrade # optional
            sudo apt-get install -y gcc git python2.7-dev libffi-dev libssl-dev
        fi
    else;
        echo "Sorry dude, you're not supported"
    fi
fi


# RHEL/CentOS 7
# This is broken for sure
if [[ -x $(which yum) ]]; then
    if [ $(lsb_release -is) == "CentOS" ] and [ $(lsb_release -rs) == "7" ]; then
        echo -e "Detected CentOS"
        echo -e "CentOS 7 is supported, proceeding"
        sudo yum install -y wget git gcc python-devel libffi-devel openssl-devel
    fi
fi

# Universal steps begin

# Fetch pip
if [[ -x $(which wget) ]]; then
    wget https://bootstrap.pypa.io/get-pip.py
else;
    echo 'Something is wrong with your $PATH or wget'
fi

# Check for python and ensure we're using 2.7
if [[ -x $(which python) ]]; then


fi

# Install pip
sudo -H python get-pip.py

# Install ansible
sudo -H pip install ansible

# Get the ansible repo
git clone https://github.com/PaloAltoNetworks/minemeld-ansible.git

# Run the ansible playbook
ansible-playbook -K -i 127.0.0.1, minemeld-ansible/local.yml

# Add the user who started this to minemeld group
# check $PATH and sudo requirements for Debian, was 'sudo /usr/sbin/usermod'
usermod -a -G minemeld <your user> # add your user to minemeld group, useful for development

# Clean up

# Check Minemeld status
sudo -u minemeld /opt/minemeld/engine/current/bin/supervisorctl -c /opt/minemeld/supervisor/config/supervisord.conf status

# Add aliases to /etc/profile?
echo "Would you like to create aliases for minemeld?"