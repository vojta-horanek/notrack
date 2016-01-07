#!/usr/bin/env bash
#Title : NoTrack Installer
#Description : This script will install NoTrack and then configure dnsmasq and lightpd
#Author : QuidsUp
#Date : 2016-01-03
#Usage : bash install.sh

#User configurable variables-----------------------------------------


#Settings------------------------------------------------------------
Version="0.1"
ConfLoc="~/.NoTrack/"
Height=$(tput lines)
Width=$(tput cols)
Height=$(($Height / 2))
Width=$((($Width * 2) / 3))
IPVersion=""
DNSChoice1=""
DNSChoice2=""


# Divide by two so the dialogs take up half of the screen, which looks nice.

#Welcome Dialog------------------------------------------------------
Show_Welcome() {
  whiptail --msgbox --title "Welcome" "This installer will transform your Raspberry Pi into a network-wide Tracker Blocker!" $Height $Width

  whiptail --title "Initating Network Interface" --yesno "NoTrack is a SERVER, therefore it needs a STATIC IP ADDRESS to function properly." --yes-button "Ok" --no-button "Abort" $Height $Width
  if (( $? == 1)) ; then                           #Abort install if user selected no
    echo "Aborting Install"
    exit 4
  fi
}

#Ask user which IP Version they are using on their network-----------
Ask_IPVersion() {
  Fun=$(whiptail --title "IP Version" --radiolist "Select IP Version being used" $Height $Width 2 --ok-button Select \
   IPv4 "IP Version 4 (default)" on \
   IPv6 "IP Version 6" off \
   3>&1 1>&2 2>&3) 
  Ret=$?
    
  if [ $Ret -eq 1 ]; then
    echo "Aborting Install"
    exit 4
  elif [ $Ret -eq 0 ]; then
    case "$Fun" in
      "IPv4") IPVersion="IPv4" ;;
      "IPv6") IPVersion="IPv6" ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 10 $Width 1 ;;
    esac 
  fi
}

#Ask user for preffered DNS server-----------------------------------
Ask_DNSServer() {
  Fun=$(whiptail --title "DNS Server" --radiolist "Choose a DNS server \nThe job of a DNS server is to translate human readable domain names (e.g. google.com) into an  IP address which your computer will understand (e.g. 109.144.113.88) \nBy default your router will forward DNS queries to your Internet Service Provider" $Height $Width 7 --ok-button Select \
   OpenDNS "OpenDNS" on \
   Google "Google Public DNS" off \
   DNSWatch "DNS.Watch" off \
   Verisign "Verisign" off \
   Comodo "Comodo" off \
   FreeDNS "FreeDNS" off \
   Yandex "Yandex DNS" off \
   3>&1 1>&2 2>&3) 
  Ret=$?
    
  if [ $Ret -eq 1 ]; then
    echo "Aborting Install"
    exit 4
  elif [ $Ret -eq 0 ]; then
    case "$Fun" in
      "OpenDNS") 
        DNSChoice1="208.67.222.222" 
        DNSChoice2="208.67.220.220"
      ;;
      "Google") 
        DNSChoice1="8.8.8.8"
        DNSChoice2="8.8.4.4"
      ;;
      "DNSWatch") 
        if [[ $IPVersion == "IPv6" ]]; then
          DNSChoice1="2001:1608:10:25::1c04:b12f"
          DNSChoice2="2001:1608:10:25::9249:d69b"
        else
          DNSChoice1="84.200.69.80"
          DNSChoice2="84.200.70.40"
        fi
      ;;
      "Verisign")
        DNSChoice1="64.6.64.6"
        DNSChoice2="64.6.65.6"
      ;;
      "Comodo")
        DNSChoice1="8.26.56.26"
        DNSChoice2="8.20.247.20"
      ;;
      "FreeDNS")
        DNSChoice1="37.235.1.174"
        DNSChoice2="37.235.1.177"
      ;;
      "Yandex")
        if [[ $IPVersion == "IPv6" ]]; then
          DNSChoice1="2a02:6b8::feed:bad"
          DNSChoice2="2a02:6b8:0:1::feed:bad"
        else
          DNSChoice1="77.88.8.88"
          DNSChoice2="77.88.8.2"
        fi
      ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 10 $Width 1 ;;
    esac 
  fi
}

