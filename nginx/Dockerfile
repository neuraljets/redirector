FROM nginx:alpine

COPY nginx.conf /etc/nginx/nginx.conf
COPY domains.conf.template /etc/nginx/domains.conf.template
COPY update_nginx.sh /usr/local/bin/update_nginx.sh

RUN mkdir -p /etc/letsencrypt && \
    mkdir -p /var/www/certbot && \
    chmod +x /usr/local/bin/update_nginx.sh

EXPOSE 80 443