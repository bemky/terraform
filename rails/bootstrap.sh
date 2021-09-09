# Find and replace [**domain**] with ex. "superleag.com"
# Find and replace [**Application**] with ex. "Superleag"
# Find and replace [**application**] with ex. "superleag"
# cd to this dir
cp -rf package tmp
find tmp -name '*application*' | while read f; do mv "$f" "${f/application/[**application**]}"; done
find tmp/* | while read f; do sed -i "" "s/\[\*\*Application\*\*\]/[**Application**]/g" "$f"; done
find tmp/* | while read f; do sed -i "" "s/\[\*\*application\*\*\]/[**application**]/g" "$f"; done

for f in '[**application**]-app.service' '[**application**]-app.socket' '[**application**]-worker@.service' '[**application**]-workers.target' '[**application**].target' 'logrotate'
do
  sum=`shasum -a 256 tmp/$f`
  sed -i "" "s/\[\*\*checksum:$f\*\*\]/${sum[0,64]}/g" tmp/PKGBUILD
done

scp -pr tmp [**application**]@[**domain**]:package
rm -rf tmp

ssh [**application**]@[**domain**]
cd package
makepkg
sudo pacman -U [**application**]...pkg.tar.zst
cd ../
rm -rf package

sudo cat <<EOF > /etc/nginx/sites/[**domain**]
server {
	listen 80;
	listen [::]:80;

	server_name [**domain**];

	include /etc/nginx/letsencrypt.conf;

	location ~ ^/ {
		return 301 https://[**domain**]$request_uri;
	}
}

server {
	listen 443 ssl http2;
	listen [::]:443 ssl http2;

	server_name [**domain**];

	include /etc/nginx/ssl/[**domain**];

	client_max_body_size  20m;

	resolver 84.200.69.80 [2001:1608:10:25::1c04:b12f] 84.200.70.40 [2001:1608:10:25::9249:d69b] valid=300s;
	resolver_timeout 5s;

	location @app {
		proxy_set_header X-Request-Start "t=${msec}";
		proxy_set_header Host $http_host;
		proxy_set_header X-Real-IP  $proxy_protocol_addr;
		proxy_set_header X-Forwarded-For $proxy_protocol_addr;
		proxy_set_header X-Forwarded-Proto https;
		proxy_http_version 1.1;
		proxy_buffer_size 64k;
		proxy_buffers 4 64k;
		proxy_busy_buffers_size 64k;
		proxy_redirect off;
		proxy_connect_timeout 5s;
		proxy_send_timeout 5s;
		proxy_next_upstream_timeout 10s;

		proxy_pass http://[**application**];
	}

	root /srv/[**application**]/current/public;

	location / {
		location ~ ^/(assets)/  {
		    gzip_static on;
		    gzip_vary on;
		    add_header Cache-Control "public, max-age=315360000, immutable";
		}

		if (-f /srv/[**application**]/shared/maintenance/[**domain**]) {
		    return 503;
		}

		try_files $uri @app;
	}

	error_page 503 /503.html;

	location /503.html {
		root /srv/[**application**]/current/public;
	}

	error_page 500 502 504 /500.html;

	location /500.html {
		root /srv/[**application**]/current/public;
	}
}
EOF

mkdir -p /etc/nginx/apps
sudo cat <<EOF > /etc/nginx/apps/[**application**]
upstream [**application**] {
	least_conn;
	server 127.0.0.1:8036;
}
EOF

systemctl restart nginx


## Setup Postgres DB
sudo su - postgres
createuser DATABASE --pwprompt
createdb DATABASE -O DATABASE -E UTF8
exit