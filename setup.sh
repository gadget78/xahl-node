#!/bin/bash
version=0.93

# *** check and setup permissions ***
# Get current user id and store as var
USER_ID=$(getent passwd $EUID | cut -d: -f1)

# Authenticate sudo perms before script execution to avoid timeouts or errors
echo "checking privileges..."
if sudo -l > /dev/null 2>&1; then
    echo "privleges all good..."
    echo "just going to extend the timeout period, so sudo privleges do not timeout while installing.."
    # extend sudo timeout for USER_ID to an hour, instead of default 5min
    echo "Defaults:$USER_ID timestamp_timeout=120" > /tmp/xahlsudotmp
    # add visudo check ? 
    sudo sh -c 'cat /tmp/xahlsudotmp > /etc/sudoers.d/xahlnode_deploy'

else
    if [ -f "/root/xahl-node/setup.sh" ]; then
        echo
        echo "this user ($USER_ID) does not have full sudo privilages, going to try root user..."
        if su -c "./setup.sh $USER_ID" root; then
            exit
        else
            if [ $? -eq 1 ]; then
            echo
            echo "Incorrect password for root user."
            else
            echo 
            echo "Failed to execute the script with "root" user ID."
            echo "please log into a user with root privledges and try again."
            exit
            fi
        fi
    else
        echo 
        echo "this user ($USER_ID) does not have full sudo privilages"
        echo "please log into a user with root privledges and try again."
        exit
    fi
fi


# *** SETUP INITIAL VARIABLES THAT THIS SCRiPT NEEDS

# Set Colour Vars
GREEN='\033[0;32m'
#RED='\033[0;31m'
RED='\033[0;91m'  # Intense Red
YELLOW='\033[0;33m'
BYELLOW='\033[1;33m'
BLUE='\033[0;94m'
NC='\033[0m' # No Color

# Get the absolute path of the script directory
# and import variables

cd ~
sudo mkdir -p xahl-node
cd ~/xahl-node
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# Check for the .var file, if not present, generate a default one
FUNC_VARS_VARIABLE_CHECK(){
if [  ! -f $SCRIPT_DIR/xahl_node.vars ]; then
    echo -e "$SCRIPT_DIR/xahl_node.vars file missing, generating a new one...${NC}"
    sudo cat <<EOF > $SCRIPT_DIR/xahl_node.vars
vars_version="$version"
# These are the default variables for the setup.sh script to use.
# you can change these to suit you needs and enviroment.
# all saved question data is in .env file
#  - for example, 
#    always_ask, will ask all question every time, with promt of past anser, false skips if answered before
#    install certbot, will stop the install of the cert bot, so it can be used without the need for SSL
#    install landingpage, having this on false, will prevent it deleteing and re-installing the landing pages (if you have a custom one)
#    install_toml, as above, you can force setup from messing with you .toml file

# variables for size setup
TINY_LEDGER_HISTORY="2048"
TINY_LEDGER_DELETE="2048"
MEDIUM_LEDGER_HISTORY="4096"
MEDIUM_LEDGER_DELETE="4096"

# varibles for script choices
ALWAYS_ASK="true"
INSTALL_UPDATES="true"
VARVAL_CHAIN_NAME="mainnet"
INSTALL_UFW="true"
INSTALL_CERTBOT_SSL="true"
INSTALL_LANDINGPAGE="true"
INSTALL_TOML="true"

# ipv6 can be set to auto (default), true or false, auto uses command \`ip a | grep -c 'inet6.*::1/128'\` 
IPv6="auto" 

# -------------------------------------------------------------------------------
# *** the following variables DO NOT need to be changed ***
# *      these are for the script/nginx setups            *

# ubuntu packages that the main script depends on;
SYS_PACKAGES=(net-tools git curl gpg nano node-ws python3 python3-requests python3-toml whois htop sysstat mlocate apache2-utils)

TOMLUPDATER_URL=https://raw.githubusercontent.com/gadget78/ledger-live-toml-updating/node-dev/validator/update.py

# variables for nginx
NGX_CONF_ENABLED="/etc/nginx/sites-enabled/"
NGX_CONF_NEW="/etc/nginx/sites-available/"
NGINX_CONF_FILE="/etc/nginx/nginx.conf"
NGINX_ALLOWLIST_FILE="nginx_allowlist.conf"
NGINX_PROXY_IP="192.168.0.0/16"

# MAINNET
NGX_MAINNET_RPC="6007"
NGX_MAINNET_WSS="6009" 
XAHL_MAINNET_PEER="21337"

# TESTNET
NGX_TESTNET_RPC="5009"
NGX_TESTNET_WSS="6009"
XAHL_TESTNET_PEER="21338"
EOF
fi

source $SCRIPT_DIR/xahl_node.vars
touch $SCRIPT_DIR/.env
source $SCRIPT_DIR/.env

# check and update old .vars file if it already exsists
if [ -z "$ALWAYS_ASK" ]; then
    ALWAYS_ASK="true"
    sudo sh -c "echo 'ALWAYS_ASK="true"' >> $SCRIPT_DIR/xahl_node.vars"
fi
if [ -z "$NGINX_PROXY_IP" ]; then
    NGINX_PROXY_IP="192.168.0.0/16"
    sed -i '/^NGIINX_PROXY_IP/d' $SCRIPT_DIR/xahl_node.vars
    #sudo sh -c "echo 'NGINX_PROXY_IP="192.168.0.0/16"' >> $SCRIPT_DIR/xahl_node.vars"
    sudo sed -i '/^NGINX_ALLOWLIST_FILE="nginx_allowlist.conf"/a\NGINX_PROXY_IP="192.168.0.0/16"' $SCRIPT_DIR/xahl_node.vars
    echo -e "${GREEN}## ${YELLOW}xahl-node.vars file updated, by adding entry NGINX_PROXY_IP... ${NC}"
fi
if [ -z "$TOMLUPDATER_URL" ]; then
    TOMLUPDATER_URL=https://raw.githubusercontent.com/gadget78/ledger-live-toml-updating/node-dev/validator/update.py
    sudo sh -c "echo '\n# variables for toml updater' >> $SCRIPT_DIR/xahl_node.vars"
    sudo sh -c "echo 'TOMLUPDATER_URL=https://raw.githubusercontent.com/gadget78/ledger-live-toml-updating/node-dev/validator/update.py' >> $SCRIPT_DIR/xahl_node.vars"
    echo -e "${GREEN}## ${YELLOW}xahl-node.vars file updated, by adding entry TOMLUPDATER_URL... ${NC}"
fi
if [ -z "$IPv6" ]; then
    sudo sed -i "/^INSTALL_TOML=*/a\\ \n# ipv6 can be set to auto (default), true or false, auto uses command \"ip a | grep -c 'inet6.*::1/128'\"\nIPv6=\"auto\"" $SCRIPT_DIR/xahl_node.vars
fi
if [ -z "$vars_version" ] || [ "$vars_version" == "0.8.7" ] || [ "$vars_version" == "0.8.8" ]; then
    vars_version=$version
    sudo sed -i '/^vars_version/d' $SCRIPT_DIR/xahl_node.vars
    sudo sh -c "sed -i '1i vars_version=$version' $SCRIPT_DIR/xahl_node.vars"
    sudo sed -i "s/^NGX_MAINNET_WSS=.*/NGX_MAINNET_WSS=\"6009\"/" $SCRIPT_DIR/xahl_node.vars
    sudo sed -i "s/^NGX_TESTNET_WSS=.*/NGX_TESTNET_WSS=\"6009\"/" $SCRIPT_DIR/xahl_node.vars
    sudo sed -i "s/^NGX_TESTNET_RPC=.*/NGX_TESTNET_RPC=\"5009\"/" $SCRIPT_DIR/xahl_node.vars
    sed -i '/^SYS_PACKAGES/d' $SCRIPT_DIR/xahl_node.vars
    sudo sed -i '/^# ubuntu packages that the main script depends on;/a\SYS_PACKAGES=(net-tools git curl gpg nano node-ws python3 python3-requests python3-toml whois htop sysstat mlocate apache2-utils)' $SCRIPT_DIR/xahl_node.vars
    echo -e "${GREEN}## ${YELLOW}xahl-node.vars file updated to version 0.89... ${NC}"
fi
if echo "$vars_version" | awk '{ exit !($1 < 0.93) }'; then
    vars_version=$version
    sudo sed -i '/^vars_version/d' $SCRIPT_DIR/xahl_node.vars
    sudo sh -c "sed -i '1i vars_version=$version' $SCRIPT_DIR/xahl_node.vars"
    sudo sed -i "s/^TINY_LEDGER_HISTORY=.*/TINY_LEDGER_HISTORY=\"2048\"/" $SCRIPT_DIR/xahl_node.vars
    sudo sed -i "s/^TINY_LEDGER_DELETE=.*/TINY_LEDGER_DELETE=\"2048\"/" $SCRIPT_DIR/xahl_node.vars
    sudo sed -i "s/^MEDIUM_LEDGER_HISTORY=.*/MEDIUM_LEDGER_HISTORY=\"4096\"/" $SCRIPT_DIR/xahl_node.vars
    sudo sed -i "s/^MEDIUM_LEDGER_DELETE=.*/MEDIUM_LEDGER_DELETE=\"4096\"/" $SCRIPT_DIR/xahl_node.vars
    sudo sed -i '/^# ubuntu packages that the main script depends on;/a\SYS_PACKAGES=(net-tools git curl gpg nano node-ws python3 python3-requests python3-toml whois htop sysstat mlocate apache2-utils)' $SCRIPT_DIR/xahl_node.vars
fi
source $SCRIPT_DIR/xahl_node.vars
source $SCRIPT_DIR/.env

#setup date
FDATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
}

