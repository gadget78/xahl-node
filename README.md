# Xahau RPC/WSS Submission Node 
Xahau submission node installation, utilizing nginx to give webserver and endpoints, with lets encrypt TLS certificate.

---

This script uses the standard Xahau node install non-docker version, [found here](https://github.com/Xahau/mainnet-docker).

and supplements it with the necessary configuration to provide a TLS secured RPC and WSS endpoints using Nginx, with extra features of a landing page for easy checking, and diagnoses, all on the same domain.

# Table of Contents
---

- [Xahau RPC/WSS Submission Node](#xahau-rpcwss-submission-node)
- [Table of Contents](#table-of-contents)
  - [Current functionality](#current-functionality)
  - [How to download & use](#how-to-download--use)
    - [How to UPDATE from older scripts like go140point6](#how-to-update-from-older-scripts-like-go140point6)
    - [OK so HOW do we Install ?](#ok-so-how-do-we-install)
    - [Config files](#config-files)
    - [Nginx related](#nginx-related)
    - [Permitting Access](#node-ip-permissions)
    - [Testing your Xahaud server](#testing-your-xahaud-server)
      - [local xahaud](#local-xahaud)
      - [RPC and API](#rpc-and-api)
      - [Websocket](#websocket)
    - [Future updates](#future-updates)
      - [auto updater](#auto-updater)
    - [Contributors:](#contributors)
    - [Feedback](#feedback)


---
---

## Current functionality
 - Install options for Mainnet (and Testnet)
 - Supports the use of custom variables using the `xahl_node.vars` file, to adjust the setup
 - Saves all data from questions to .env file, so it can be used to check current settings, and also for the prompt if setup is ran again
 - Detects UFW firewall & applies necessary firewall updates.
 - Installs & configures Nginx 
   - sets up nginx so that it splits the incoming traffic to your supplied domain 5 ways
        - 1.static website for allowed IPs
        - 2.static website for blocked IPs 
        - 3.the main node websocket(accesed via the standard wss://)
        - 4.any rpc traffic (when using POST for API use)
        - 5.public access to .toml file
   - TL;DR; you only need ONE (A record) domain pointing to this server (no need to any CNAME setups)
   - Automatically detects the IPs of your ssh session, the node itself, and its local environment then adds them to the nginx_allowlist.conf file
   - checks for updates every 24 hours
   - also now works behind another nginx/NPM front end see [Nginx related](#nginx-related) section
   - IPv6 support (auto detect by default, can be forced via .vars setting)
   - adds a simple `update` to the command line, so you can update easily
   - Applies NIST security best practices
 - additional Dockerfiles and entry point file have now been added to this repo, so you can create your own docker image.
 - or use the prebuilt docker image at [/gadget78/xahau-node:latest](https://hub.docker.com/r/gadget78/xahau-node)
 
---

# How to download & use

there is two main ways to use this script, one to clone the repo and run, and one is to run repo direct with a single commandline,

read over the following sections and when ready simply copy and paste the code snippets to your terminal window.

## How to UPDATE from older scripts like go140point6

### Save your IP allow list

older versions, where the allow list needed 2 blocks, and was saved in `/etc/nginx/sites-available/xahau` are now captured,

and used in the new method, using a separate file nginx_allowlist.conf , althou it is still good practice to backup FIRST.

So this newer version of script, it will capture and save your allow list, it should show you them so you can be 100% that they are added.

it will be after the "capturing any IPs from a previous old type install, ready for the new type" text,

where it should then give you a confirmation of "found allow list from past install, will add these to the allowlist;" and list the found IPs

if these are not detected, or you hav them saved previously, you can add IPs either manually (one at a time) at this point, or afterwards as a pasted in block to the file nginx_allowlist.conf

### only needs a single domain name

so in older versions, you would of needed two to three "(sub)domain names", comprising of 1 A record (using a IP) and 2 CNAMES (using names) 

this build now only needs ONE, 

and that ONE domain can be a root domain, like `youdomain.com`, or a subdomain, like `subdomain.yourdomain.com` or stay with the old type domain `wss.yourdomain.com`

this ONE domain does need to be a "A Record", so thats a domain that points to a specified IP, that IP being the public IP of your Xahau Node.

now if you have LOTS of evernodes that are already using the old sub-domain, you may choose to carry on and use the same domain as before `wss.yourdomain.com`

which you can of course, just make sure that it is an `A Record`, or its pointing to a `A Record` (and not another CNAME)

also, this ONE domain you use, will be the SAME domain you will then use in a browser to check your node, https://yourdomain.com, and the domain for the websocket for use in your evernode, wss://yourdomain.com

# OK so HOW do we Install

simplest method, in a suitable environment, like debian or ubuntu, with at least 2GB of RAM, and 5GB of HDD space

copy, and run this simple command... 

        sudo bash -c "$(wget -qLO - https://raw.githubusercontent.com/gadget78/xahl-node/main/setup.sh)"

(if you want to force a different script install directory, prefix with `SCRIPT_DIR="/new/path/here"` if not default will be "$HOME"/xahl-node)

setup will go through a series of questions (in blue) and output all info along the way

one of the questions in the setup, for example, is to enter IPs that will form a "allow list" which you do one at a time, once finished, submit a blank entry to move on.

when setup is finished asking questions, and outputting progress, it will give a some info on how to check its working with the IP or URls that are now in use.

also shows you where the new `nginx_allowlist.conf` file is. just in case you need to enter more in future (where you will need to issue command `nginx -s reload` after any edits)

### alternative install method

alternative install method, so vars file can be edited before running .. 

is to clone this repo, by doing these steps INSTEAD of the above...

        apt install git
        git clone https://github.com/gadget78/xahl-node
        cd xahl-node
        chmod +x *.sh

adjusting .vars file with `node xahl_node.vars` if needed.

now install with

        `sudo ./setup.sh`

(if you want to force a different script install directory, prefix with `SCRIPT_DIR="/new/path/here"` if not default will be "$HOME"/xahl-node)

## alternative install method via Docker

you can use the docker image to install. [/gadget78/xahau-node:latest](https://hub.docker.com/r/gadget78/xahau-node)

### config files

#### .vars file

there is a xahl.node.vars file, to adjust how the setup.sh is configured, but this is only needed for advanced users

to adjust the default settings via this file, edit it using your preferred editor such as nano;

        nano ~/xahl-node/xahl_node.vars

there are MANY things that can be adjusted, the main ones are;

- `ALWAYS_ASK` - "true" true setting will force asking of questions, false will only ask questions if value is not set (in .vars or .env file) useful for re-generate files/setting
- `INSTALL_UPDATES` - "true" this setting can be used to turn off the checking/installing of linux updates, and default install packages
- `VARVAL_CHAIN_NAME` - "mainnet" this is the main "mode" of setup, can be either mainnet, or testnet
- `INSTALL_UFW` - "true" chose to install or not (in environments that do not have UFW installed in as standard)
- `INSTALL_CERTBOT_SSL` - "true" to let certbot handle it, "false" to be handled upstream, like Nginx Proxy Manager, or "nginx" if you want to place the files manually.
- `INSTALL_LANDINGPAGE` - "true" so you can switch off the landing page generation, if you have editing default one.
- `INSTALL_TOML` - "true" so you can switch of .toml file generation, if you have manually edited it
- `RECREATE_NGINX_FILES` - "true" this will recreate the nginx files, updating and fixing any issues
- `RECREATE_XAHAU_FILES` - "true" this will recreate all xahau files (xahaud.cfg, and validators-xahau.txt files), updating and fixing issues
- `USE_SYSTEMCTL` - "true" to use systemctl, or false to use other methods (useful for docker environments)

#### .env file

all the questions asked in setup, are saved in file called `.env` this is so they do not get altered by updating the repo (git pull)

- `USER_DOMAIN` - your server domain.
- `CERT_EMAIL` - email address for certificate renewals etc.
- `TOML_EMAIL` - email address for the PUBLIC .toml file.
- `NODE_TYPE` - saves you node type.

---

# Nginx related

All the domain specific config is contained in the file `NGX_CONF_NEW`/xahau (this and `default` are deleted, and recreated when running the script)

logs are held at /var/log/nginx/

and Although this works best as a dedicated host with no other nginx/proxy instances,

it can work behind another proxy instance, you may need to adjust the NGINX_PROXY_IP setting in xahl_node.vars file to the ip/subnet of your own proxy

# Node IP Permissions

the setup script adds 3 IPs by default to the nginx_allowlist.conf file, these are, the detected SSH IP, the external nodes IP, and the local environment IP.

In order to add/remove access to your node, you adjust the addresses within the `nginx_allowlist.conf` file

edit the `nginx_allowlist.conf` file with your preferred editor e.g. `nano nginx_allowlist.conf`.

start every line with allow, a space, and then the IP, and end the line with a semicolon.

for example

        allow 127.0.0.0;
        allow 192.168.0.1;

__ADD__ : Simply add a new line with the same syntax as above,

__REMOVE__ : Simply delete a line.

THEN

__RELOAD__ : for the changes to take effect you need to issue command `sudo nginx -s reload`

---

# Testing your Xahaud server

This can be done simply by entering the domain/URL into any browser.

great for diagnosis, or checking on Node remotely. as gives lots of info to check on your Nodes Health

there are two main landing pages;

one will give you either a notice that you IP is blocked, and which IP to put in the access list.

or the other if not IP blocked, will give more of a current live pull of your server details.

or following these next examples, you can test other aspects of it manually...

### Local XAHAUD

this option ONLY works LOCALLY on the xahau node, and is directly querying the node itself, type in the terminal;

        xahaud server_info

Note: look for `"server_state" : "full",` and your xahaud should be working as expected.
it may be in a `connected` state, if just installed. Give it time.

### RPC and API

a simple command from terminal, which can be locally on the xah node, or externally on a different terminal, a great way to test connection from your Evernode to your Xahau node,

    curl -X POST -H "Content-Type: application/json" -d '{"method":"server_info"}' https://your.domain

if it works, will reply with your server info, if not, will reply with a raw html file (of your blocked page for example)

### WEBSOCKET

#### REMOTELY safe to use on your evernode

another tool to test websocket function is via node, first we check/install websocket function

        npm install ws

now the command to perform, may be best to copy and paste this, then alter the wss://your.domain to the domain to test

        node -e "const ws = new (require('ws'))('wss://**your.domain**'); ws.once('open', () => { console.log('WebSocket Working'); ws.close(); }).on('error', () => console.log('WebSocket Failed'));"

which will reply WebSocket working, or Websocket Failed

#### ONLY SAFE in none Evernode Environments

to test the Websocket function of your xahau node, we can use the wscat command, 
**BUT this is not safe to install on a already existing/running evernode. only locally, or non-evernode terminals**

Copy the following command replacing `yourdomain.com` with your domain you used in setup. (this can be found in the .env file)

        wscat -c wss://yourdomain.com

This should open another session within your terminal, similar to the below;

    Connected (press CTRL+C to quit)
    >

and enter

    { "command": "server_info" }
which will return you xah node server info

---

# Future Updates

#### Auto updater

this now includes a "auto-updater" which will check (by default) every 24 hours

for a new binary release, and install and restart, if needed

#### New way

from version 0.88, you can simply type

        update

within the terminal to update... 

for older versions or if `update` doesn't work, you can use the one line command method from here [OK so HOW do we Install ?](#ok-so-how-do-we-install-?)

#### Old way

OR, you can do it the older manual git method of ....

apply repo updates to your local clone, 

        cd ~/xahl-node

which changes your working directory to the directory where you cloned repo last time

        git pull

checks for new repo updates, and pulls new updates if there is any.

if you HAVE changed the .vars file, you wll need to perform a "stash" that override those setting.. 

        git stash

then you can then perform git pull, and get the latest updates again .. 


---

### Contributors:  

A special thanks & shout out to the following community members for their input & testing;
- This was original made possible by [@inv4fee2020](https://github.com/inv4fee2020/), which has now been Heavily modified
- [@nixer89](https://github.com/nixer89) helped with the websocket splitting
- [@gadget78](https://github.com/gadget78) 
- [@realgo140point6](https://github.com/go140point6)
- [@rippleitinnz](https://github.com/rippleitinnz/xahaud_update)for the binary auto updater
- [@s4njk4n](https://github.com/s4njk4n)
- [Jan Žorž]{https://github.com/orgs/community/discussions/10539} for the IPv6 git hub proxy support
- @samsam

---

### Feedback
Please provide feedback on any issues encountered or indeed functionality by utilizing the relevant Github issues..