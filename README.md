
# Rencrypt

Rencrypt is a cli to generate and update SSL certificates on hetzner cloud
servers using [Letsencrypt](https://letsencrypt.org/). When running on multiple
hetzner cloud servers, rencrypt checks which server owns the particular
floating ip and only on this server the SSL certificate is generated or updated
if neccessary. Subsequently, the SSL certificate is pushed to a configurable
redis server, such that rencrypt running on the other servers can fetch it from
there.