FUNC_PKG_CHECK(){
    echo
    echo -e "${GREEN}#########################################################################${NC}"
    echo
    echo -e "${GREEN}## Check/install necessary updates, and Packages... ${NC}"
    echo     

    # update and upgrade the system
    if [ -z "$INSTALL_UPDATES" ]; then
        read -p "do you want to check, and install OS updates? Enter true or false # " INSTALL_UPDATES
        sed -i "s/^INSTALL_UPDATES=.*/INSTALL_UPDATES=\"$INSTALL_UPDATES\"/" $SCRIPT_DIR/xahl_node.vars
    fi
    if [ "$INSTALL_UPDATES" == "true" ]; then
        sudo apt update -y && sudo apt upgrade -y

        echo -e "${GREEN}## cycle through packages in vars file, and install... ${NC}"
        echo     
        # cycle through packages in vars file, and install
        for i in "${SYS_PACKAGES[@]}"
        do
            hash $i &> /dev/null
            if [ $? -eq 1 ]; then
                echo >&2 "package "$i" not found. installing...."
                sudo apt install -y "$i"
            else
                echo "packages "$i" exist, proceeding to next...."
            fi
        done
        echo -e "${GREEN}## ALL PACKAGES INSTALLED.${NC}"
    else
        echo -e "${GREEN}## ${YELLOW}INSTALL_UPDATES set to false in var files, skipping... ${NC}"
    fi
    echo 
    echo -e "${GREEN}#########################################################################${NC}"
    echo
    sleep 2s
}

FUNC_IPV6_CHECK(){
    if [ "$IPv6" != "false" ]; then
        if ! ping -c 1 -4 github.com &> /dev/null && ip a | grep -q 'inet6.*::1/128'; then
            echo -e "${YELLOW}IPv6 environment detected, checking hosts file.${NC}"
            IPv6="true"
            if ! grep -q "github" /etc/hosts; then
                echo '2001:67c:27e4:1064::140.82.121.3 github.com www.github.com' | sudo tee -a /etc/hosts
                echo -e "${YELLOW}Updated hosts file.${NC}"
            fi
        elif [ "$IPv6" == "true" ]; then
            echo -e "${YELLOW}IPv6 environment being forced by .var file, checking hosts file.${NC}"
            if ! grep -q "github" /etc/hosts; then
                echo '2001:67c:27e4:1064::140.82.121.3 github.com www.github.com' | sudo tee -a /etc/hosts
                echo -e "${YELLOW}Updated hosts file.${NC}"
            fi
        else
            echo -e "${YELLOW}Not an exclusive IPv6 enviroment.${NC}"
        fi
    fi
}

FUNC_SETUP_MODE(){
    if [ "$VARVAL_CHAIN_NAME" != "mainnet" ] && [ "$VARVAL_CHAIN_NAME" != "testnet" ] && [ "$VARVAL_CHAIN_NAME" != "logrotate" ]; then
        echo -e "${BLUE}VARVAL_CHAIN_NAME not set in $SCRIPT_DIR/xahl_node.vars"
        echo "Please choose an option:"
        echo "1. Mainnet = configures and deploys/updates xahau node for Mainnet"
        echo "2. Testnet = configures and deploys/updates xahau node for Testnet"
        echo "3. Logrotate = implements the logrotate config for chain log file ${NC}"
        read -p "Enter your choice [1-3] # " choice
        
        case $choice in
            1) 
                VARVAL_CHAIN_NAME="mainnet"
                ;;
            2) 
                VARVAL_CHAIN_NAME="testnet"
                ;;
            3) 
                VARVAL_CHAIN_NAME="logrotate"
                ;;
            *) 
                echo "Invalid option. Exiting."
                FUNC_EXIT
                ;;
        esac
        sed -i "s/^VARVAL_CHAIN_NAME=.*/VARVAL_CHAIN_NAME=\"$VARVAL_CHAIN_NAME\"/" $SCRIPT_DIR/xahl_node.vars
    fi

    if [ "$VARVAL_CHAIN_NAME" == "mainnet" ]; then
        echo -e "${GREEN}### Configuring node for ${BYELLOW}Xahau $VARVAL_CHAIN_NAME${GREEN}... ${NC}"
        VARVAL_CHAIN_RPC=$NGX_MAINNET_RPC
        VARVAL_CHAIN_WSS=$NGX_MAINNET_WSS
        VARVAL_CHAIN_REPO="mainnet-docker"
        VARVAL_CHAIN_PEER=$XAHL_MAINNET_PEER

    elif [ "$VARVAL_CHAIN_NAME" == "testnet" ]; then
        echo -e "${GREEN}### Configuring node for ${BYELLOW}Xahau $VARVAL_CHAIN_NAME${GREEN}... ${NC}"
        VARVAL_CHAIN_RPC=$NGX_TESTNET_RPC
        VARVAL_CHAIN_WSS=$NGX_TESTNET_WSS
        VARVAL_CHAIN_REPO="Xahau-Testnet-Docker"
        VARVAL_CHAIN_PEER=$XAHL_TESTNET_PEER

    elif [ "$VARVAL_CHAIN_NAME" == "logrotate" ]; then
        FUNC_LOGROTATE
        FUNC_EXIT
    fi

    VARVAL_NODE_NAME="xahl_node_$(hostname -s)"
    echo -e "Node name is :${BYELLOW} $VARVAL_NODE_NAME ${NC}"
    echo -e "Local Node RPC port is :${BYELLOW} $VARVAL_CHAIN_RPC ${NC}"
    echo -e "Local WSS port is :${BYELLOW} $VARVAL_CHAIN_WSS ${NC}"
    echo
    echo -e "${GREEN}#########################################################################${NC}"
    echo
}

