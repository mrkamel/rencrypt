
# Rencrypt

Rencrypt is a cli to generate and update SSL certificates on hetzner cloud
servers using [Letsencrypt](https://letsencrypt.org/) and the HTTP or DNS
challenge. When using the HTTP challenge and running on multiple hetzner cloud
servers, rencrypt checks which server owns the particular floating ip and only
on this server the SSL certificate is generated/updated if neccessary. When
using the DNS challenge, a DNS record is added to AWS route53, such that any
server can generate/update the certificate, such that rencrypt will acquire a
lock in redis before generating/updating the certificate. Subsequently, in both
cases the SSL certificate is pushed to a configurable redis server, such that
rencrypt running on the other servers can fetch it from there.

## Install

First, install ruby, then:

```
git clone https://github.com/mrkamel/rencrypt
gem install bundler
cd rencrypt
bundle
```

## Usage (HTTP challenge)

```
  rencrypt http
    --base-path=BASE_PATH
    --common-name=COMMON_NAME
    --email=EMAIL
    --floating-ip=FLOATING_IP
    --hcloud-token=HCLOUD_TOKEN
    --redis-url=REDIS_URL
    --server-name=SERVER_NAME
```

## Usage (DNS challlenge)

```
  rencrypt dns
    --aws-region=AWS_REGION
    --aws-access-key=AWS_ACCESS_KEY
    --aws-secret-key=AWS_SECRET_KEY
    --base-path=BASE_PATH
    --common-name=COMMON_NAME
    --email=EMAIL
    --redis-url=REDIS_URL
```
