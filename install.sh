#! /usr/bin/env bash
# Determine host OS and if possible perform the steps for a Minemeld install

# Check for and require root execution
if ! [ $(id -u) = 0 ]; then
   echo "The script need to be run as root." >&2
   echo ""
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
lsb_install() {
    if [[ -x $(which apt-get 2>/dev/null) ]]; then
        if [ $(lsb_release -is) == "Ubuntu" ]; then
            echo "Detectd Ubuntu"
            echo ""
            if [[ $(lsb_release -rs) == "14.04" ]]; then
                echo "Version 14.04 is supported, proceeding"
                echo ""
                apt-get update
                apt-get upgrade
                apt-get install -y gcc git python2.7-dev libffi-dev libssl-dev make
            elif [[ $(lsb_release -rs) == "16.04" ]]; then
                echo "Version 16.04 is supported, proceeding"
                echo ""
                apt-get update
                apt-get upgrade
                apt-get install -y gcc git python-minimal python2.7-dev libffi-dev libssl-dev make
            else
                echo "Sorry, did not detect a supported version"
                echo ""
            fi
        elif [[ $(lsb_release -is) == "Debian" ]]; then
            echo "Detected Debian"
            echo ""
            if [[ $(lsb_release -rs) == "7" || $(lsb_release -rs) ==  "9" ]]; then
                echo "Debian 7 and 9 are supported, proceeding"
                echo ""
                apt-get update
                apt-get upgrade
                apt-get install -y gcc git python2.7-dev libffi-dev libssl-dev
            fi
        else
            echo "Sorry, you're not supported"
            echo ""
            exit 0
        fi
    fi
}

# RHEL/CentOS 7
rhel_install() {
    if [[ -x $(which yum 2>/dev/null) ]]; then
        if [[ -r /etc/os-release ]]; then
            rhelver=$(grep 'REDHAT_SUPPORT_PRODUCT_VERSION' /etc/os-release | grep -o [0-9])
            if [[ ${rhelver} == "7" ]]; then
                echo "Detected RHEL or CentOS 7, proceeding"
                echo ""
                yum install -y wget git gcc python-devel libffi-devel openssl-devel
            else
                echo "Could not detect a supported version of RedHat or CentOS"
                echo ""
            fi
        fi
    else
        echo "Unexpected error, how did you get here?"
        echo ""
        exit 0
    fi
}

# Get pip
getpip() {
    if [[ -x $(which wget 2>/dev/null) ]]; then
        wget -O ${tmppip} https://bootstrap.pypa.io/get-pip.py
    elif [[ -x $(which curl 2>/dev/null) ]]; then
        curl -o ${tmppip} https://bootstrap.pypa.io/get-pip.py
    else
        echo "Can't find curl or wget, you need one of them"
        echo ""
        exit 0
    fi

    if [[ -x $(which python 2>/dev/null) ]]; then
        if [[ -s ${tmppip} ]]; then
            python ${tmppip}
        else
            echo "Something went wrong with pip installation"
            echo ""
            exit 0
        fi
    fi
}

# Get ansible from pip
getansible() {
    if [[ -x $(which pip 2>/dev/null) ]]; then
        pip install ansible
    else
        echo "Unexpected error with pip installation"
        echo ""
        exit 0
    fi
}

# Check if we're in the minemeld ansible repo
gitmm() {
    if [[ $wherearewe == "minemeld-ansible" ]]; then
        echo "Looks like you already have the Ansible Playbook, skipping git clone"
        echo ""
    else
        git clone https://github.com/PaloAltoNetworks/minemeld-ansible.git ${tmpdir}
    fi
}

# Run the ansible playbook
runplaybook() {
    echo "Running Ansible Playbook"
    echo ""
    if [[ -r local.yml ]]; then
        ansible-playbook -K -i 127.0.0.1, local.yml
    elif [[ -r ${tmpdir}/local.yml ]]; then
        ansible-playbook -K -i 127.0.0.1, ${tmpdir}/local.yml
    else
        echo "Could not read ansible playbook, something is wrong"
        echo ""
        exit 0
    fi
}

# Read /etc for version info
distrocheck() {
    if [[ -r /etc/centos-release ]]; then
        rhel_install
    elif [[ -r /etc/redhat-release ]]; then
        rhel_install
    elif [[ -r /etc/lsb-release ]]; then
        lsb_install
    else
        echo "Sorry, no supported distro detected"
        echo ""
    fi
}

# ===
# Main
# ===

distrocheck

if [[ -x $(which pip 2>/dev/null)  ]]; then
    getansible
else
    getpip
    getansible
fi

gitmm

runplaybook

# Check Minemeld status
sleep 5
echo "Waiting for MineMeld to start"
sleep 45

sudo -u minemeld /opt/minemeld/engine/current/bin/supervisorctl -c /opt/minemeld/supervisor/config/supervisord.conf status