FUNC_CLONE_NODE_SETUP(){
    echo
    echo -e "${GREEN}#########################################################################${NC}"
    echo
    echo -e "${GREEN}## ${YELLOW}Starting Xahau Node install... ${NC}"
    echo
    
    cd $SCRIPT_DIR
    if [ ! -d "$VARVAL_CHAIN_REPO" ]; then
        echo -e "Creating directory '$SCRIPT_DIR/$VARVAL_CHAIN_REPO' to use for xahaud instalilation..."
        echo -e "Cloning repo https://github.com/Xahau/$VARVAL_CHAIN_REPO' ${NC}"
        git clone https://github.com/Xahau/$VARVAL_CHAIN_REPO
    else
        echo "exsiting directory '$SCRIPT_DIR/$VARVAL_CHAIN_REPO' found, pulling updates..."
        cd $SCRIPT_DIR/$VARVAL_CHAIN_REPO
        git pull
    fi
    if [ -d "/opt/xahaud/" ]; then
        echo "previous xahaud node install found,"
        echo "will stop existing xahaud, check for updates, and re-create xahaud.cfg file..."
        sudo systemctl stop xahaud
    fi

    rm -f /opt/xahaud/etc/xahaud.cfg 
    cd $SCRIPT_DIR/$VARVAL_CHAIN_REPO
    sudo ./xahaud-install-update.sh

    if [ "$VARVAL_CHAIN_NAME" == "mainnet" ]; then
        echo
        echo -e "Updating .cfg file to limit public RPC/WS to localhost ...${NC}"

        sudo sed -i -E '/^\[port_ws_public\]$/,/^\[/ {/^(ip = )0\.0\.0\.0/s/^(ip = )0\.0\.0\.0/\1127.0.0.1/}' /opt/xahaud/etc/xahaud.cfg    
        if grep -qE "^\[port_ws_public\]$" "/opt/xahaud/etc/xahaud.cfg" && grep -q "ip = 0.0.0.0" "/opt/xahaud/etc/xahaud.cfg"; then
            sudo sed -i -E '/^\[port_ws_public\]$/,/^\[/ s/^(ip = )0\.0\.0\.0/\1127.0.0.1/' /opt/xahaud/etc/xahaud.cfg
            sleep 2
            if grep -q "ip = 127.0.0.1" "/opt/xahaud/etc/xahaud.cfg"; then
                echo -e "It appears that [port_ws_public] was able to update correctly. ${NC}"
            else
                echo -e "${RED}Something wrong with updating [port_ws_public] ip in /opt/xahaud/etc/xahaud.cfg. Attempting second time..."
                sudo sed -i -E '/^\[port_ws_public\]$/,/^\[/ s/^(ip = )0\.0\.0\.0/\1127.0.0.1/' /opt/xahaud/etc/xahaud.cfg
                sleep 2
                if grep -q "ip = 127.0.0.1" "/opt/xahaud/etc/xahaud.cfg"; then
                    echo -e "It appears that [port_ws_public] was able to update correctly on the second attempt. ${NC}"
                else
                    echo -e "${RED}Something wrong with updating [port_ws_public] ip in /opt/xahaud/etc/xahaud.cfg. YOU MUST DO MANUALLY! ${NC}"
                fi
            fi
        else
            echo -e "${RED}Something wrong with updating [port_ws_public] ip in /opt/xahaud/etc/xahaud.cfg. YOU MUST DO MANUALLY! ${NC}"
        fi
        
        sudo sed -i -E '/^\[port_rpc_public\]$/,/^\[/ {/^(ip = )0\.0\.0\.0/s/^(ip = )0\.0\.0\.0/\1127.0.0.1/}' /opt/xahaud/etc/xahaud.cfg    
        if grep -qE "^\[port_rpc_public\]$" "/opt/xahaud/etc/xahaud.cfg" && grep -q "ip = 0.0.0.0" "/opt/xahaud/etc/xahaud.cfg"; then
            sudo sed -i -E '/^\[port_rpc_public\]$/,/^\[/ s/^(ip = )0\.0\.0\.0/\1127.0.0.1/' /opt/xahaud/etc/xahaud.cfg
            if grep -q "ip = 127.0.0.1" "/opt/xahaud/etc/xahaud.cfg"; then
                echo -e "It appears that [port_rpc_public] was able to update correctly. ${NC}"
            else
                echo -e "${RED}Something wrong with updating [port_rpc_public] ip in /opt/xahaud/etc/xahaud.cfg. Attempting second time... ${NC}"
                sudo sed -i -E '/^\[port_rpc_public\]$/,/^\[/ s/^(ip = )0\.0\.0\.0/\1127.0.0.1/' /opt/xahaud/etc/xahaud.cfg
                if grep -q "ip = 127.0.0.1" "/opt/xahaud/etc/xahaud.cfg"; then
                    echo -e "It appears that [port_rpc_public] was able to update correctly on the second attempt. ${NC}"
                else
                    echo -e "${RED}Something wrong with updating [port_rpc_public] ip in /opt/xahaud/etc/xahaud.cfg. YOU MUST DO MANUALLY! ${NC}"
                fi
            fi
        else
            echo -e "${RED}Something wrong with updating [port_rpc_public] ip in /opt/xahaud/etc/xahaud.cfg. YOU MUST DO MANUALLY! ${NC}"
        fi
    else
        echo
        echo -e "no .cfg changes needed, as using testnet ...${NC}"
    fi

    if [  "$IPv6" == "true" ]; then
        echo -e "${YELLOW}applying IPv6 changes to xahaud.cfg file.${NC}"
        sudo sed -i "s/0.0.0.0/::/g" /opt/xahaud/etc/xahaud.cfg
        sudo sed -i "s/127.0.0.1/::1/g" /opt/xahaud/etc/xahaud.cfg
    fi
    
    echo
    echo -e "Updating node size in .cfg file  ...${NC}"
    echo
    if [ "$XAHAU_NODE_SIZE" != "tiny" ] && [ "$XAHAU_NODE_SIZE" != "medium" ] && [ "$XAHAU_NODE_SIZE" != "huge" ] || [ "$ALWAYS_ASK" == "true" ]; then
        echo -e "${BLUE}Please choose a config option:"
        echo -e "1. sets config as \"medium\", ledgers capped at $TINY_LEDGER_HISTORY, suitable for around 6GB+ RAM, and 25GB+ HDD+ (supports some evernodes, with NO rep contracts)"
        echo -e "2. sets config as \"huge\", ledgers capped at $MEDIUM_LEDGER_HISTORY, suitable for 16GB+ RAM, 50GB+ SSD+ (supports many evernodes WITH contracts)"
        echo -e "3. sets config as \"huge\", with NO cap on ledger size, suitable for 32G+ RAM, 30TB+ SSD+ (supports many evernodes WITH contracts, and history API/tools${NC}"
        read -p "Enter your choice [1-3] # " choice
        
        case $choice in
            1) 
                XAHAU_NODE_SIZE="small"
                ;;
            2) 
                XAHAU_NODE_SIZE="medium"
                ;;
            3) 
                XAHAU_NODE_SIZE="huge"
                ;;
            *) 
                echo "Invalid option. Exiting."
                FUNC_EXIT
                ;;
        esac
        if sudo grep -q 'XAHAU_NODE_SIZE=' "$SCRIPT_DIR/.env"; then
            sudo sed -i "s/^XAHAU_NODE_SIZE=.*/XAHAU_NODE_SIZE=\"$XAHAU_NODE_SIZE\"/" "$SCRIPT_DIR/.env"
        else
            sudo echo -e "XAHAU_NODE_SIZE=\"$XAHAU_NODE_SIZE\"" >> $SCRIPT_DIR/.env

        fi
    fi
    
    if [ "$XAHAU_NODE_SIZE" == "small" ]; then
        XAHAU_LEDGER_HISTORY=$TINY_LEDGER_HISTORY
        XAHAU_ONLINE_DELETE=$TINY_LEDGER_DELETE
        sudo sed -i "/^\[node_size\]/!b;n;cmedium" /opt/xahaud/etc/xahaud.cfg
    fi
    if [ "$XAHAU_NODE_SIZE" == "medium" ]; then
        XAHAU_LEDGER_HISTORY=$MEDIUM_LEDGER_HISTORY
        XAHAU_ONLINE_DELETE=$MEDIUM_LEDGER_DELETE
        sudo sed -i "/^\[node_size\]/!b;n;chuge" /opt/xahaud/etc/xahaud.cfg
    fi
    if [ "$XAHAU_NODE_SIZE" == "huge" ]; then
        XAHAU_LEDGER_HISTORY="full"
        XAHAU_ONLINE_DELETE=""
        sudo sed -i "/^\[node_size\]/!b;n;chuge" /opt/xahaud/etc/xahaud.cfg
    fi
    echo ".."
    sudo sed -i -e 's/^#\{0,1\}\(\[ledger_history\]\)/\1/; /^\[ledger_history\]/ { n; s/.*/'"$XAHAU_LEDGER_HISTORY"'/; }' /opt/xahaud/etc/xahaud.cfg   
    echo "..."
    sudo grep -q 'online_delete' /opt/xahaud/etc/xahaud.cfg || sed -i '/^online_delete.*/!{ /\[node_db\]/ s/$/\nonline_delete='"$XAHAU_ONLINE_DELETE"'/ }' /opt/xahaud/etc/xahaud.cfg
    echo "...."
    sudo sed -i "s/online_delete=.*/online_delete=$XAHAU_ONLINE_DELETE/" /opt/xahaud/etc/xahaud.cfg
    echo "....."

    echo "restarting xahaud service"
    sudo systemctl restart xahaud.service

    echo 
    echo -e "config changed to ${BYELLOW}$XAHAU_NODE_SIZE${NC} with ledger_history=${BYELLOW}$XAHAU_LEDGER_HISTORY${NC} online_delete=${BYELLOW}$XAHAU_ONLINE_DELETE ${NC}"
    echo
    echo -e "${GREEN}## Finished Xahau Node install ...${NC}"
    echo
    cd $SCRIPT_DIR
    sleep 4s
}

FUNC_UFW_SETUP(){
    # Check UFW config, install/update 
    echo
    echo -e "${GREEN}#########################################################################${NC}"
    echo 
    echo -e "${GREEN}## ${YELLOW}Setup: Checking UFW... ${NC}"
    echo
    sudo ufw version
    if [ $? = 0 ]; then
        echo -e "${GREEN}UFW is ALREADY installed ${NC}"
        echo
        # Setup UFW
        FUNC_SETUP_UFW_PORTS;
        FUNC_ENABLE_UFW;
    else
        echo
        echo -e "${GREEN}## ${YELLOW}UFW is not installed, checking config option... ${NC}"
        echo
        
        if [ -z "$INSTALL_UFW" ]; then
            read -p "Do you want to install UFW (Uncomplicated Firewall) ? enter true or false #" INSTALL_UFW
            sudo sed -i "s/^INSTALL_UFW=.*/INSTALL_UFW=\"$INSTALL_UFW\"/" $SCRIPT_DIR/xahl_node.vars
        fi
        if [ "$INSTALL_UFW" == "true" ]; then
            echo
            echo -e "${GREEN}## ${YELLOW}Setup: Installing UFW... ${NC}"
            echo
            sudo apt install ufw
            FUNC_SETUP_UFW_PORTS;
            FUNC_ENABLE_UFW;
        fi
    fi
}

FUNC_SETUP_UFW_PORTS(){
    echo 
    echo -e "${GREEN}#########################################################################${NC}" 
    echo 
    echo -e "${GREEN}## ${YELLOW}Setup: Configure Firewall...${NC}"
    echo 
    echo "allowing Nginx through the firewall."
    sudo ufw allow 'Nginx Full'

    # Get current SSH and xahau node port number, and unblock them
    CPORT=$(sudo ss -tlpn | grep sshd | awk '{print$4}' | cut -d ':' -f 2 -s)
    echo -e "current SSH port number detected as: ${BYELLOW}$CPORT${NC}"
    echo -e "current Xahau Node port number detected as: ${BYELLOW}$CPORT${NC}"
    sudo ufw allow $CPORT/tcp
    sudo ufw allow $VARVAL_CHAIN_PEER/tcp
    sudo ufw status verbose --no-page
    sleep 2s
}

FUNC_ENABLE_UFW(){
    echo 
    echo 
    echo -e "${GREEN}#########################################################################${NC}"
    echo 
    echo -e "${GREEN}## ${YELLOW}Setup: Change UFW logging to ufw.log only${NC}"
    echo 
    # source: https://handyman.dulare.com/ufw-block-messages-in-syslog-how-to-get-rid-of-them/
    sudo sed -i -e 's/\#& stop/\& stop/g' /etc/rsyslog.d/20-ufw.conf
    sudo cat /etc/rsyslog.d/20-ufw.conf | grep '& stop'

    echo 
    echo 
    echo -e "${GREEN}#########################################################################${NC}" 
    echo 
    echo -e "${GREEN}## ${YELLOW}Setup: (re)Enable Firewall...${NC}"
    echo 
    sudo systemctl start ufw && sudo systemctl status ufw verbose --no-page
    echo "y" | sudo ufw enable
    #sudo ufw enable
    sudo ufw status verbose --no-page
    sleep 2s
}

FUNC_CERTBOT_PRECHECK(){
    echo
    echo -e "${GREEN}#########################################################################${NC}"
    echo 
    echo -e "${GREEN}## ${YELLOW}Setup: Checking CERTBOT options... ${NC}"
    echo
    if [ -z "$INSTALL_CERTBOT_SSL" ]; then
        read -e -p "Do you want to use install CERTBOT and use SSL? : true or false # " INSTALL_CERTBOT_SSL
        sudo sed -i "s/^INSTALL_CERTBOT_SSL=.*/INSTALL_CERTBOT_SSL=\"$INSTALL_CERTBOT_SSL\"/" $SCRIPT_DIR/xahl_node.vars
    fi
    if [ "$INSTALL_CERTBOT_SSL" != "true" ]; then
        echo
        echo -e "${GREEN}## ${YELLOW}Setup: INSTALL_CERTBOT_SSL in .vars file set to Skip CERTBOT install... ${NC}"
        echo
        echo -e "${GREEN}#########################################################################${NC}"
        echo
        return
    fi
    echo
    echo -e "${GREEN}## ${YELLOW}CertBot: installing, ready for Setting up... ${NC}"
    echo

    # Install Let's Encrypt Certbot
    sudo apt install certbot python3-certbot-nginx -y
    echo -e "${GREEN}#########################################################################${NC}"
    echo
    sleep 2s

}

