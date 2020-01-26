#!/bin/bash

# Run with sudo.
sudo apt -y update
sudo apt -y upgrade

# Remove dhcp and create static ip
cp ~/roger-skyline-1/srcs/interfaces /etc/network/interfaces

# configure ssh properly with fixed port
rm -rf /etc/ssh/sshd_config
cp ~/roger-skyline-1/srcs/sshd/sshd_config /etc/ssh
mkdir /home/ken/.ssh/
cat ~/roger-skyline-1/srcs/ssh/id_rsa.pub > /home/ken/.ssh/authorized_keys
sudo service ssh restart
sudo service sshd restart
sudo service networking restart
sudo ifup enp0s3

#Install and configure Fail2Ban
yes "y" | sudo apt-get -y install fail2ban
cp ~/roger-skyline-1/srcs/fail2ban/jail.local /etc/fail2ban/jail.local
cp ~/roger-skyline-1/srcs/fail2ban/portscan.conf /etc/fail2ban/filter.d
sudo service fail2ban restart

# stop unneeded services
sudo systemctl disable console-setup.service
sudo systemctl disable keyboard-setup.service
sudo systemctl disable apt-daily.timer
sudo systemctl disable apt-daily-upgrade.timer
sudo systemctl disable syslog.service

#Copy and set up cron scripts for updating packages and detecting crontab changes
sudo apt-get -y install mailx
sudo apt-get -y install mailutils
cp -r ~/roger-skyline-1/srcs/scripts/ ~/
{ crontab -l -u root; echo '0 4 * * SUN sudo ~/scripts/update.sh'; } | crontab -u root -
{ crontab -l -u root; echo '@reboot sudo ~/scripts/update.sh'; } | crontab -u root -
{ crontab -l -u root; echo '0 0 * * * SUN ~/scripts/monitor.sh'; } | crontab -u root -
{ crontab -l -u ken; echo '0 4 * * SUN sudo ~/scripts/update.sh'; } | crontab -u ken -
{ crontab -l -u ken; echo '@reboot sudo ~/scripts/update.sh'; } | crontab -u ken -
{ crontab -l -u ken; echo '0 0 * * * SUN ~/scripts/monitor.sh'; } | crontab -u ken -
{ crontab -e; echo '0 4 * * SUN sudo ~/scripts/update.sh'; } | crontab -e -
{ crontab -e; echo '@reboot sudo ~/scripts/update.sh'; } | crontab -e -
{ crontab -e; echo '0 0 * * * SUN ~/scripts/monitor.sh'; } | crontab -e -

#install apache
sudo apt install apache2 -y
sudo systemctl enable apache2
yes "y" | rm -rf /var/www/html/
cp -r ~/roger-skyline-1/srcs/html/ /var/www/html/

#Generate & Setup SSL
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -subj "/C=US/ST=Wisconsin/O=GreenBay/OU=Packers/CN=10.12.144.144" -keyout /etc/ssl/private/apache-selfsigned.key -out /etc/ssl/certs/apache-selfsigned.crt

cp ~/roger-skyline-1/srcs/ssl/ssl-params.conf /etc/apache2/conf-available/ssl-params.conf
sudo cp /etc/apache2/sites-available/default-ssl.conf /etc/apache2/sites-available/default-ssl.conf.bak
rm /etc/apache2/sites-available/default-ssl.conf
cp ~/roger-skyline-1/srcs/ssl/default-ssl.conf /etc/apache2/sites-available/default-ssl.conf
rm /etc/apache2/sites-available/000-default.conf
cp ~/roger-skyline-1/srcs/ssl/000-default.conf /etc/apache2/sites-available/000-default.conf

sudo a2enmod ssl
sudo a2enmod headers
sudo a2ensite default-ssl
sudo a2enconf ssl-params

#Set up Firewall; Default DROP connections
sudo apt-get update && sudo apt-get upgrade
yes "y" | sudo apt-get install ufw
sudo ufw enable
sudo ufw allow 50000/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw reload
sudo ssh service sshd restart

#Reboot Apache server, hopefully we have a live website
systemctl reload apache2
sudo fail2ban-client status