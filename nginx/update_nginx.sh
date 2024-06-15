#!/bin/bash

DOMAINS=$(sqlite3 /app/db/redirects.db "SELECT domain FROM redirects")
NGINX_CONF="/etc/nginx/nginx.conf"
NGINX_TEMPLATE="/etc/nginx/domains.conf.template"

# Clear existing domain configuration
> $NGINX_CONF

# Add base Nginx configuration
cat <<EOL >> $NGINX_CONF
events {}
http {
EOL

# Iterate over domains and update Nginx configuration
for DOMAIN in $DOMAINS; do
    CONF=$(sed "s/{{server_name}}/$DOMAIN/g" $NGINX_TEMPLATE)
    echo "$CONF" >> $NGINX_CONF
done

# Close the http block
echo "}" >> $NGINX_CONF

# Reload Nginx to apply changes
nginx -s reload