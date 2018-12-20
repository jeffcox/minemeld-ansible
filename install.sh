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

# ===
# Variables
# ===

tmpdir=$(mktemp -d)
tmppip=$(mktemp)
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )" #thanks stackexchange
wherearewe=$(basename $DIR)
usedev=0
addtogroup=0
mmstatusalias="sudo -u minemeld /opt/minemeld/engine/current/bin/supervisorctl -c /opt/minemeld/supervisor/config/supervisord.conf status"
rhelver=0
aliasanswer=""
groupanswer=""

# ===
# Functions
# ===

# Apt based?
lsb_install(){
    if [[ -x $(which apt-get) ]]; then
        if [ $(lsb_release -is) == "Ubuntu" ]; then
            echo "Detectd Ubuntu"
            if [[ $(lsb_release -rs) == "14.04" ]]; then
                echo "Version 14.04 is supported, proceeding"
                apt-get update
                apt-get upgrade
                apt-get install -y gcc git python2.7-dev libffi-dev libssl-dev make
            elif [[ $(lsb_release -rs) == "16.04" ]]; then
                echo "Version 16.04 is supported, proceeding"
                apt-get update
                apt-get upgrade
                apt-get install -y gcc git python-minimal python2.7-dev libffi-dev libssl-dev make
            else; then
                echo "Sorry, did not detect a supported version"
            fi
        elif [[ $(lsb_release -is) == "Debian" ]]; then
            echo "Detected Debian"
            if [[ $(lsb_release -rs) == "7" || $(lsb_release -rs) ==  "9" ]]; then
                echo "Debian 7 and 9 are supported, proceeding"
                apt-get update
                apt-get upgrade
                apt-get install -y gcc git python2.7-dev libffi-dev libssl-dev
            fi
        else;
            echo "Sorry, you're not supported"
        fi
    fi
}

# RHEL/CentOS 7
rhel_install(){
    if [[ -x $(which yum) ]]; then
        if [[ -r /etc/os-release ]]; then
            rhelver=$(grep 'REDHAT_SUPPORT_PRODUCT_VERSION' /etc/os-release | grep -o [0-9])
            if [[ rhelver == 7 ]]; then
                echo "Detected RHEL or CentOS 7, proceeding"
                yum install -y wget git gcc python-devel libffi-devel openssl-devel
            else;
                echo "Could not detect a supported version of RedHat or CentOS"
        fi
    else;
        echo "Unexpected error, how did you get here?"
    fi
}

# Add an alias for checking on minemeld to shell rcs
# I'm pretty sure this would never work for zsh but low priority
addalias(){
    if [[ $0 == "bash" ]]; then
        if [[ -w /etc/bashrc ]]
            echo ${mmstatusalias} >> /etc/bashrc
        elif [[ -w ~${real_user}/.bashrc ]]; then
            echo ${mmstatusalias} >> ~${real_user}/.bashrc
        else;
            echo "Unexpected error"
    elif [[ $0 == "zsh" ]]; then
        if [[ -w /etc/zshrc ]]
            echo ${mmstatusalias} >> /etc/zshrc
        elif [[ -w ~${real_user}/.zshrc ]]; then
            echo ${mmstatusalias} >> ~${real_user}/.zshrc
        else;
            echo "Unexpected error"
        fi
    fi
}

# Get pip
getpip(){
    if [[ -x $(which wget) ]]; then
        wget -O ${tmppip} https://bootstrap.pypa.io/get-pip.py
    else;
        echo 'Something is wrong with your $PATH or wget'
    fi
    if [[ -x $(/usr/bin/env python) ]]; then
        python ${tmppip}
    else;
        echo 'Error invoking python, please check your $PATH and try again'
    fi
}

# Get ansible from pip
getansible(){
    if [[ -x $(which pip) ]]; then
        pip install ansible
    else;
        "Unexpected error with pip installation"
    fi
}

# Check if we're in the minemeld ansible repo
gitmm(){
    if [[ $wherearewe == "minemeld-ansible" ]]; then
        echo "Looks like you already have the Ansible Playbook, skipping git clone"
    else;
        git clone https://github.com/PaloAltoNetworks/minemeld-ansible.git ${tmpdir}
    fi
}

# Run the ansible playbook
runplaybook(){
    echo "Running Ansible Playbook"
    if [[ -r local.yaml ]]; then
        ansible-playbook -K -i 127.0.0.1, local.yml
    elif [[ -d minemeld-ansible ]]; then
        if [[ -r ${tmpdir}/local.yaml ]]
            ansible-playbook -K -i 127.0.0.1, ${tmpdir}/local.yml
        fi
    else;
        echo "Could not read ansible playbook, something is wrong"
    fi
}

# Add the user to the MM group
groupadd(){
    if [[ $addtogroup ]]; then
        if [[ -x $(which usermod) ]]; then
            usermod -a -G minemeld ${real_user} # add your user to minemeld group, useful for development
        elsif [[ -x /usr/sbin/usermod ]]; then
            /usr/sbin/usermod -a -G minemeld ${real_user}
        else;
            echo "Unexpected error updating your group membership"
    fi
}

# Read /etc for version info
distrocheck(){
    if [[ -r /etc/centos-release ]]; then
        rhel_install
    elif [[ -r /etc/redhat-release ]]; then
        rhel_install
    elif [[ -r /etc/lsb-release ]]; then
        lsb_install
    else;
        echo "Sorry, no supported distro detected"
    fi
}

# ===
# Main
# ===

distrocheck

if [[ -x $(which pip) ]]; then
    getansible
else;
    getpip
    getansible
fi

gitmm

runplaybook

# Check Minemeld status
echo "Waiting 30 seconds for MineMeld to start"
sleep 30
sudo -u minemeld /opt/minemeld/engine/current/bin/supervisorctl -c /opt/minemeld/supervisor/config/supervisord.conf status

# Add to group?
while [[ groupanswer=="" ]]; do
    read -p "Add an alias for MineMeld Satus? [y/n]: " groupanswer
    if [[ $(groupanswer) == "Y" || $(groupanswer) == "y" ]]; then
        groupadd
    elif [[ $(groupanswer) == "N" || $(groupanswer) == "n" ]]; then
        break
    else;
        echo "Bad input"
        groupanswer=""
    fi
done

# Add aliases to /etc/profile?
while [[ aliasanswer=="" ]]; do
    read -p "Add an alias for MineMeld Satus? [y/n]: " aliasanswer
    if [[ $(aliasanswer) == "Y" || $(aliasanswer) == "y" ]]; then
        addalias
    elif [[ $(aliasanswer) == "N" || $(aliasanswer) == "n" ]]; then
        break
    else;
        echo "Bad input"
        aliasanswer=""
    fi
done