#Install Applications------------------------------------------------
Install_Apps() {
  sudo apt-get update
  echo
  echo "Installing dependencies"
  sudo apt-get -y install unzip
  echo
  echo "Installing Dnsmasq"
  sudo apt-get -y install dnsmasq
  echo
  echo "Installing Lightpd and PHP5"
  sudo apt-get -y install lighttpd php5-cgi
  echo
}

#Backup Configs------------------------------------------------------
Backup_Conf() {
  echo "Backing up old config files"
  echo "Copying /etc/dnsmasq.conf to /etc/dnsmasq.conf.old"
  sudo cp /etc/dnsmasq.conf /etc/dnsmasq.conf.old
  echo "Copying /etc/lighttpd/lighttpd.conf to /etc/lighttpd/lighttpd.conf.old"
  sudo cp /etc/lighttpd/lighttpd.conf /etc/lighttpd/lighttpd.conf.old
  echo
}

#Download------------------------------------------------------------
Download_NoTrack() {
  if [ -d ~/NoTrack ]; then                      #Move NoTrack folder if it exists
    if [ -d ~/NoTrack-old ]; then                #Delete NoTrack-old folder if it exists
      echo "Removing old NoTrack folder"
      echo
      rm -r ~/NoTrack-old
    fi
    echo "Moving ~/NoTrack folder to ~/NoTrack-old"
    echo
    mv ~/NoTrack ~/NoTrack-old
  fi

  echo "Downloading latest code from github"
  wget https://github.com/quidsup/notrack/archive/master.zip -O /tmp/notrack-master.zip
  
  if [ ! -e /tmp/notrack-master.zip ]; then      #Check if download was successful
    echo "Error Download from github has failed"
    exit 1                                       #Abort we can't go any further without any code from git
  fi

  unzip -oq /tmp/notrack-master.zip -d /tmp
  mv /tmp/notrack-master ~/NoTrack
  rm /tmp/notrack-master.zip                     #Cleanup
  
}
#Setup---------------------------------------------------------------
Setup_NoTrack() {
  #Copy config files modified for NoTrack
  echo "Copying config files from ~/NoTrack to /etc/"
  sudo cp ~/NoTrack/conf/dnsmasq.conf /etc/dnsmasq.conf
  sudo cp ~/NoTrack/conf/lighttpd.conf /etc/lighttpd/lighttpd.conf
  
  #Finish configuration of dnsmasq
  sudo sed -i "s/server=changeme1/server=$DNSChoice1/" /etc/dnsmasq.conf
  sudo sed -i "s/server=changeme2/server=$DNSChoice2/" /etc/dnsmasq.conf 
  
  #Configure lightpd
  sudo usermod -a -G www-data $(whoami)          #Add www-data group rights to current user
  sudo lighty-enable-mod fastcgi fastcgi-php
  sudo chmod 775 /var/www/html                   #Give read/write privilages to Web folder
  
  sudo ln -s ~/NoTrack/sink /var/www/html/sink   #Setup symlinks for Web folders
  sudo ln -s ~/NoTrack/admin/ /var/www/html/admin
}
#Main----------------------------------------------------------------

#Show_Welcome

#Ask_IPVersion
echo "IPVersion set to: "$IPVersion
echo

Ask_DNSServer
echo "Primary DNS Server set to: "$DNSChoice1
echo "Secondary DNS Server set to: "$DNSChoice2
echo 

#Install Applications
#Install_Apps

#Backup old config files
#Backup_Conf

#Download_NoTrack


#Setup_NoTrack

#touch /etc/localhosts.list