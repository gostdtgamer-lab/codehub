#!/bin/bash

clear
echo "================================"
echo "  Pterodactyl Auto Installer"
echo "================================"

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit
fi

echo "Updating system..."
apt update -y && apt upgrade -y

echo "Installing dependencies..."
apt install -y curl wget git unzip nginx mariadb-server redis-server

echo "Installing PHP..."
apt install -y php php-cli php-fpm php-mysql php-zip php-gd php-mbstring php-curl php-xml php-bcmath

echo "Installing Composer..."
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer

echo "Downloading Pterodactyl Panel..."
cd /var/www/
mkdir pterodactyl
cd pterodactyl

curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
tar -xzvf panel.tar.gz
chmod -R 755 storage/* bootstrap/cache/

echo "Installing panel dependencies..."
composer install --no-dev --optimize-autoloader

echo "Creating environment..."
cp .env.example .env
php artisan key:generate --force

echo "Setup complete!"
echo "Now configure database and run:"
echo "php artisan p:environment:setup"
echo "php artisan p:environment:database"
echo "php artisan migrate --seed --force"
