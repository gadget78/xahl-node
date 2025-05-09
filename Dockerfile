FROM ubuntu:latest

RUN apt-get update -y && apt-get upgrade -y && apt-get dist-upgrade -y && \
    apt-get install -y jq sudo wget gpg curl nano git supervisor htop ucommon-utils openssh-server inetutils-ping passwd && \
    mkdir /var/run/sshd && sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd && \
    rm -rf /var/lib/apt/lists/*

ENV NOTVISIBLE="in users profile"

RUN echo "export VISIBLE=now" >> /etc/profile && rm -f /run/nologin

RUN git clone https://github.com/gadget78/xahl-node /root/xahl-node

WORKDIR /root/xahl-node

RUN sed -i "s/^ALWAYS_ASK=.*/ALWAYS_ASK=\"false\"/" "/root/xahl-node/xahl_node.vars"

RUN sed -i "s/^INSTALL_CERTBOT_SSL=.*/INSTALL_CERTBOT_SSL=\"false\"/" "/root/xahl-node/xahl_node.vars"

RUN sed -i "s/^INSTALL_UFW=.*/INSTALL_UFW=\"false\"/" "/root/xahl-node/xahl_node.vars"

RUN sed -i "s/^USE_SYSTEMCTL=.*/USE_SYSTEMCTL=\"false\"/" "/root/xahl-node/xahl_node.vars"

RUN echo "USER_DOMAIN=\"_\"" >> /root/xahl-node/.env

RUN echo -e "TOML_EMAIL=\"blank@email.com\"" >> /root/xahl-node/.env

RUN echo -e "CERT_EMAIL=\"blank@email.com\"" >> /root/xahl-node/.env

RUN chmod +x /root/xahl-node/setup.sh 

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 22 80 443