FUNC_CERTBOT_REQUEST(){
    echo
    echo -e "${GREEN}#########################################################################${NC}"
    echo
    echo -e "${GREEN}## ${YELLOW}CertBot: final setup and request, and restart nginx ...${NC}"
    echo
    
    if [ "$INSTALL_CERTBOT_SSL" == "true" ]; then
        # Request and install a Let's Encrypt SSL/TLS certificate for Nginx
        echo -e "${GREEN}## ${YELLOW}Setup: Request and install a Lets Encrypt SSL/TLS certificate for domain: ${BYELLOW} $USER_DOMAIN${NC}"
        # make sure correct version is installed
        #sudo pip install --upgrade twine requests-toolbelt
        sudo certbot --nginx  -m "$CERT_EMAIL" -n --agree-tos -d "$USER_DOMAIN"
    else
        echo -e "${GREEN}## ${YELLOW}Setup: skipping installing of Certbot certificate request.${NC}"
    fi

    echo
    echo -e "${GREEN}#########################################################################${NC}"
    sleep 4s

    # Start/Reload Nginx to apply all the new configuration
    if sudo systemctl is-active --quiet nginx; then
        # Nginx is running, so reload its configuration
        sudo systemctl reload nginx
        echo "Nginx reloaded."
    else
        # Nginx is not running, starting it
        sudo systemctl start nginx
        echo "Nginx started."
    fi
    # and enable it to start at boot
    sudo systemctl enable nginx

}

FUNC_PROMPTS_4_DOMAINS_EMAILS() {
    if [ -z "$USER_DOMAIN" ] || [ "$ALWAYS_ASK" == "true" ]; then
        printf "${BLUE}Enter your servers domain (e.g. mydomain.com or a subdomain like xahau.mydomain.com )${NC} # "
        read -e -i "$USER_DOMAIN" USER_DOMAIN
        if sudo grep -q 'USER_DOMAIN=' "$SCRIPT_DIR/.env"; then
            sudo sed -i "s/^USER_DOMAIN=.*/USER_DOMAIN=\"$USER_DOMAIN\"/" "$SCRIPT_DIR/.env"
        else
            sudo echo -e "USER_DOMAIN=\"$USER_DOMAIN\"" >> $SCRIPT_DIR/.env
        fi
    fi

    # Prompt for CERT email if not provided as a variable
    if [ -z "$CERT_EMAIL" ] || [ "$ALWAYS_ASK" == "true" ] || [ "$INSTALL_CERTBOT_SSL" == "true" ]; then
        echo
        printf "${BLUE}Enter your email address for certbot updates ${NC}# "
        read -e -i "$CERT_EMAIL" CERT_EMAIL
        if sudo grep -q 'CERT_EMAIL=' "$SCRIPT_DIR/.env"; then
            sudo sed -i "s/^CERT_EMAIL=.*/CERT_EMAIL=\"$CERT_EMAIL\"/" "$SCRIPT_DIR/.env"
        else
            sudo echo -e "CERT_EMAIL=\"$CERT_EMAIL\"" >> $SCRIPT_DIR/.env
        fi
        echo
    fi
}


FUNC_INSTALL_LANDINGPAGE(){
    echo
    echo -e "${GREEN}#########################################################################${NC}"
    echo 
    echo -e "${GREEN}## ${YELLOW}Setup: Installing Landing page, along with .toml updater... ${NC}"
    echo

    if [ -z "$INSTALL_LANDINGPAGE" ]; then
        read -p "Do you want to (re)install the landng webpage?: true or false # " INSTALL_LANDINGPAGE
        sudo sed -i "s/^INSTALL_LANDINGPAGE=.*/INSTALL_LANDINGPAGE=\"$INSTALL_LANDINGPAGE\"/" $SCRIPT_DIR/xahl_node.vars
    fi
    if [ "$INSTALL_LANDINGPAGE" == "true" ]; then
        
        sudo mkdir -p /home/www
        echo "created /home/www directory for webfiles, now re-installing webpage"

        if [  -f /home/www/index.html ]; then
            sudo rm -f /home/www/index.html
        fi
        sudo cat <<EOF > /home/www/index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <title>Xahau Node</title>
    <link rel="icon" href="https://2820133511-files.gitbook.io/~/files/v0/b/gitbook-x-prod.appspot.com/o/spaces%2Fm6f29os4wP16vCS4lHNh%2Ficon%2FeZDp8sEXSQQTJfGGITkj%2Fxahau-icon-yellow.png?alt=media&amp;token=b911e9ea-ee58-409c-939c-c28c293c9adb" type="image/png" media="(prefers-color-scheme: dark)">
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/2.9.4/Chart.min.js"></script>
</head>

<style>
body {
    background-color: #121212;
    color: #ffffff;
    font-family: Arial, sans-serif;
    padding: 20px;
    margin: 2;
    text-align: center;
}

h1 {
    color: white; 
    font-size: 30px;
    margin-bottom: 10px;
    text-shadow: 2px 2px 4px rgba(0, 0, 0, 0.42);
}

.tab-buttons {
    display: flex;
    justify-content: center;
    margin-bottom: 5px;
}

.tab-buttons button {
    padding: 10px 20px;
    cursor: pointer;
    border: 1px solid #ffffff;
    border-radius: 5px;
    margin: 0 5px;
    font-size: 26px;
    color: #ffffff;
    background-color: #221902;
}

.tab-buttons button.active {
    background-color: #f0c040;
    color: #000;
}

.tab {
    display: none;
    height: 100%;
    width: 100%;
}

.tab.active {
    display: block;
    height: 100%;
    width: 100%;
}

#content {
    height: 100%;
    display: flex;
    flex-direction: column;
    align-items: center;
}

.tab-content {
    height: 100%;
    width: 100%;
}

iframe {
    width: 100%;
    height: 600px;
    border: none;
    border-radius: 10px;
    background-color: #1a1a1a;
}

.serverinfo {
    color: #555;
    max-width: 400px;
    margin: 0 auto;
    margin-bottom: 20px;
    padding: 20px;
    border: 2px solid #ffffff;
    border-radius: 10px;
    text-align: left;
}

.serverinfo span {
    color: white; 
}

#rawoutput {
    background-color: #1a1a1a;
    padding: 20px;
    border-radius: 10px;
    margin-top: 10px;
    margin: 0 auto;
    max-width: 600px;
    color: #ffffff;
    font-family: Arial, sans-serif;
    font-size: 14px;
    white-space: pre-wrap;
    overflow: auto;
    text-align: left;
}

footer {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-top: 20px;
    padding: 10px 20px;
    background-color: #1a1a1a;
    color: #ffffff;
}

footer a {
    color: #ffffff;
    text-decoration: none;
    font-weight: bold;
}

footer a:hover {
    color: #f0c040;
}

.footer-icon {
    width: 20px;
    height: 20px;
    vertical-align: middle;
    margin-right: 5px;
}
</style>

<body>
<div id="content">
    <h1>Xahau Node Landing Page</h1>
    <div class="tab-buttons" id="tab-buttons">
        <button class="tab-button active" onclick="openTab('tab1')">Server Info</button>
        <button class="tab-button" id="tab2-button" onclick="openTab('tab2')">Uptime Kuma</button>
    </div>
    <div id="tab1" class="tab active">
        <div class="serverinfo">
            <p>Status: <span id="status">loading server data..</span></p>
            <p>Server State: <span id="serverstate">loading server data..</span></p>
            <p>full transitions: <span id="statecount">no full count yet..</span></p>
            <p>Build Version: <span id="buildVersion">...</span></p>
            <p>Connected Websockets: <span id="connections">loading toml..</span></p>
            <p>Connected peers: <span id="peers">...</span></p>
            <p>Current Ledger: <span id="currentLedger">...</span></p>
            <p>Complete Ledgers: <span id="completeLedgers">...</span></p>
            <p>Node Size: <span id="nodeSize">...</span></p>
            <p>UpTime: <span id="uptime">...</span></p>
            <p>Last Refresh: <span id="time">...</span></p>
            <canvas id="myChart">...</canvas>
        </div>
    
        <pre id="rawoutput"><h1>Raw .toml file</h1><span id="rawTOML"></span></pre>
    
        <pre id="rawoutput"><h1>xahaud server_info</h1><span id="serverInfo"></span></pre>
    </div>
    <div id="tab2" class="tab">
        <iframe id="tab2-iframe" src="https://$USER_DOMAIN/uptime/status/evernode/" frameborder="0" allowtransparency="yes"></iframe>
    </div>
</div>

<footer>
    <div>
        <a href="https://github.com/gadget78/xahl-node" target="_blank">
            <img src="https://github.com/fluidicon.png" alt="GitHub" class="footer-icon">
            install script by gadget78, fork it on GitHub.
        </a>
    </div>
    <div>Version: <span id="version"></span></div>
</footer>

