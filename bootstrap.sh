# Locale
echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen
locale-gen
export LANG=en_US.UTF-8

# Timezone
rm /etc/localtime
ln -s /usr/share/zoneinfo/Etc/UTC /etc/localtime

# Hostname
echo '[hostname]' > /etc/hostname
hostname -F /etc/hostname

cat <<EOF > /etc/hosts
127.0.0.1   localhost.localdomain   localhost
::1         localhost.localdomain   localhost


###
# Populate keys
# - If key loading problem run with --keyserver pool.sks-keyservers.net
###
pacman-key --init
pacman-key --populate archlinux
pacman-key --refresh-keys


# System Update
pacman --noconfirm -Syu

# Add 42Floors pacman repo (for account-sync)
pacman-key -r A1ADA9D4
pacman-key --lsign-key A1ADA9D4
pacman -Syy

# Basic Installs
pacman -S --noconfirm \
  git \
  node \
  npm \
  ruby \
  ruby-irb \
  bash-completion \
  base-devel \
  wget \
  htop \
  links \
  ack \
  vim \
  rsync \
  ncdu \
  tree \
  certbot \
  logrotate

# Rdoc needed for tab complete in irb?
gem install --no-document --no-user-install bundler rdoc

# Sync Accounts
pacman -S --noconfirm sync-accounts

cat <<EOF > /etc/sync-accounts.conf
users:
  - bemky
apps:
  [app-name]:
    - bemky
EOF

systemctl enable sync-accounts.timer
systemctl start sync-accounts.timer

/usr/bin/sync-accounts

# Sudo Access
# TODO: See http://ubuntuforums.org/showthread.php?p=8481350
cat <<EOF > /etc/sudoers
root ALL=(ALL) ALL
%wheel ALL=(ALL) NOPASSWD:ALL # Allow members of the group sudo to execute any command
EOF
chmod 440 /etc/sudoers

# NTP
pacman --noconfirm -S ntp
cat <<EOF > /etc/ntp.conf
server 0.us.pool.ntp.org iburst
server 1.us.pool.ntp.org iburst
server 2.us.pool.ntp.org iburst
server 3.us.pool.ntp.org iburst
restrict default kod limited nomodify nopeer noquery notrap
restrict 127.0.0.1
restrict ::1
driftfile /var/lib/ntp/ntp.drift
EOF

systemctl enable ntpd.service
systemctl start ntpd.service

# SSH Access
cat <<EOF > /etc/ssh/sshd_config
Port 22
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_dsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
SyslogFacility AUTH
LogLevel INFO
LoginGraceTime 120
PermitRootLogin no
StrictModes no
PubkeyAuthentication yes
IgnoreRhosts yes
HostbasedAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
PasswordAuthentication no
X11Forwarding yes
X11DisplayOffset 10
PrintMotd no
PrintLastLog yes
TCPKeepAlive yes
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
UsePAM yes
ClientAliveInterval 120
EOF

mkdir -p /etc/systemd/system/sshd.service.d
cat <<EOF > /etc/systemd/system/sshd.service.d/network.conf
[Unit]
After=network.target
EOF

# Logrotate
cat <<EOF > /etc/systemd/system/logrotate.timer
[Unit]
Description=Hourly rotation of log files
Documentation=man:logrotate(8) man:logrotate.conf(5)

[Timer]
OnCalendar=hourly
AccuracySec=15m
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl reenable logrotate.timer

systemctl daemon-reload
systemctl restart sshd.service

pacman --noconfirm -S nginx

/usr/bin/sync-accounts

mkdir /etc/nginx/sites
mkdir /etc/nginx/ssl

###
# Default Nginx Config
###
cat <<EOF > /etc/nginx/nginx.conf
worker_processes    auto;

error_log  /var/log/nginx/error.log;

events {
    worker_connections  1024;
}

http {
    include             mime.types;
    default_type        application/octet-stream;

    sendfile            on;

    keepalive_timeout   65;

    gzip                on;
    gzip_comp_level     5;
    gzip_types          application/x-javascript text/css application/javascript text/javascript text/plain text/xml application/json application/vnd.ms-fontobject application/x-font-opentype application/x-font-truetype application/x-font-ttf application/xml font/eot font/opentype font/otf image/svg+xml image/vnd.microsoft.icon image/x-icon;

    resolver            84.200.69.80 [2001:1608:10:25::1c04:b12f] 84.200.70.40 [2001:1608:10:25::9249:d69b];
    resolver_timeout    5s;

    types_hash_max_size 4096;
    
    include /etc/nginx/sites/*;
}
EOF

cat <<'EOF' > /etc/nginx/letsencrypt.conf
location ^~ /.well-known/acme-challenge/ {
  allow all;
  root /var/lib/letsencrypt/;
  default_type "text/plain";
  try_files $uri =404;
}
EOF

systemctl enable nginx.service
systemctl start  nginx.service

openssl dhparam -out /etc/nginx/dhparam.pem 4096

systemctl reload nginx.service


## For Certbot
sudo cat <<EOF > /usr/lib/systemd/system/certbot.service
[Unit]
Description=Let's Encrypt renewal
[Service]
Type=oneshot
ExecStart=/usr/bin/certbot renew --quiet --agree-tos --post-hook "systemctl reload ngnix"
EOF

sudo cat <<EOF > /usr/lib/systemd/system/certbot.timer
[Unit]
Description=Twice daily renewal of Let's Encrypt's certificates
[Timer]
OnCalendar=0/12:00:00
RandomizedDelaySec=6h
Persistent=true
[Install]
WantedBy=timers.target
EOF

sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer
