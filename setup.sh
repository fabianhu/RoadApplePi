#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
fi

softwareVersion=$(git describe --long)

echo -e "\e[1;4;246mRoadApplePi Setup $softwareVersion\e[0m
Welcome to RoadApplePi setup. RoadApplePi is \"Black Box\" software that
can be retrofitted into any car with an OBD port. This software is meant
to be installed on a Raspberry Pi running unmodified Raspbian Stretch,
but it may work on other OSs or along side other programs and modifications.
Use with anything other then out-of-the-box Vanilla Raspbain Stretch is not
supported.

This script will download, compile, and install the necessary dependencies
before finishing installing RoadApplePi itself. Depending on your model of
Raspberry Pi, this may take several hours.
"
#!/bin/bash
if [ $# -ge 1 ]
then
    $answer = $1
else
    #Prompt user if they want to continue
	read -p "Would you like to continue? (y/N) " answer
fi

if [ "$answer" == "n" ] || [ "$answer" == "N" ] || [ "$answer" == "" ]
then
	echo "Setup aborted"
	exit
fi

#################
# Update System #
#################
echo -e "\e[1;4;93mStep 1. Updating system\e[0m"
apt update
apt upgrade -y

###########################################
# Install pre-built dependencies from Apt #
###########################################
echo -e "\e[1;4;93mStep 2. Install pre-built dependencies from Apt\e[0m"
sudo apt install -y dnsmasq hostapd libbluetooth-dev apache2 php7.3 php7.3-mysql php7.3-bcmath mariadb-server libmariadbclient-dev libmariadbclient-dev-compat uvcdynctrl
#sudo systemctl disable hostapd dnsmasq
sudo apt install -y ffmpeg

################
# Build FFMpeg #
################
echo -e "\e[1;4;93mStep 3. Build ffmpeg (this may take a while)\e[0m"
ffmpegLocation=$(which ffmpeg)
if [ $? != 0 ]
then
	wget https://www.ffmpeg.org/releases/ffmpeg-3.4.2.tar.gz
	tar -xvf ffmpeg-3.4.2.tar.gz
	cd ffmpeg-3.4.2
	echo "./configure --enable-gpl --enable-nonfree --enable-mmal --enable-omx --enable-omx-rpi"
	./configure --enable-gpl --enable-nonfree --enable-mmal --enable-omx --enable-omx-rpi
	make -j$(nproc)
	make install
else
	echo "FFMpeg already found at $ffmpegLocation! Using installed version."
fi

################################
# Using CameraPi? By DavidMorp #
################################
echo -e "\e[1;4;93mStep 4. Camera Setup\e[0m"
read -r -p "Are you using a Camera Module? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
    if ! grep -q bcm2835-v4l2 /etc/modules; then
        echo "Adding Module"
        sh -c "echo 'bcm2835-v4l2' >> /etc/modules"
    else
        echo "Module already present"
    fi
else
    if grep -q bcm2835-v4l2 /etc/modules; then
        echo "You should remove bcm2835-v4l2 from /etc/modules"
    fi
fi

#######################
# Install RoadApplePi #
#######################
echo -e "\e[1;4;93mStep 4. Building and installing RoadApplePi\e[0m"
make
make install

cp -r html /var/www/
rm /var/www/html/index.html
mkdir /var/www/html/vids
chown -R www-data:www-data /var/www/html
chmod -R 0755 /var/www/html
cp raprec.service /lib/systemd/system
chown root:root /lib/systemd/system/raprec.service
chmod 0755 /lib/systemd/system/raprec.service
systemctl daemon-reload
systemctl enable raprec
#cp hostapd-rap.conf /etc/hostapd
#cp dnsmasq.conf /etc

# Enable SSL and HTTP => HTTPS redirect.
sudo install -o root -g root -m 0644 rewrite-ssl.conf /etc/apache2/sites-available
sudo a2enmod ssl
sudo a2ensite default-ssl
sudo a2enmod rewrite
sudo a2ensite rewrite-ssl
sudo a2dissite 000-default

installDate=$(date)
cp roadapplepi.sql roadapplepi-configd.sql
echo "INSERT INTO env (name, value) VALUES (\"rapVersion\", \"$softwareVersion\"), (\"installDate\", \"$installDate\");" >> roadapplepi-configd.sql
mysql < roadapplepi-configd.sql

echo "Done! Please reboot your Raspberry Pi now"
