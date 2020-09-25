sudo pacman -S php-fpm
sudo systemctl enable php-fpm
sudo systemctl start php-fpm

# Update example.com nginx conf

systemctl restart nginx