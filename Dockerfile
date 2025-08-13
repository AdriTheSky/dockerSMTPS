FROM alpine:3.22

RUN apk add --no-cache postfix cyrus-sasl cyrus-sasl-login cyrus-sasl-plain \
    ca-certificates bash openssl tzdata shadow rsyslog

RUN mkdir -p /var/spool/postfix /var/lib/postfix /etc/sasl2 \
 && chown -R postfix:postfix /var/spool/postfix /var/lib/postfix

COPY config/master.cf /etc/postfix/master.cf
COPY entrypoint/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

VOLUME ["/var/spool/postfix", "/var/lib/postfix", "/etc/postfix", "/etc/sasldb2"]

EXPOSE 25 587 465

HEALTHCHECK --interval=30s --timeout=5s --retries=5 CMD sh -c "nc -z localhost 465 || nc -z localhost 25 || exit 1"

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["postfix", "start-fg"]
