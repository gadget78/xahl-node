#!/bin/bash

## run the initial setup script, if this is the 1st docker run (detected by no xahau DB)
if [[ ! -f "/opt/xahaud/db/ledger.db" ]] || \
   ! command -v nginx >/dev/null 2>&1 || \
   ! command -v cron >/dev/null 2>&1 || \
   ! command -v xahaud >/dev/null 2>&1; then
  
  ## setup domain and TLS files, if files found, and environment variables (variables can be sourced from env.vars file if found)
  if [[ -f "/contract/env.vars" ]]; then
    echo "found env.vars file, sourcing variables"
    source /contract/env.vars
  fi
  if [[ -n "${HOST_DOMAIN_ADDRESS:-}" ]] && [[ -f "/contract/cfg/tlscert.pem" ]] && [[ -f "/contract/cfg/tlskey.pem" ]]; then
    echo "found needed variables and TLS files, enabling https:// support"
    mkdir -p /etc/letsencrypt/live/${HOST_DOMAIN_ADDRESS}
    cp /contract/cfg/tlscert.pem /etc/letsencrypt/live/${HOST_DOMAIN_ADDRESS}/fullchain.pem
    cp /contract/cfg/tlskey.pem /etc/letsencrypt/live/${HOST_DOMAIN_ADDRESS}/privkey.pem
    sed -i "s/^INSTALL_CERTBOT_SSL=.*/INSTALL_CERTBOT_SSL=\"nginx\"/" "/root/xahl-node/xahl_node.vars"
    sed -i "s/^USER_DOMAIN=.*/USER_DOMAIN=\"$HOST_DOMAIN_ADDRESS\"/" "/root/xahl-node/.env"
  elif [[ "${INSTALL_CERTBOT_SSL:-}" == "true" ]] && [[ -n "${HOST_DOMAIN_ADDRESS:-}" ]] && [[ -n "${CERT_EMAIL:-}" ]]; then
    sed -i "s/^USER_DOMAIN=.*/USER_DOMAIN=\"$HOST_DOMAIN_ADDRESS\"/" "/root/xahl-node/.env"
    sed -i "s/^CERT_EMAIL=.*/CERT_EMAIL=\"$CERT_EMAIL\"/" "/root/xahl-node/.env"
    sed -i "s/^USER_DOMAIN=.*/USER_DOMAIN=\"$HOST_DOMAIN_ADDRESS\"/" "/root/xahl-node/.env"
    sed -i "s/^INSTALL_CERTBOT_SSL=.*/INSTALL_CERTBOT_SSL=\"true\"/" "/root/xahl-node/xahl_node.vars"
  fi

  /root/xahl-node/setup.sh

  ## adjust listening ports For both IPv4: and IPv6: if it has the supporting variables
  if [[ -n "${INTERNAL_GPTCP1_PORT:-}" ]]; then
    NGINX_CONF="/etc/nginx/sites-enabled/xahau"
    echo "adjusting internal listening port to $INTERNAL_GPTCP1_PORT in nginx conf file $NGINX_CONF"
    sed -i "0,/listen \([0-9]\+\)\( ssl\)\?;/s/listen \([0-9]\+\)\( ssl\)\?;/listen $INTERNAL_GPTCP1_PORT\2;/" "$NGINX_CONF"
    sed -i "0,/listen \[::\]:\([0-9]\+\)\( ssl\)\?;/s/listen \[::\]:\([0-9]\+\)\( ssl\)\?;/listen \[::\]:$INTERNAL_GPTCP1_PORT\2;/" "$NGINX_CONF"
  fi

  ## setup allowlist, to allow all connection (TO-DO either enter your own IP(s) here, or develop another method of restriction)
  echo "allow 0.0.0.0; # allow all" >> /root/xahl-node/nginx_allowlist.conf
  
  ## kill all processes so that supervisor can take control
  pkill -9 cron
  pkill -9 nginx
  pkill -9 xahaud
fi

## setup supervisor to keep everything running in docker
if ! command -v supervisord &> /dev/null; then
    apt-get update && apt-get install -y supervisor
fi
if [[ ! -f "/etc/supervisor/conf.d/services.conf" ]]; then
mkdir -p /etc/supervisor/conf.d
sudo cat <<EOF > /etc/supervisor/conf.d/services.conf
[supervisord]
nodaemon=true   ; Required for Docker!
user=root
logfile=/var/log/supervisord.log

[unix_http_server]
file=/var/run/supervisor.sock
chmod=0777
chown=root:root

[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

[supervisorctl]
serverurl=unix:///var/run/supervisor.sock

[program:nginx]
command=bash -c "/usr/sbin/nginx -g 'daemon off;'  2>&1 | sed 's/^/[NGINX] /'"  ; run nginx in foreground, with label for logs
startsecs=10                                                                    ; Wait 10 seconds before considering the program "started"
stdout_logfile=/dev/stdout                                                      ; Docker will then see all logs
stdout_logfile_maxbytes=0                                                       ; Disable log rotation for supervisor, and let docker handle them
stderr_logfile=/dev/stderr                                                      ; Errors go to stderr, for docker to handle them too
stderr_logfile_maxbytes=0                                                       ; Disable log rotation for supervisor, and let docker handle them
redirect_stderr=true                                                            ; Merge stderr into stdout
user=root                                                                       ; start as user root
autorestart=true                                                                ; make sure it continues to run, by restarting it.

[program:cron]
command=bash -c "cron -f  2>&1 | sed 's/^/[CRON] /'"                            ; Run cron in foreground, with label for logs
startsecs=10
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
redirect_stderr=true
user=root
autorestart=true

[program:xahaud]
command=bash -c "xahaud --start  2>&1 | sed 's/^/[XAHAU] /'"
startsecs=10
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
redirect_stderr=true
user=root
autorestart=true

EOF
fi

## now start supervisord, to keep it all running
supervisord -n -c /etc/supervisor/conf.d/services.conf

exec "$@"
wait