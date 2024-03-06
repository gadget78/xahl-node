# Xahau RPC/WSS Submission Node 
Xahau submission node installation with nginx &amp; lets encrypt TLS certificate.

---

This script will take the standard Xahau node install (non-docker version) and supplement it with the necessary configuration to provide a TLS secured RPC/WSS endpoint using Nginx.

This script is automating the manual steps in here, please review for more information about the process: https://github.com/go140point6/xahl-info/blob/main/setup-xahaud-node.md 

# Table of Contents
---

- [Xahau RPC/WSS Submission Node](#xahau-rpcwss-submission-node)
- [Table of Contents](#table-of-contents)
  - [Current functionality](#current-functionality)
  - [How to download \& use](#how-to-download--use)
    - [Clone the repo](#clone-the-repo)
    - [Vars file _(xahl\_node.vars)_](#vars-file-xahl_nodevars)
    - [Script Usage](#script-usage)
    - [Nginx related](#nginx-related)
      - [Permitted Access - scripted](#permitted-access---scripted)
      - [Permitted Access - manual](#permitted-access---manual)
    - [Testing your Xahaud server and Websocket endpoint](#testing-your-xahaud-server-and-websocket-endpoint)
      - [xahaud](#xahaud)
      - [Websocket](#websocket)
  - [Manual updates](#manual-updates)
    - [Contributors:](#contributors)
    - [Feedback](#feedback)


---
---

## Current functionality
 - Install options for Mainnet (Testnet if demand warrants)
 - Supports the use of custom variables using the `xahl_node.vars` file
 - Detects UFW firewall & applies necessary firewall updates.
 - Installs & configures Nginx 
   - Currently only supports multi-domain deployment with one A record & two CNAME records (requires operator has control over the domain)
   - Automatically detects the ssh session source IP & adds to the config as a permitted source
 - Applies NIST security best practices
 
---

## How to download & use

To download the script(s) to your local node & install, read over the following sections and when ready simply copy and paste the code snippets to your terminal window.

### Clone the repo

        cd ~/
        git clone https://github.com/go140point6/xahl-node
        cd xahl-node
        chmod +x *.sh



### Vars file _(xahl_node.vars)_

The vars file allows you to manually update the following variables which help to avoid interactive prompts during the install;

- `USER_DOMAINS` - note the order in which the A & CNAME records must be entered.
- `CERT_EMAIL` - email address for certificate renewals etc.

The file also controls some of the packages that are installed on the node. More features will be added over time.

Simply clone down the repo and update the file using your preferred editor such as nano;

        nano ~/xahl-node/xahl_node.vars


### Script Usage

The following example will install a `mainnet` node

        ./setup.sh mainnet

>        Usage: ./setup.sh {function}
>            example:  ./setup.sh mainnet
>
>        where {function} is one of the following;
>
>              mainnet       ==  deploys the full Mainnet node with Nginx & Let's Encrypt TLS certificate

---

### Nginx related

It is assumed that the node is being deployed to a dedicated host with no other nginx configuration. The node specific config is contained in the `NGX_CONF_NEW` variable which is a file named `xahau`.

As part of the installation, the script adds the ssh session source IPv4 address as a permitted source for accessing reverse proxied services. Operators should update this as necessary with additional source IPv4 addresses as required.

#### Permitted Access - scripted

__tbc__



#### Permitted Access - manual

In order to add/remove source IPv4 addresses from the permit list within the nginx config, you simply access the file with your preferred editor e.g. vim or nano etc.  Each of the server blocks must be updated to reflect your desired access control policy. Pay attention
to what server block you are in, there are two! The first is for RPC access, the second is for Websocket access.

Open the file with the 'nano' editor;
`sudo nano /etc/nginx/sites-available/xahau`

Move the cursor to the server blocks, similar to the following. NOTE! These IP addresses are EXAMPLES! You need YOUR IP addresses here;

    location / {
        try_files  / =404;
        allow 123.45.67.89;     # evr-node01
        allow 98.76.54.32;      # evr-node02
        allow 111.111.111.111;  # evr-node03
        allow 88.88.88.88;      # some-other-server
        allow 55.44.33.222;     # Allow the source IP of the node itself (for validation testing)
        deny all;

__ADD__ : Simply add a new line after the last allow (& above the deny all) being sure to enter a valid IPv4 address and end with a semi-colon '*_;_*'

__REMOVE__ : Simply delete the entire line.

Save the file and exit the editor.

For the changes to take effect, you will need to restart the nginx service as follows;

        sudo systemctl restart nginx


---

### Testing your Xahaud server and Websocket endpoint

The following are examples of tests that have been used successfully to validate correct operation;

#### xahaud

Run the following command:

        xahaud server_info

Note: look for `"server_state" : "full",` and your xahaud should be working as expected.  May be "connected", if just installed. Give it time.

#### Websocket

Install wscat one of two ways:

        sudo apt-get update
        sudo apt-get install node-ws

        OR

        npm install -g wscat

Copy the following command and update with the your WSS CNAME that you entered at run time or in the vars file.

        wscat -c wss://wss.EXAMPLE.com

This should open another session within your terminal, similar to the below;

    Connected (press CTRL+C to quit)
    >

---

## Manual updates

To apply repo updates to your local clone, be sure to stash any modifications you may have made to the `xahl_node.vars` file & take a manual backup also.

        cd ~/xahl-node
        git stash
        cp xahl_node.vars ~/xahl_node_$(date +'%Y%m%d%H%M%S').vars
        git pull
        git stash apply

---

### Contributors:  
This was all made possible by [@inv4fee2020](https://github.com/inv4fee2020/), this is 98% his work, I just copied pasta'd... and fixed his spelling mistakes like "utilising"... ;)

A special thanks & shout out to the following community members for their input & testing;
- [@realgo140point6](https://github.com/go140point6)
- [@s4njk4n](https://github.com/s4njk4n)
- @samsam

---

### Feedback
Please provide feedback on any issues encountered or indeed functionality by utilizing the relevant Github issues..