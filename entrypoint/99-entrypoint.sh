#!/bin/bash

set -euo pipefail

: "${MYHOSTNAME:=relay.example.com}"
: "${MYDOMAIN:=example.com}"
: "${MYNETWORKS:=0.0.0.0}"
: "${SMTP_USERS:=smtpUser:smtpPasswd}"
: "${RELAYHOST:=}"
: "${RELAYHOST_USER:=}"
: "${RELAYHOST_PASSWORD:=}"
: "${TZ:=Europe/Paris}"
: "${ENABLE_PROXY_PROTOCOL:=no}"
: "${SMTPD_LOGLEVEL:=1}"
: "${SMTP_LOGLEVEL:=1}"

ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime && echo "${TZ}" > /etc/timezone

# SASL
mkdir -p /etc/sasl2
cat >/etc/sasl2/smtpd.conf <<EOF
pwcheck_method: auxprop
auxprop_plugin: sasldb
mech_list: PLAIN LOGIN
sasldb_path: /etc/sasldb2
EOF
chmod 644 /etc/sasl2/smtpd.conf

# main.cf
cat >/etc/postfix/main.cf <<EOF
smtpd_banner = \$myhostname ESMTP
biff = no
append_dot_mydomain = no
readme_directory = no
compatibility_level = 3.6

inet_interfaces = all
inet_protocols = all

myhostname = ${MYHOSTNAME}
mydomain   = ${MYDOMAIN}
myorigin   = \$mydomain

# Never get mail
mydestination =
relay_domains =

mynetworks = ${MYNETWORKS}

smtpd_sasl_auth_enable = yes
smtpd_sasl_type = cyrus
smtpd_sasl_path = smtpd
smtpd_sasl_security_options = noanonymous

# No open-relay
smtpd_relay_restrictions = permit_mynetworks, permit_sasl_authenticated, reject_unauth_destination
smtpd_recipient_restrictions = permit_mynetworks, permit_sasl_authenticated, reject_unauth_destination

# Logging/verbo
smtpd_tls_loglevel = ${SMTPD_LOGLEVEL}
smtp_tls_loglevel  = ${SMTP_LOGLEVEL}
EOF

if [[ -n "${RELAYHOST}" ]]; then
  cat >>/etc/postfix/main.cf <<EOF
relayhost = ${RELAYHOST}
smtp_sasl_auth_enable = yes
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_sasl_security_options = noanonymous
smtp_use_tls = yes
EOF

  if [[ -n "${RELAYHOST_USER}" && -n "${RELAYHOST_PASSWORD}" ]]; then
    echo "${RELAYHOST} ${RELAYHOST_USER}:${RELAYHOST_PASSWORD}" >/etc/postfix/sasl_passwd
    postmap /etc/postfix/sasl_passwd
    chmod 600 /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db || true
  fi
fi

if [[ -n "${SMTP_USERS}" ]]; then
  IFS=';' read -ra PAIRS <<< "${SMTP_USERS}"
  for pair in "${PAIRS[@]}"; do
    u="${pair%%:*}"
    p="${pair#*:}"
    [[ -n "$u" && -n "$p" ]] || continue
    echo -n "$p" | saslpasswd2 -p -c -u "${MYHOSTNAME}" "$u"
  done
  chgrp postfix /etc/sasldb2 || true
  chmod 640 /etc/sasldb2 || true
fi

# YES = log real IP from client cnx
if [[ "${ENABLE_PROXY_PROTOCOL}" == "yes" ]]; then
  echo "smtpd_upstream_proxy_protocol = haproxy" >> /etc/postfix/main.cf
fi

postfix check || true
exec "$@"
