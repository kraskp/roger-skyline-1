#!/bin/bash

PRE_INFO="# "
PRE_ERR="! "

COLOR_INFO="\033[0;36m"
COLOR_NOTICE="\033[0;33m"
COLOR_ERR="\033[0;31m"
COLOR_RESET="\033[0m"

err () {
	echo -e ${COLOR_ERR}${PRE_ERR}${1}${COLOR_RESET}	
}

err_exit () {
	err "${1} - exiting"
	exit
}

pr () {
	echo -e "${COLOR_INFO}${PRE_INFO}${1}${COLOR_RESET}"
}

pr_notice () {
	echo -e "${COLOR_NOTICE}${PRE_INFO}${1}${COLOR_RESET}"
}

# Run with sudo.
pr "Updating system"
apt-get update -y || err_exit
echo
pr "Upgrading system"
apt-get upgrade -y || err_exit
echo

# Remove dhcp and create static ip
pr "Removing DHCP and creating static IP"
rm /etc/network/interfaces
cp /home/ken/roger-skyline-1/srcs/interfaces /etc/network/

# configure ssh properly with fixed port
rm -rf /etc/ssh/sshd_config
cp /home/ken/roger-skyline-1/srcs/sshd/sshd_config /etc/ssh
sudo service ssh restart || err "Restarting the SSH service failed"
sudo service sshd restart || err "Restarting the SSHD service failed"
sudo service networking restart || err "Restarting the networking service failed"
sudo ifup enp0s3 || err "enp0s3 failed"

#Install and configure Fail2Ban
yes "y" | sudo apt-get -y install fail2ban
pr "Deploying fail2ban src files"
cp /home/ken/roger-skyline-1/srcs/fail2ban/jail.local /etc/fail2ban/jail.local || err_exit "Failed to copy \"jail.local\""
cp /home/ken/roger-skyline-1/srcs/fail2ban/portscan.conf /etc/fail2ban/filter.d || err_exit "Failed to copy \"portscan.conf\""
cp /home/ken/roger-skyline-1/srcs/fail2ban/http-get-dos.conf /etc/fail2ban/filter.d || err_exit "Failed to copy \"http-get-dos.conf\""
sudo service fail2ban restart || err "Restarting fail2ban failed"

# stop unneeded services
pr "Stopping unneeded services"
sudo systemctl disable console-setup.service
sudo systemctl disable keyboard-setup.service
sudo systemctl disable apt-daily.timer
sudo systemctl disable apt-daily-upgrade.timer
sudo systemctl disable syslog.service

#Copy and set up cron scripts for updating packages and detecting crontab changes
pr "Installing mailx and deploying cron jobs"
sudo apt-get -y install mailx
sudo apt-get -y install mailutils
cp -r /home/ken/roger-skyline-1/srcs/scripts/ /home/ken/
{ crontab -l -u root; echo '0 4 * * SUN sudo /home/ken/scripts/update.sh'; } | crontab -u root -
{ crontab -l -u root; echo '@reboot sudo /home/ken/scripts/update.sh'; } | crontab -u root -
{ crontab -l -u root; echo '0 0 * * * SUN /home/ken/scripts/monitor.sh'; } | crontab -u root -
{ crontab -l -u ken; echo '0 4 * * SUN sudo /home/ken/scripts/update.sh'; } | crontab -u ken -
{ crontab -l -u ken; echo '@reboot sudo /home/ken/scripts/update.sh'; } | crontab -u ken -
{ crontab -l -u ken; echo '0 0 * * * SUN /home/ken/scripts/monitor.sh'; } | crontab -u ken -
{ crontab -e; echo '0 4 * * SUN sudo /home/ken/scripts/update.sh'; } | crontab -e -
{ crontab -e; echo '@reboot sudo /home/ken/scripts/update.sh'; } | crontab -e -
{ crontab -e; echo '0 0 * * * SUN /home/ken/scripts/monitor.sh'; } | crontab -e -

#install apache
pr "Installing apache"
sudo apt install apache2 -y
sudo systemctl enable apache2
yes "y" | rm -rf /var/www/html/
pr "Deploying webpage"
cp -r /home/ken/roger-skyline-1/srcs/html/ /var/www/html/

#Generate & Setup SSL
pr "Generate SSL self-signed key and certificate"
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -subj "/C=US/ST=Wisconsin/O=GreenBay/OU=Packers/CN=10.12.144.144" -keyout /etc/ssl/private/apache-selfsigned.key -out /etc/ssl/certs/apache-selfsigned.crt || err_exit "Failed to generate SSL self-signed key and certificate"
pr "Deploying SSL params src file"
cp /home/ken/roger-skyline-1/srcs/ssl/ssl-params.conf /etc/apache2/conf-available/ssl-params.conf || err_exit "Failed to copy ssl-params.conf"
pr "Backing up default SSL conf src file"
sudo cp /etc/apache2/sites-available/default-ssl.conf /etc/apache2/sites-available/default-ssl.conf.bak || err_exit "Failed to back up default SSL conf src file"
rm /etc/apache2/sites-available/default-ssl.conf
pr "Deploying default SSL conf src file"
cp /home/ken/roger-skyline-1/srcs/ssl/default-ssl.conf /etc/apache2/sites-available/default-ssl.conf || err_exit "Failed to copy default-ssl.conf"
rm /etc/apache2/sites-available/000-default.conf
pr "Deploying 000-default.conf src file"
cp /home/ken/roger-skyline-1/srcs/ssl/000-default.conf /etc/apache2/sites-available/000-default.conf || err_exit "Failed to copy 000-default.conf"

sudo a2enmod ssl
sudo a2enmod headers
sudo a2ensite default-ssl
sudo a2enconf ssl-params

#Set up Firewall; Default DROP connections
pr "Setting up firewall"
sudo apt-get update && sudo apt-get upgrade
yes "y" | sudo apt-get install ufw
sudo ufw enable
sudo ufw allow 50000/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw reload || err_exit "Failed to reload firewall"
sudo service sshd restart || err_exit "Failed to restart sshd"

#Reboot Apache server, hopefully we have a live website
systemctl reload apache2 || err_exit "Failed to restart apache"
sudo fail2ban-client status

pr_notice "Don't forget to setup SSH public key authentication on the host side!"