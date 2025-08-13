# SMTP Relay Docker avec Postfix + Traefik TLS + PROXY protocol v2

## 🎯 Objectif
Ce projet fournit un conteneur Docker **Postfix** configuré pour agir comme **SMTP relay** sécurisé.  
Le TLS est **terminé par Traefik** (certificats wildcard DNS) et la communication entre Traefik et Postfix se fait **en clair** dans le réseau Docker.

Le conteneur supporte :
- Authentification **SASL** (LOGIN/PLAIN)
- Restriction par **IP (`mynetworks`)**
- Relais via un **SMTP amont** si besoin
- **PROXY protocol v2** pour voir l’IP réelle du client dans les logs Postfix

## 🔑 Variables d'environnement

| Variable                | Description                            | Exemple                       |
|-------------------------|----------------------------------------|-------------------------------|
| `MYHOSTNAME`            | Hostname                               | `relay.example.com`           |
| `MYDOMAIN`              | Domain                                 | `example.com`                 |
| `MYNETWORKS`            | Authorize IP                           | `127.0.0.0/8, 192.168.1.0/24` |
| `SMTP_USERS`            | SASL ACCOUNT (`user:pass;user2:pass2`) | `app1:Pass123;app2:Secret!`   |
| `RELAYHOST`             | (Optional) SMTP                        | `[smtp.office365.com]:587`    |
| `RELAYHOST_USER`        | (Optional) Utilisateur SMTP            | `smtpuser@example.com`        |
| `RELAYHOST_PASSWORD`    | (Optional) Mot de passe SMTP           | `SuperSecret`                 |
| `ENABLE_PROXY_PROTOCOL` | USE PROXY protocol v2 (`yes`/`no`)     | `no`                          |
| `TZ`                    | Timezone                               | `Europe/Paris`                |
| `SMTPD_LOGLEVEL`        | SMTPD loglevel                         | `1`                           |
| `SMTP_LOGLEVEL`         | SMTP loglevel                          | `1`                           |

## 📌 PROXY protocol v2

### Sans PROXY protocol
Postfix voit uniquement **l’IP de Traefik** (IP interne Docker) comme source de connexion.

### Avec PROXY protocol
Traefik envoie **l’IP réelle** du client à Postfix via une entête spéciale au début de la connexion.

**Avantages :**
- Logs Postfix plus utiles (IP réelle)
- Règles IP (`mynetworks`) et limites de connexion basées sur la vraie IP

**⚠ Important** : Si activé côté Traefik, il faut aussi activer dans Postfix via ENABLE_PROXY_PROTOCOL *'yes'*

## Testing

````shell
swaks --to test@example.net --from app1@example.com \
--server relay.example.com:465 --auth LOGIN \
--auth-user app1 --auth-password 'Pass123' --tls
````

## Docker compose service example

````yaml
smtp-relay:
    volume:
      - spool:/var/spool/postfix
      - account:/etc/postfix
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    environment:
      MYHOSTNAME: "relay.example.com"
      MYDOMAIN: "example.com"
      MYNETWORKS: "127.0.0.0/8, 192.168.1.0/24"
      SMTP_USERS: "app1:Pass123;app2:Secret!"
      ENABLE_PROXY_PROTOCOL: "yes"
    labels:
      - "traefik.enable=true"
      # 465 SMTPS - TLS Traefik -> Postfix:25 interne
      - "traefik.tcp.routers.smtps.rule=HostSNI(`relay.example.com`)"
      - "traefik.tcp.routers.smtps.entrypoints=smtps"
      - "traefik.tcp.routers.smtps.tls=true"
      - "traefik.tcp.routers.smtps.tls.certresolver=le-dns"
      - "traefik.tcp.routers.smtps.service=smtp-internal-plain"
      - "traefik.tcp.services.smtp-internal-plain.loadbalancer.server.port=25"
      # ONLY IF ENABLE_PROXY_PROTCOL to YES else COMENTE IT
      - "traefik.tcp.services.smtp-internal-plain.loadbalancer.proxyProtocol.version=2"
````