<script>
    let percentageCPU;
    let percentageRAM;
    let percentageHDD;
    let timeLabels;
    let fullCount;
    let wssConnects;
    const version = "$version";
    document.getElementById('version').textContent = version;
    
    document.addEventListener('DOMContentLoaded', function() {
            var iframe = document.getElementById('tab2-iframe');

            iframe.onload = function() {
                var iframeDocument = iframe.contentDocument || iframe.contentWindow.document;

                // Check if the body contains the text '502' or any custom message set by the server for 502 errors
                if ((iframeDocument.body && iframeDocument.body.innerText.includes('502')) || 
    (iframeDocument.body && iframeDocument.body.innerText.includes('refuse'))) {
                    console.error('502 Error detected');
                    document.getElementById('tab-buttons').style.display = 'none';
                    document.getElementById('tab2-iframe').style.display = 'none';
                } else {
                    document.getElementById('tab-buttons').style.display = 'flex';
                }
            };

            // Handle generic errors, if any (for network issues or the iframe src not reachable)
            iframe.onerror = function() {
                console.error('Error loading iframe content');
                document.getElementById('tab-buttons').style.display = 'none';
                document.getElementById('tab2-iframe').style.display = 'none';
            };
        });

    function openTab(tabId) {
        var tabs = document.getElementsByClassName('tab');
        for (var i = 0; i < tabs.length; i++) {
            tabs[i].classList.remove('active');
        }
        document.getElementById(tabId).classList.add('active');

        var buttons = document.getElementsByClassName('tab-button');
        for (var i = 0; i < buttons.length; i++) {
            buttons[i].classList.remove('active');
        }
        document.querySelector(`[onclick="openTab('\${tabId}')"]`).classList.add('active');
    }

    async function parseValue(value) {
        if (value.startsWith('"') && value.endsWith('"')) {
        return value.slice(1, -1);
        }
        if (value === "true" || value === "false") {
        return value === "true";
        }
        if (!isNaN(value)) {
        return parseFloat(value);
        }
        return value;
    }

    async function parseTOML(tomlString) {
        const json = {};
        let currentSection = json;
        tomlString.split("\n").forEach((line) => {
        line = line.split("#")[0].trim();
        if (!line) return;

        if (line.startsWith("[")) {
            const section = line.replace(/[\[\]]/g, "");
            json[section] = {};
            currentSection = json[section];
        } else {
            const [key, value] = line.split("=").map((s) => s.trim());
            currentSection[key] = parseValue(value);
        }
        });
        return json;
    }
    
    async function fetchTOML() {
        try {
            const response = await fetch('.well-known/xahau.toml');
            const toml = await response.text();
            const parsedTOML = await parseTOML(toml);
            document.getElementById('rawTOML').textContent = toml;
            document.getElementById('connections').textContent = await parsedTOML.STATUS.CONNECTIONS;
            document.getElementById('nodeSize').textContent = await parsedTOML.STATUS.NODESIZE;
            percentageCPU = await parsedTOML.STATUS.CPU;
            percentageCPU = percentageCPU.replace("[", "").replace("]", "").split(",");
            percentageRAM = await parsedTOML.STATUS.RAM;
            percentageRAM = percentageRAM.replace("[", "").replace("]", "").split(",");
            percentageHDD = await parsedTOML.STATUS.HDD;
            percentageHDD = percentageHDD.replace("[", "").replace("]", "").split(",");
            percentageHDD_IO = await parsedTOML.STATUS.HDD_IO;
            percentageHDD_IO = percentageHDD_IO.replace("[", "").replace("]", "").split(",");
            fullCount = await parsedTOML.STATUS.STATUS_COUNT;
            fullCount = fullCount.replace("[", "").replace("]", "").split(",");
            wssConnects = await parsedTOML.STATUS.WSS_CONNECTS;
            wssConnects = wssConnects.replace("[", "").replace("]", "").split(",");
            timeLabels = await parsedTOML.STATUS.TIME;
            timeLabels = timeLabels.replace("[", "").replace("]", "").split(",");
        } catch (error) {
            console.error('Error:', error);
        }
    }

    async function fetchSERVERINFO() {
        const dataToSend = {"method":"server_info"};
        await fetch('/', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(dataToSend)
        })
        .then(response => {
            return response.json();
        })
        .then(serverInfo => {
            const formattedJson = JSON.stringify(serverInfo, null, 2);
            document.getElementById('serverInfo').textContent = formattedJson;
            document.getElementById('status').textContent = serverInfo.result.status || "failed, server could be down?";
            document.getElementById('serverstate').textContent = serverInfo.result.info.server_state;
            document.getElementById('statecount').textContent = serverInfo.result.info.state_accounting.full.transitions;
            document.getElementById('buildVersion').textContent = serverInfo.result.info.build_version;
            document.getElementById('currentLedger').textContent = serverInfo.result.info.validated_ledger.seq || "not known yet";
            document.getElementById('completeLedgers').textContent = serverInfo.result.info.complete_ledgers || "0";
            document.getElementById('peers').textContent = serverInfo.result.info.peers || "0";
            const uptimeInSeconds = serverInfo.result.info.uptime;
            const days = Math.floor(uptimeInSeconds / 86400);
            const hours = Math.floor((uptimeInSeconds % 86400) / 3600);
            const minutes = Math.floor((uptimeInSeconds % 3600) / 60);
            const formattedUptime = \`\${days} Days, \${hours.toString().padStart(2, '0')} Hours, and \${minutes.toString().padStart(2, '0')} Mins\`;
            document.getElementById('uptime').textContent = formattedUptime;
            document.getElementById('time').textContent = serverInfo.result.info.time;
        })
        .catch(error => {
            console.error('Error fetching server info:', error);
            document.getElementById('status').textContent = "failed, server could be down";
            document.getElementById('status').style.color = "red";
        });
    }

    async function renderChart() {
        await fetchTOML();
        fetchSERVERINFO();

        const ctx = document.getElementById('myChart').getContext('2d');
        const myChart = new Chart(ctx, {
            type: 'line',
            data: {
                labels: timeLabels,
                datasets: [{
                    label: 'CPU(%)',
                    data: percentageCPU,
                    borderColor: 'rgba(255, 99, 132, 1)',
                    borderWidth: 1,
                    fill: false
                },
                {
                    label: 'HDD(%)',
                    data: percentageHDD,
                    borderColor: 'rgba(75, 192, 192, 1)',
                    borderWidth: 1,
                    fill: false
                },
                {
                    label: 'HDD IO(%)',
                    data: percentageHDD_IO,
                    borderColor: 'rgba(20, 106, 106, 1)',
                    borderWidth: 1,
                    fill: false
                },
                {
                    label: 'RAM(%)',
                    data: percentageRAM,
                    borderColor: 'rgba(54, 162, 235, 1)',
                    borderWidth: 1,
                    fill: false
                },
                {
                    label: 'Full Count',
                    data: fullCount,
                    borderColor: 'rgba(153, 102, 255, 1)',
                    borderWidth: 1,
                    fill: false
                },
                {
                    label: 'WSS Connects',
                    data: wssConnects,
                    borderColor: 'rgba(255, 159, 64, 1)',
                    borderWidth: 1,
                    fill: false
                }]
            },
            options: {
                responsive: true,
                scales: {
                    x: {
                        display: true,
                        title: {
                            display: true,
                            text: 'Time'
                        }
                    },
                    y: {
                        display: true,
                        title: {
                            display: true,
                            text: 'Percentage/Count'
                        },
                        beginAtZero: true
                    }
                }
            }
        });
    }
    renderChart();
</script>
</body>
</html>
EOF

        sudo mkdir -p /home/www/error
        echo "created /home/www/error directory for blocked page, re-installing webpage"
        if [  -f /home/www/error/custom_403.html ]; then
            sudo rm -r /home/www/error/custom_403.html
        fi        
        sudo cat <<EOF > /home/www/error/custom_403.html
<!DOCTYPE html>
<html lang="en">
<head>
    <title>Xahau Node</title>
    <link rel="icon" href="https://2820133511-files.gitbook.io/~/files/v0/b/gitbook-x-prod.appspot.com/o/spaces%2Fm6f29os4wP16vCS4lHNh%2Ficon%2FeZDp8sEXSQQTJfGGITkj%2Fxahau-icon-yellow.png?alt=media&amp;token=b911e9ea-ee58-409c-939c-c28c293c9adb" type="image/png" media="(prefers-color-scheme: dark)">
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/2.9.4/Chart.min.js"></script>
</head>

<style>
body {
    background-color: #121212;
    color: #ffffff;
    font-family: Arial, sans-serif;
    padding: 20px;
    margin: 2;
    text-align: center;
}

h1 {
    color: white; 
    font-size: 30px;
    margin-bottom: 10px;
    text-shadow: 2px 2px 4px rgba(0, 0, 0, 0.42);
}

.tab-buttons {
    display: flex;
    justify-content: center;
    margin-bottom: 5px;
}

.tab-buttons button {
    padding: 10px 20px;
    cursor: pointer;
    border: 1px solid #ffffff;
    border-radius: 5px;
    margin: 0 5px;
    font-size: 26px;
    color: #ffffff;
    background-color: #221902;
}

.tab-buttons button.active {
    background-color: #f0c040;
    color: #000;
}

.tab {
    display: none;
    height: 100%;
    width: 100%;
}

.tab.active {
    display: block;
    height: 100%;
    width: 100%;
}

#content {
    height: 100%;
    display: flex;
    flex-direction: column;
    align-items: center;
}

.tab-content {
    height: 100%;
    width: 100%;
}

iframe {
    width: 100%;
    height: 600px;
    border: none;
    border-radius: 10px;
    background-color: #1a1a1a;
}

.serverinfo {
    color: #555;
    max-width: 400px;
    margin: 0 auto;
    margin-bottom: 20px;
    padding: 20px;
    border: 2px solid #ffffff;
    border-radius: 10px;
    text-align: left;
}

.serverinfo span {
    color: white; 
}

#rawoutput {
    background-color: #1a1a1a;
    padding: 20px;
    border-radius: 10px;
    margin-top: 10px;
    margin: 0 auto;
    max-width: 600px;
    color: #ffffff;
    font-family: Arial, sans-serif;
    font-size: 14px;
    white-space: pre-wrap;
    overflow: auto;
    text-align: left;
}

footer {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-top: 20px;
    padding: 10px 20px;
    background-color: #1a1a1a;
    color: #ffffff;
}

footer a {
    color: #ffffff;
    text-decoration: none;
    font-weight: bold;
}

footer a:hover {
    color: #f0c040;
}

.footer-icon {
    width: 20px;
    height: 20px;
    vertical-align: middle;
    margin-right: 5px;
}
</style>

<body>
    <div id="content">
        <h1>Xahau Node Landing Page</h1>
        <div class="tab-buttons" id="tab-buttons">
            <button class="tab-button active" onclick="openTab('tab1')">Server Info</button>
            <button class="tab-button" id="tab2-button" onclick="openTab('tab2')">Uptime Kuma</button>
        </div>
        <div id="tab1" class="tab active">
            <div class="serverinfo">
                <h1>Server Info</h1>
                <p><span style="color: orange;">your IP has restricted access</span></p>
                <p>YourIP: <span id="realip"></p>
                <p>X-Real-IP: <span id="xrealip"></p>
                <p>Contact Email:</p>
                <p></p>
            
                <p>Status: <span id="status">loading toml file..</span></p>
                <p>full transitions: <span id="statecount">...</span></p>
                <p>Build Version: <span id="buildVersion">...</span></p>
                <p>Connections: <span id="connections">...</span></p>
                <p>Connected Peers: <span id="peers">...</span></p>
                <p>Current Ledger: <span id="currentLedger">...</span></p>
                <p>Complete Ledgers: <span id="completedLedgers">...</span></p>
                <p>Node Size: <span id="nodeSize">...</span></p>
                <p>UpTime: <span id="uptime">...</span></p>
                <p>Last Refresh: <span id="time">...</span></p>
                <canvas id="myChart">...</canvas>
            </div>
        
            <pre id="rawoutput"><h1>raw .toml file</h1><span id="rawTOML">loading .toml file...</spam></pre>
        </div>
        <div id="tab2" class="tab">
            <iframe id="tab2-iframe" src="https://$USER_DOMAIN/uptime/status/evernode/" frameborder="0" allowtransparency="yes"></iframe>
        </div>
    </div>

<footer>
    <div>
        <a href="https://github.com/gadget78/xahl-node" target="_blank">
            <img src="https://github.com/fluidicon.png" alt="GitHub" class="footer-icon">
            install script by gadget78, fork it on GitHub.
        </a>
    </div>
    <div>Version: <span id="version"></span></div>
</footer>

<script>
    let percentageCPU;
    let percentageRAM;
    let percentageHDD;
    let timeLabels;
    let fullCount;
    let wssConnects;
    const version = "$version";
    document.getElementById('version').textContent = version;

    document.addEventListener('DOMContentLoaded', function() {
            var iframe = document.getElementById('tab2-iframe');

            iframe.onload = function() {
                var iframeDocument = iframe.contentDocument || iframe.contentWindow.document;

                // Check if the body contains the text '502' or any custom message set by the server for 502 errors
                if ((iframeDocument.body && iframeDocument.body.innerText.includes('502')) || 
    (iframeDocument.body && iframeDocument.body.innerText.includes('refuse'))) {
                    console.error('502 Error detected');
                    document.getElementById('tab-buttons').style.display = 'none';
                    document.getElementById('tab2-iframe').style.display = 'none';
                } else {
                    document.getElementById('tab-buttons').style.display = 'flex';
                }
            };

            // Handle generic errors, if any (for network issues or the iframe src not reachable)
            iframe.onerror = function() {
                console.error('Error loading iframe content');
                document.getElementById('tab-buttons').style.display = 'none';
                document.getElementById('tab2-iframe').style.display = 'none';
            };
        });

    function openTab(tabId) {
        var tabs = document.getElementsByClassName('tab');
        for (var i = 0; i < tabs.length; i++) {
            tabs[i].classList.remove('active');
        }
        document.getElementById(tabId).classList.add('active');

        var buttons = document.getElementsByClassName('tab-button');
        for (var i = 0; i < buttons.length; i++) {
            buttons[i].classList.remove('active');
        }
        document.querySelector(`[onclick="openTab('\${tabId}')"]`).classList.add('active');
    }

    async function parseValue(value) {
        if (value.startsWith('"') && value.endsWith('"')) {
        return value.slice(1, -1);
        }
        if (value === "true" || value === "false") {
        return value === "true";
        }
        if (!isNaN(value)) {
        return parseFloat(value);
        }
        return value;
    }

    async function parseTOML(tomlString) {
        const json = {};
        let currentSection = json;
        tomlString.split("\n").forEach((line) => {
        line = line.split("#")[0].trim();
        if (!line) return;

        if (line.startsWith("[")) {
            const section = line.replace(/[\[\]]/g, "");
            json[section] = {};
            currentSection = json[section];
        } else {
            const [key, value] = line.split("=").map((s) => s.trim());
            currentSection[key] = parseValue(value);
        }
        });
        return json;
    }
    
    async function fetchTOML() {
        try {
            const response = await fetch('.well-known/xahau.toml');
            const toml = await response.text();
            parsedTOML = await parseTOML(toml);
            document.getElementById('xrealip').textContent = response.headers.get('X-Real-IP');
            document.getElementById('rawTOML').textContent = toml;
        } catch (error) {
            document.getElementById('status').textContent = "Unable to retrieve .toml file";
            console.error('Error Retriving .toml file:', error);
        }
        try {
            // 1st check if the difference in hours is less than or equal to 12
            let refreshDate = new Date((await parsedTOML.STATUS.LASTREFRESH).toString().replace(" UTC", ""));
            let now = new Date();
            let timeDifference = now - refreshDate; // milliseconds
            let days = Math.floor(timeDifference / (1000 * 60 * 60 * 24)); // Convert milliseconds to days
            let hours = Math.floor(timeDifference / (1000 * 60 * 60));
            let mins = Math.floor(timeDifference / (1000 * 60));

            if (hours <= 12) {
                document.getElementById('status').textContent = await parsedTOML.STATUS.STATUS;
                document.getElementById('statecount').textContent = await parsedTOML.STATUS.FULLCOUNT;
                document.getElementById('buildVersion').textContent = await parsedTOML.STATUS.BUILDVERSION;
                document.getElementById('connections').textContent = await parsedTOML.STATUS.CONNECTIONS;
                document.getElementById('peers').textContent = await parsedTOML.STATUS.PEERS;
                document.getElementById('currentLedger').textContent = await parsedTOML.STATUS.CURRENTLEDGER;
                document.getElementById('completedLedgers').textContent = await parsedTOML.STATUS.LEDGERS;
                document.getElementById('nodeSize').textContent = await parsedTOML.STATUS.NODESIZE;
                document.getElementById('uptime').textContent = await parsedTOML.STATUS.UPTIME;
                document.getElementById('time').textContent = days+"days "+hours+"hours and "+mins+"mins ago";

                percentageCPU = await parsedTOML.STATUS.CPU;
                percentageCPU = percentageCPU.replace("[", "").replace("]", "").split(",");
                percentageRAM = await parsedTOML.STATUS.RAM;
                percentageRAM = percentageRAM.replace("[", "").replace("]", "").split(",");
                percentageHDD = await parsedTOML.STATUS.HDD;
                percentageHDD = percentageHDD.replace("[", "").replace("]", "").split(",");
                percentageHDD_IO = await parsedTOML.STATUS.HDD_IO;
                percentageHDD_IO = percentageHDD_IO.replace("[", "").replace("]", "").split(",");
                fullCount = await parsedTOML.STATUS.STATUS_COUNT;
                fullCount = fullCount.replace("[", "").replace("]", "").split(",");
                wssConnects = await parsedTOML.STATUS.WSS_CONNECTS;
                wssConnects = wssConnects.replace("[", "").replace("]", "").split(",");
                timeLabels = await parsedTOML.STATUS.TIME;
                timeLabels = timeLabels.replace("[", "").replace("]", "").split(",");
            }else {
                document.getElementById('status').textContent = "data "+days+"days "+hours+"hours old";
            }
        } catch (error) {
            document.getElementById('status').textContent = "no status data in .toml file";
            console.error('Unable to process .toml file', error);
        }
    }

    async function renderChart() {
        await fetchTOML();

        const ctx = document.getElementById('myChart').getContext('2d');
        const myChart = new Chart(ctx, {
            type: 'line',
            data: {
                labels: timeLabels,
                datasets: [{
                    label: 'CPU(%)',
                    data: percentageCPU,
                    borderColor: 'rgba(255, 99, 132, 1)',
                    borderWidth: 1,
                    fill: false
                },
                {
                    label: 'HDD(%)',
                    data: percentageHDD,
                    borderColor: 'rgba(75, 192, 192, 1)',
                    borderWidth: 1,
                    fill: false
                },
                {
                    label: 'HDD IO(%)',
                    data: percentageHDD_IO,
                    borderColor: 'rgba(20, 106, 106, 1)',
                    borderWidth: 1,
                    fill: false
                },
                {
                    label: 'RAM(%)',
                    data: percentageRAM,
                    borderColor: 'rgba(54, 162, 235, 1)',
                    borderWidth: 1,
                    fill: false
                },
                {
                    label: 'Full Count',
                    data: fullCount,
                    borderColor: 'rgba(153, 102, 255, 1)',
                    borderWidth: 1,
                    fill: false
                },
                {
                    label: 'WSS Connects',
                    data: wssConnects,
                    borderColor: 'rgba(255, 159, 64, 1)',
                    borderWidth: 1,
                    fill: false
                }]
            },
            options: {
                responsive: true,
                scales: {
                    x: {
                        display: true,
                        title: {
                            display: true,
                            text: 'Time'
                        }
                    },
                    y: {
                        display: true,
                        title: {
                            display: true,
                            text: 'Percentage/Count'
                        },
                        beginAtZero: true
                    }
                }
            }
        });
    }
    renderChart();

    fetch('https://ipinfo.io/ip')
    .then(response => response.text())
    .then(ipinfo => {
        document.getElementById('realip').textContent = ipinfo;
    })
    .catch(error => {
        console.error('Error fetching client IP:', error);
        document.getElementById('realip').textContent = "unknown";
    });

</script>
</body>
</html>
EOF
    echo
    echo -e "${GREEN}## ${YELLOW}Setup: (re)downlaoding the .toml updater, and setting permissions ${NC}"
    sudo rm -f /root/xahl-node/updater.py
    sudo wget -O /root/xahl-node/updater.py $TOMLUPDATER_URL
    sudo chmod +x /root/xahl-node/updater.py
    cron_job="*/15 * * * * /usr/bin/python3 /root/xahl-node/updater.py"
    echo
    if sudo crontab -l | grep -Fxq "$cron_job"; then
        echo -e "${GREEN}## ${YELLOW}Setup: Cron job for .toml updater already exists. No changes made. ${NC}"
    else
        echo "$cron_job" | sudo crontab -
        echo -e "${GREEN}## ${YELLOW}Setup: Cron job for .toml updater added successfully."
    fi

    else
        echo -e "${GREEN}## ${YELLOW}Setup: Skipped re-installing Landng webpage install, due to vars file config... ${NC}"
        echo
        echo
    fi

    if [ -z "$INSTALL_TOML" ]; then
        read -p "Do you want to (re)install the default xahau.toml file?: true or false # " INSTALL_TOML
        sudo sed -i "s/^INSTALL_TOML=.*/INSTALL_TOML=\"$INSTALL_TOML\"/" $SCRIPT_DIR/xahl_node.vars
    fi
    if [ "$INSTALL_TOML" == "true" ]; then
        
        # Prompt for user email if not provided as a variable
        if [ -z "$TOML_EMAIL" ] || [ "$ALWAYS_ASK" == "true" ]; then
            echo
            printf "${BLUE}Enter your email address for the PUBLIC .toml file ${NC}# "
            read -e -i "$TOML_EMAIL" TOML_EMAIL
            sudo sed -i "s/^TOML_EMAIL=.*/TOML_EMAIL=\"$TOML_EMAIL\"/" $SCRIPT_DIR/.env
            if sudo grep -q 'TOML_EMAIL=' "$SCRIPT_DIR/.env"; then
                sudo sed -i "s/^TOML_EMAIL=.*/TOML_EMAIL=\"$TOML_EMAIL\"/" "$SCRIPT_DIR/.env"
            else
                sudo echo -e "TOML_EMAIL=\"$TOML_EMAIL\"" >> $SCRIPT_DIR/.env
            fi
            echo
        fi




        sudo mkdir -p /home/www/.well-known
        echo "created /home/www.well-known directory for .toml file, and re-creating default .toml file"
        sudo rm -f /home/www/.well-known/xahau.toml
        sudo cat <<EOF > /home/www/.well-known/xahau.toml
[[METADATA]]
created = $FDATE
modified = $FDATE

[[PRINCIPALS]]
name = "evernode"
email = "$TOML_EMAIL"
discord = ""

[[ORGANIZATION]]
website = "https://$USER_DOMAIN"

[[SERVERS]]
domain = "https://$USER_DOMAIN"
install = "created by g140point6 & gadget78 Node Script"

[[STATUS]]
NETWORK = "$VARVAL_CHAIN_NAME"
NODESIZE = "$XAHAU_NODE_SIZE"

[[AMENDMENTS]]

# End of file
EOF

    else
        echo -e "${GREEN}## ${YELLOW}Setup: Skipped re-installing default xahau.toml file, due to vars file config... ${NC}"
        echo
        echo
    fi
    echo
    sleep 2s
}


FUNC_ALLOWLIST_CHECK(){
    echo
    echo -e "${GREEN}#########################################################################${NC}"
    echo
    echo -e "${GREEN}## ${YELLOW}Setup: checking/setting up IPs in ${BYELLOW}'$SCRIPT_DIR/$NGINX_ALLOWLIST_FILE'${NC} file...${NC}"
    echo

    # Get some source IPs
    #current SSH session
    SRC_IP=$(echo $SSH_CONNECTION | awk '{print $1}')
    if [ -z "$SRC_IP" ]; then
        SRC_IP="127.0.0.1"
    fi
    #this Nodes IP
    NODE_IP=$(curl -s ipinfo.io/ip)
    if [ -z "$NODE_IP" ]; then
        NODE_IP="127.0.0.1"
    fi
    #dockers IP
    #DCKR_HOST_IP=$(sudo docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $VARVAL_CHAIN_NAME_xinfinnetwork_1)
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    if [ -z "$LOCAL_IP" ]; then
        LOCAL_IP="127.0.0.1"
    fi

    echo "adding default IPs..."
    echo
    if ! grep -q "allow $SRC_IP;  # Detected IP of the SSH session" "$SCRIPT_DIR/nginx_allowlist.conf"; then
        echo "allow $SRC_IP;  # Detected IP of the SSH session" >> $SCRIPT_DIR/nginx_allowlist.conf
        echo "added IP $SRC_IP;  # Detected IP of the SSH session"
    else
        echo "SSH session IP, $SRC_IP, already in list."
    fi
    if ! grep -q "allow $LOCAL_IP; # Local IP of server" "$SCRIPT_DIR/nginx_allowlist.conf"; then
        echo "allow $LOCAL_IP; # Local IP of server" >> $SCRIPT_DIR/nginx_allowlist.conf
        echo "added IP $LOCAL_IP; # Local IP of the server"
    else
        echo "Local IP of the server, $LOCAL_IP, already in list."
    fi
    if ! grep -q "allow $NODE_IP;  # ExternalIP of the Node itself" "$SCRIPT_DIR/nginx_allowlist.conf"; then
        echo "allow $NODE_IP;  # ExternalIP of the Node itself" >> $SCRIPT_DIR/nginx_allowlist.conf
        echo "added IP $NODE_IP;  # ExternalIP of the Node itself"
    else
        echo "External IP of the Node itself, $NODE_IP, already in list."
    fi
    echo
    echo
    if [ "$ALWAYS_ASK" == "true" ]; then
        echo -e "${BLUE}here we add additional IPs to the Allowlist... ${NC}"
        echo
        while true; do
            printf "${BLUE}Enter an additional IP address (one at a time for example 10.0.0.20, or just press enter to skip) ${NC}# " 
            read -e user_ip

            # Validate the input using regex
            # IPv4 regex
            ipv4_regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'

            # IPv6 regex
            ipv6_regex='^(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))$'

            # Check if the input matches either the IPv4 or IPv6 pattern
            if [[ $user_ip =~ $ipv4_regex ]] || [[ $user_ip =~ $ipv6_regex ]]; then
                echo -e "${GREEN}IP address: ${YELLOW}$user_ip added to Allow list. ${NC}"
                echo -e "allow $user_ip;" >> $SCRIPT_DIR/nginx_allowlist.conf
            else
                if [ -z "$user_ip" ]; then
                    break
                else
                    echo -e "${RED}Invalid IP address. Please try again. ${NC}"
                fi
            fi
        done
    fi
    echo
    sleep 2s
}


FUNC_NGINX_CLEAR_RECREATE() {
        echo
    echo -e "${GREEN}#########################################################################${NC}"
    echo
    echo -e "${GREEN}## ${YELLOW}Checking and installing NGINX... ${NC}"
    nginx -v 
    if [ $? != 0 ]; then
        echo -e "${GREEN}## ${YELLOW}NGINX is not installed. Installing now...${NC}"
        apt update -y
        sudo apt install nginx -y
    else
        # If NGINX is already installed.. skipping
        echo -e "${GREEN}## NGINX is already installed... ${NC}"
    fi
    
    # delete default and old files, along with symbolic link file if it exists
    echo "clearing old default config files..."
    if [  -f $NGX_CONF_ENABLED/default ]; then
        sudo rm -f $NGX_CONF_ENABLED/default
    fi
    if [  -f $NGX_CONF_NEW/default ]; then
        sudo rm -f $NGX_CONF_NEW/default
    fi
    if [  -f $NGX_CONF_ENABLED/xahau ]; then
        sudo rm -f $NGX_CONF_ENABLED/xahau
    fi 
    if [  -f $NGX_CONF_NEW/xahau ]; then
        sudo rm -f $NGX_CONF_NEW/xahau
    fi

    # re-create new nginx configuration file with the user-provided domain....
    echo
    echo -e "${GREEN}#########################################################################${NC}"
    echo
    echo -e "${GREEN}## ${YELLOW}Setup: Installing new Nginx configuration files ...${NC}"
    echo 

    sudo touch $NGX_CONF_NEW/xahau
    sudo chmod 666 $NGX_CONF_NEW/xahau
    
    if [ "$INSTALL_CERTBOT_SSL" == "true" ] && [ -f /etc/letsencrypt/live/$USER_DOMAIN/privkey.pem ]; then
    echo -e "${GREEN}## ${YELLOW}Setup: previous SSL files found, installing SSL type .conf file... ${NC}"
        sudo cat <<EOF > $NGX_CONF_NEW/xahau
set_real_ip_from $NGINX_PROXY_IP;
real_ip_header X-Real-IP;
real_ip_recursive on;
server {
    server_name $USER_DOMAIN;

    # Additional settings, including HSTS
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Real-IP \$remote_addr;
    add_header Host \$host;

    # Enable XSS protection
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-XSS-Protection "1; mode=block";

    error_page 403 /custom_403.html;
    location /custom_403.html {
        root /home/www/error;
        internal;
    }
    
    location / {
        try_files \$uri \$uri/ =404;
        include $SCRIPT_DIR/$NGINX_ALLOWLIST_FILE;
        deny all;

        # These three are critical to getting websockets to work
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache off;
        proxy_buffering off;
        tcp_nopush  on;
        tcp_nodelay on;
        if (\$http_upgrade = "websocket") {
                proxy_pass  http://localhost:$VARVAL_CHAIN_WSS;
        }

        if (\$request_method = POST) {
                proxy_pass http://localhost:$VARVAL_CHAIN_RPC;
        }

        root /home/www;
    }

    location /.well-known/xahau.toml {
        allow all;
        try_files \$uri \$uri/ =403;
        root /home/www;
    }

    location /uptime {
        proxy_pass http://localhost:3001;

        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # define url prefix
        set \$url_prefix uptime;

        # remove url prefix to pass to backend
        rewrite ^/uptime/?(.*)$ /\$1 break;

        # redirect location headers
        proxy_redirect ^ /\$url_prefix;
        proxy_redirect /dashboard /\$url_prefix/dashboard;

        # sub filters to replace hardcoded paths
        proxy_set_header Accept-Encoding "";
        sub_filter_last_modified on;
        sub_filter_once off;
        sub_filter_types *;
        sub_filter '"/status/' '"/\$url_prefix/status/';
        sub_filter '/upload/' '/\$url_prefix/upload/';
        sub_filter '/api/' '/\$url_prefix/api/';
        sub_filter '/assets/' '/\$url_prefix/assets/';
        sub_filter '"assets/' '"\$url_prefix/assets/';
        sub_filter '/socket.io' '/\$url_prefix/socket.io';
        sub_filter '/icon.svg' '/\$url_prefix/icon.svg';
        sub_filter '/favicon.ico' '/\$url_prefix/favicon.ico';
        sub_filter '/apple-touch-icon.png' '/\$url_prefix/apple-touch-icon.png';
        sub_filter '/manifest.json' '/\$url_prefix/manifest.json';
        sub_filter '/add' '/\$url_prefix/add';
        sub_filter '/settings/' '/\$url_prefix/settings/';
        sub_filter '"/settings' '"/\$url_prefix/settings';
        sub_filter '/dashboard' '/\$url_prefix/dashboard';
        sub_filter '/maintenance' '/\$url_prefix/maintenance';
        sub_filter '/add-status-page' '/\$url_prefix/add-status-page';
        sub_filter '/manage-status-page' '/\$url_prefix/manage-status-page';
    }

    listen 443 ssl; # managed by Certbot
    listen [::]:443 ssl; # managed by Certbot
    ssl_certificate /etc/letsencrypt/live/$USER_DOMAIN/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/$USER_DOMAIN/privkey.pem; # managed by Certbot
    include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot
}

server {
    listen 80;
    listen [::]:80;
    if (\$host = $USER_DOMAIN) {
        return 301 https://\$host\$request_uri;
    } # managed by Certbot

    server_name $USER_DOMAIN;
    return https://\$host;

}
EOF

    else
    echo -e "${GREEN}## ${YELLOW}Setup: installing non-SSL type .conf file... ${NC}"
    sudo cat <<EOF > $NGX_CONF_NEW/xahau
set_real_ip_from $NGINX_PROXY_IP;
real_ip_header X-Real-IP;
real_ip_recursive on;
server {
    listen 80;
    listen [::]:80;
    server_name $USER_DOMAIN;

    # Additional settings, including HSTS
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Real-IP \$remote_addr;
    add_header Host \$host;

    # Enable XSS protection
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-XSS-Protection "1; mode=block";

    error_page 403 /custom_403.html;
    location /custom_403.html {
        root /home/www/error;
        internal;
    }
    
    location / {
        try_files \$uri \$uri/ =404;
        include $SCRIPT_DIR/$NGINX_ALLOWLIST_FILE;
        deny all;

        # These three are critical to getting websockets to work
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache off;
        proxy_buffering off;
        tcp_nopush  on;
        tcp_nodelay on;
        if (\$http_upgrade = "websocket") {
                proxy_pass  http://localhost:$VARVAL_CHAIN_WSS;
        }

        if (\$request_method = POST) {
                proxy_pass http://localhost:$VARVAL_CHAIN_RPC;
        }

        root /home/www;
    }

    location /.well-known/xahau.toml {
        allow all;
        try_files \$uri \$uri/ =403;
        root /home/www;
    }

    location /uptime {
        proxy_pass http://localhost:3001;

        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # define url prefix
        set \$url_prefix uptime;

        # remove url prefix to pass to backend
        rewrite ^/uptime/?(.*)$ /\$1 break;

        # redirect location headers
        proxy_redirect ^ /\$url_prefix;
        proxy_redirect /dashboard /\$url_prefix/dashboard;

        # sub filters to replace hardcoded paths
        proxy_set_header Accept-Encoding "";
        sub_filter_last_modified on;
        sub_filter_once off;
        sub_filter_types *;
        sub_filter '"/status/' '"/\$url_prefix/status/';
        sub_filter '/upload/' '/\$url_prefix/upload/';
        sub_filter '/api/' '/\$url_prefix/api/';
        sub_filter '/assets/' '/\$url_prefix/assets/';
        sub_filter '"assets/' '"\$url_prefix/assets/';
        sub_filter '/socket.io' '/\$url_prefix/socket.io';
        sub_filter '/icon.svg' '/\$url_prefix/icon.svg';
        sub_filter '/favicon.ico' '/\$url_prefix/favicon.ico';
        sub_filter '/apple-touch-icon.png' '/\$url_prefix/apple-touch-icon.png';
        sub_filter '/manifest.json' '/\$url_prefix/manifest.json';
        sub_filter '/add' '/\$url_prefix/add';
        sub_filter '/settings/' '/\$url_prefix/settings/';
        sub_filter '"/settings' '"/\$url_prefix/settings';
        sub_filter '/dashboard' '/\$url_prefix/dashboard';
        sub_filter '/maintenance' '/\$url_prefix/maintenance';
        sub_filter '/add-status-page' '/\$url_prefix/add-status-page';
        sub_filter '/manage-status-page' '/\$url_prefix/manage-status-page';
    }

}
EOF
    sudo chmod 644 $NGX_CONF_NEW
    fi

    # check if symbolic link file exists in sites-enabled (it shouldn't), if not create it
    if [ ! -f $NGX_CONF_ENABLED/xahau ]; then
        sudo ln -s $NGX_CONF_NEW/xahau $NGX_CONF_ENABLED/xahau
    fi
}


FUNC_LOGROTATE(){
    # add the logrotate conf file
    # check logrotate status = cat /var/lib/logrotate/status

    echo -e "${GREEN}#########################################################################${NC}"
    echo
    echo -e "${GREEN}## ${YELLOW}Setup: Configurng LOGROTATE files...${NC}"
    sleep 2s

    # Prompt for Chain if not provided as a variable
    if [ -z "$VARVAL_CHAIN_NAME" ]; then

        while true; do
         read -p "Enter which chain your node is deployed on (e.g. mainnet or testnet): " _input

            case $_input in
                testnet )
                    VARVAL_CHAIN_NAME="testnet"
                    break
                    ;;
                mainnet )
                    VARVAL_CHAIN_NAME="mainnet"
                    break
                    ;;
                * ) echo "Please answer a valid option.";;
            esac
        done

    fi

        cat <<EOF > /tmp/tmpxahau-logs
/opt/xahaud/log/*.log
        {
            su $USER_ID $USER_ID
            size 100M
            rotate 50
            copytruncate
            daily
            missingok
            notifempty
            compress
            delaycompress
            sharedscripts
            postrotate
                    invoke-rc.d rsyslog rotate >/dev/null 2>&1 || true
            endscript
        }    
EOF

    sudo sh -c 'cat /tmp/tmpxahau-logs > /etc/logrotate.d/xahau-logs'

}

#####################################################################################################################################################################################################
#####################################################################################################################################################################################################







FUNC_NODE_DEPLOY(){
    echo
    echo -e "${GREEN}#########################################################################${NC}"
    echo -e "${YELLOW}#########################################################################${NC}"
    echo -e "${GREEN}${NC}"
    echo -e "${GREEN}             Xahau ${BYELLOW}$_OPTION${GREEN} RPC/WSS Node - Install${NC}"
    echo -e "${GREEN}${NC}"
    echo -e "${YELLOW}#########################################################################${NC}"
    echo -e "${GREEN}#########################################################################${NC}"
    sleep 3s

    # check for .vars file, and set other variables
    FUNC_VARS_VARIABLE_CHECK;

    # installs updates, and default packages listed in vars file
    FUNC_PKG_CHECK;

    # detect IPv6
    FUNC_IPV6_CHECK;

    # check setup mode
    FUNC_SETUP_MODE;

    # check/install CERTBOT (for SSL)
    FUNC_CERTBOT_PRECHECK;

    # prompts the user for domain name, and email address for cert_bot if needed 
    FUNC_PROMPTS_4_DOMAINS_EMAILS;

    # setup and install the landing page, request public email if needed, and add CRON job entry
    FUNC_INSTALL_LANDINGPAGE;

    # add/check allowList, ask for additional IPs if configured to do so
    FUNC_ALLOWLIST_CHECK;

    # main Xahau Node setup
    FUNC_CLONE_NODE_SETUP;

    # Check/Install Nginx, clear default/old-config
    FUNC_NGINX_CLEAR_RECREATE;

    # Check and install/setup UFW (Uncomplicated Firewall)
    FUNC_UFW_SETUP;

    # install/setup logrotate to Rotate logs on regular basis
    FUNC_LOGROTATE;

    # request new SSL certificate via certbot, before checking/re-enabling nginx settings
    FUNC_CERTBOT_REQUEST;

    # setup update command
    sudo bash -c "echo 'bash -c \"\$(wget -qLO - https://raw.githubusercontent.com/gadget78/xahl-node/main/setup.sh)\"' >/usr/bin/update"
    sudo chmod +x /usr/bin/update

    echo
    echo -e "${GREEN}#########################################################################${NC}"
    echo
    echo -e "${GREEN}## ${YELLOW}Setup: removed old files, and Created and enabled a new Nginx configuration files${NC}"
    echo
    if  [ -z "$ORIGINAL_USER_ID" ]; then 
      echo -e "${GREEN}## ${YELLOW}Setup: just applying corrective ownership... ${NC}"
      sudo chown -R $ORIGINAL_USER_ID:users $SCRIPT_DIR
    fi
    echo
    echo -e "${GREEN}#########################################################################${NC}"
    echo
    echo -e "${NC}if all went well, your Xahau Node will now be up and running, you can check; ${NC}"
    echo
    echo -e "${NC}locally at, websocket ${BYELLOW}ws://$LOCAL_IP${NC} or RPC/API and website at ${BYELLOW}https://$LOCAL_IP ${NC}"
    echo
    echo -e "${NC}or externally at, websocket ${BYELLOW}wss://$USER_DOMAIN${NC} or RPC/API and website at ${BYELLOW}https://$USER_DOMAIN ${NC}"
    echo
    echo -e "use file ${BYELLOW}'$SCRIPT_DIR/$NGINX_ALLOWLIST_FILE'${NC} to add/remove IP addresses that you want to have access to your submission node${NC}"
    echo -e "once file is edited and saved, run command ${BYELLOW}sudo nginx -s reload${NC} to apply new settings ${NC}"
    echo -e "you can also use this to check the settings if the website is not displaying correctly"
    echo
    echo -e "${NC}you can use command ${YELLOW}xahaud server_info${NC} to get info directly from this server"
    echo
    echo -e "${GREEN}## ${YELLOW}Setup complete.${NC}"
    echo
    echo


    FUNC_EXIT
}


# setup a clean exit
trap SIGINT_EXIT SIGINT
SIGINT_EXIT(){
    stty sane
    echo
    echo "exiting before completing the script."
    exit 1
    }

FUNC_EXIT(){
    # remove the sudo timeout for USER_ID
    sudo sh -c 'rm -f /etc/sudoers.d/xahlnode_deploy'
    bash ~/.profile
    sudo -u $USER_ID sh -c 'bash ~/.profile'
	exit 0
	}


FUNC_EXIT_ERROR(){
	exit 1
	}
  
FUNC_NODE_DEPLOY

FUNC_EXIT
