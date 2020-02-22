
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
    --common-name=COMMON_NAME
    --server-name=SERVER_NAME
    --base-path=BASE_PATH
    --email=EMAIL
    --floating-ip=FLOATING_IP
    --redis-url=REDIS_URL
    [--hcloud-token=HCLOUD_TOKEN]
    [--before-script=BEFORE_SCRIPT]
    [--after-script=AFTER_SCRIPT]
```

You can pass either `--hcloud-token` or `HCLOUD_TOKEN`

## Usage (DNS challlenge)

```
  rencrypt dns
    --common-name=COMMON_NAME
    --base-path=BASE_PATH
    --email=EMAIL
    --redis-url=REDIS_URL
    [--aws-region=AWS_REGION]
    [--aws-access-key=AWS_ACCESS_KEY]
    [--aws-secret-key=AWS_SECRET_KEY]
    [--before-script=BEFORE_SCRIPT]
    [--after-script=AFTER_SCRIPT]
```

You can pass either `--aws-region`, `--aws-access-key` and `--aws-secret-key`
or `AWS_REGION`, `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`
