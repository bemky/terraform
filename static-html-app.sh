###
# Setup [user.. "bemky"] for app/site ([domain.. "bemky.com"])
###
groupadd --system [user]
useradd -c '[User] User' -g [user] --create-home --home /srv/[user] --shell /bin/bash [user]
chmod 755 /srv/[user]

mkdir /srv/[user]/.ssh
ssh-keyscan github.com >> /srv/[user]/.ssh/known_hosts
sync-accounts

cat <<EOF > /etc/nginx/sites/[domain]
server {
 listen 80;
 listen [::]:80;

 server_name [domain];
 include /etc/nginx/letsencrypt.conf;
  
 root /srv/[user]/[domain];

 location / {

   location ~ ^/(assets)/ {
     gzip_vary on;
     gzip_static on;
     add_header Cache-Control "public, max-age=315360000, immutable";
   }

   if (-f /srv/[user]/shared/maintenance/[domain]) {
     return 503;
   }

   try_files $uri $uri/index.html /index.html;
   add_header Cache-Control "public, max-age=60";
 }

 error_page 503 /503.html;
 location /503.html {
   root /srv/[user]/[domain];
 }

 error_page 500 502 504 /500.html;
 location /500.html {
   root /srv/[user]/[domain];
 }
}
EOF

systemctl restart nginx
