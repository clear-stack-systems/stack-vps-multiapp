server {
  listen 80;
  server_name ${SERVER_NAME};

  location /.well-known/acme-challenge/ {
    root /var/www/certbot;
  }

  location / {
    return 301 https://$host$request_uri;
  }
}

server {
  listen 443 ssl;
  http2 on;
  server_name ${SERVER_NAME};

  ssl_certificate     /etc/letsencrypt/live/${SERVER_NAME}/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/${SERVER_NAME}/privkey.pem;

  root /var/www/app/public;
  index index.php;

  location / {
    try_files $uri $uri/ /index.php?$query_string;
  }

  location ~ \.php$ {
    include fastcgi_params;
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    fastcgi_pass ${UPSTREAM}:9000;
  }
}
