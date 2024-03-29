###
# Setup [user.. "[**user**]"] for app/site ([domain.. "[**domain**]"])
# Find and Replace
# [**user**], bemky
# [**domain**], bemky.com
# [**root**], /srv/[**user**]/[**domain**]
# [**app_root**], /srv/[**user**]/current/public
###
sudo su
groupadd --system [**user**]
useradd -c '[**user**] User' -g [**user**] --create-home --home /srv/[**user**] --shell /bin/bash [**user**]
chmod 755 /srv/[**user**]
mkdir /srv/[**user**]/[**domain**]
chown [**user**] /srv/[**user**]/[**domain**]
chgrp [**user**] /srv/[**user**]/[**domain**]

sudo su - [**user**]
ssh-keyscan github.com >> /srv/[**user**]/.ssh/known_hosts
exit

cat <<EOF >> /etc/sync-accounts.conf
  [**user**]:
    - bemky
EOF
sync-accounts


cat <<EOF > /etc/nginx/sites/[**domain**]
server {
  listen 80;
  listen [::]:80;
  server_name [**domain**];
  include /etc/nginx/letsencrypt.conf;
  root [**root**];
}
EOF

systemctl restart nginx


certbot certonly \
        --webroot \
        --webroot-path /var/lib/letsencrypt/ \
        --expand \
        --deploy-hook 'systemctl reload nginx'\
        --cert-name "[**domain**]" \
        --email "benehmke@gmail.com" \
        --agree-tos \
        --no-eff-email \
        --domains "www.[**domain**],[**domain**]"
        
# use provided path to cert
# for example [**cert_path**] = /etc/letsencrypt/live/[**domain**]

cat <<EOF > /etc/nginx/ssl/[**domain**]
ssl_certificate         [**cert_path**]/fullchain.pem;
ssl_certificate_key     [**cert_path**]/privkey.pem;
ssl_trusted_certificate [**cert_path**]/chain.pem;
ssl_session_timeout 1d;
ssl_session_cache   shared:SSL:50m;
ssl_session_tickets off;
ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
ssl_dhparam   /etc/nginx/dhparam.pem;
ssl_ciphers 'ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES256-SHA:ECDHE-ECDSA-DES-CBC3-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:DES-CBC3-SHA:!DSS';
ssl_prefer_server_ciphers on;
add_header  Strict-Transport-Security max-age=15768000;
ssl_stapling  on;
ssl_stapling_verify on;
EOF

cat <<EOF > /etc/nginx/sites/[**domain**]
server {
  listen 80;
  listen [::]:80;
  server_name [**domain**];
  include /etc/nginx/letsencrypt.conf;
  location ~ ^/ {
    return 301 https://$domain$request_uri;
  }
}
server {
  listen 443 ssl http2;
  listen [::]:443 ssl http2;
  server_name www.[**domain**];
  include /etc/nginx/ssl/[**domain**];

  location ~ ^/ {
    return 301 https://[**domain**]$request_uri;
  }
}
server {
  listen 443 ssl http2;
  listen [::]:443 ssl http2;
  server_name [**domain**];
  include /etc/nginx/ssl/[**domain**];
  
  root [**app_root**];
  location / {
    location ~ ^/(assets)/ {
      gzip_vary on;
      gzip_static on;
      add_header Cache-Control "public, max-age=315360000, immutable";
    }
    if (-f /srv/[**user**]/shared/maintenance/[**domain**]) {
      return 503;
    }
    try_files $uri $uri/index.html /index.html;
    add_header Cache-Control "public, max-age=60";
  }
}
EOF

systemctl restart nginx
