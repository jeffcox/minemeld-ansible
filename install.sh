#! /usr/bin/env bash
# Determine host OS and if possible perform the steps for a Minemeld install

# Check for and require root execution
if ! [ $(id -u) = 0 ]; then
   echo "The script need to be run as root." >&2
   exit 1
fi

# Store the user who launched the script
if [ $SUDO_USER ]; then
    real_user=$SUDO_USER
else
    real_user=$(whoami)
fi

# Variables
tmpdir=${mktemp -d}
tmppip=${mktemp}
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )" #thanks stackexchange
wherearewe=$(basename $DIR)
usedev=0
addtogroup=0
mmstatusalias=$(mmstatusalias)

# Init and user prompts
echo "This script will attempt to install Minemeld for your distro"

echo "Palo Alto Networks recommends using the develop branch."
echo "Would you like to use develop or master?"

echo "Add your account to the minemeld group?"
echo "(Recommended for development and troubleshooting)"

# TODO: Split detection and installation account for not having lsb_release
if [[ -r /etc/centos-release ]]; then
    centos_install
elif [[ -r /etc/redhat-release ]]; then
    redhat_install
elif [[ -r /etc/lsb-release ]]; then
    lsb_install
else;
    echo "Sorry, no supported distro detected"
fi

# Apt based?
# Needs testing
lsb_install(){
    if [[ -x $(which apt-get) ]]; then
        if [ $(lsb_release -is) == "Ubuntu" ]; then
            echo -e "Detectd Ubuntu"
            if [[ $(lsb_release -rs) == "14.04" ]]; then
                echo -e "Version 14.04 is supported, proceeding"
                apt-get update
                apt-get upgrade
                apt-get install -y gcc git python2.7-dev libffi-dev libssl-dev make
            elif [[ $(lsb_release -rs) == "16.04" ]]; then
                echo -ne "Version 16.04 is supported, proceeding"
                apt-get update
                apt-get upgrade
                apt-get install -y gcc git python-minimal python2.7-dev libffi-dev libssl-dev make
            else; then
                echo "Sorry, did not detect a supported version"
            fi
        elif [[ $(lsb_release -is) == "Debian" ]]; then
            echo -e "Detected Debian"
            if [[ $(lsb_release -rs) == "7" || $(lsb_release -rs) ==  "9" ]]; then
                echo -e "Debian 7 and 9 are supported, proceeding"
                apt-get update
                apt-get upgrade
                apt-get install -y gcc git python2.7-dev libffi-dev libssl-dev
            fi
        else;
            echo "Sorry dude, you're not supported"
        fi
    fi
}

# RHEL/CentOS 7
# This is broken for sure
centos_install(){
    if [[ -x $(which yum) ]]; then
        if [[ $(lsb_release -is) == "CentOS" && $(lsb_release -rs) == "7" ]]; then
            echo -e "Detected CentOS"
            echo -e "CentOS 7 is supported, proceeding"
            yum install -y wget git gcc python-devel libffi-devel openssl-devel
        fi
    fi
}
# Universal steps begin

# Fetch pip
if [[ -x $(which wget) ]]; then
    wget -O $(tmppip) https://bootstrap.pypa.io/get-pip.py
else;
    echo 'Something is wrong with your $PATH or wget'
fi

# Install pip
if [[ -x $(/usr/bin/env python) ]]; then
    python $(tmppip)
else;
    echo 'Error invoking python, please check your $PATH and try again'
fi

# Install Ansible
if [[ -x $(which pip) ]]; then
    pip install ansible
fi

# Check if we're in the minemeld ansible repo

if [[ $wherearewe == "minemeld-ansible" ]]; then
    echo "Looks like you already have the Ansible Playbook, skipping git clone"
else;
    git clone https://github.com/PaloAltoNetworks/minemeld-ansible.git $(tmpdir)
fi

# Run the ansible playbook
echo "Running Ansible Playbook"
if [[ -r local.yaml ]]; then
    ansible-playbook -K -i 127.0.0.1, local.yml
elif [[ -d minemeld-ansible ]]; then
    if [[ -r $(tmpdir)/local.yaml ]]
        ansible-playbook -K -i 127.0.0.1, $(tmpdir)/local.yml
    fi
else;
    echo "Could not read ansible playbook, something is wrong"
fi

# Add the user who started this to minemeld group
if [[ $addtogroup ]]; then
    if [[ -x $(which usermod) ]]; then
        usermod -a -G minemeld ${real_user} # add your user to minemeld group, useful for development
    elsif [[ -x /usr/sbin/usermod ]]; then
        /usr/sbin/usermod -a -G minemeld ${real_user}
    else;
        echo "Unexpected error updating your group membership"
fi

# Clean up

# Check Minemeld status
sudo -u minemeld /opt/minemeld/engine/current/bin/supervisorctl -c /opt/minemeld/supervisor/config/supervisord.conf status

# Add aliases to /etc/profile?
addalias(){
    if [[ $0 == "bash" ]]; then
        if [[ -w /etc/bashrc ]]
            echo $(mmstatusalias) >> /etc/bashrc
        elif [[ -w ~$(real_user)/.bashrc ]]; then
            echo $(mmstatusalias) >> ~$(real_user)/.bashrc
        else;
            echo "Unexpected error"
    elif [[ $0 == "zsh" ]]; then
        if [[ -w /etc/zshrc ]]
            echo $(mmstatusalias) >> /etc/zshrc
        elif [[ -w ~$(real_user)/.zshrc ]]; then
            echo $(mmstatusalias) >> ~$(real_user)/.zshrc
        else;
            echo "Unexpected error"
        fi
    fi
}
