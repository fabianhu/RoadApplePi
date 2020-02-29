#!/bin/bash -e

on_chroot << EOF
systemctl disable hostapd dnsmasq
ffmpegLocation=$(which ffmpeg)
if [ $? != 0 ]
then
	wget https://www.ffmpeg.org/releases/ffmpeg-3.4.2.tar.gz
	tar -xvf ffmpeg-3.4.2.tar.gz
	cd ffmpeg-3.4.2
	echo "./configure --enable-gpl --enable-nonfree --enable-mmal --enable-omx --enable-omx-rpi"
	./configure --enable-gpl --enable-nonfree --enable-mmal --enable-omx --enable-omx-rpi
	make -j$(nproc)
	sudo make install
	cd ..
else
	echo "FFMpeg already found at $ffmpegLocation! Using installed version."
fi
cd ~/
raprec=$(which raprec)
if [ $? != 0 ]
then
	wget https://github.com/matt2005/RoadApplePi/archive/master.zip --output-document=RoadApplePi.zip
	unzip RoadApplePi.zip
	cd RoadApplePi-master
	make
	sudo make install
else
	echo "Raprec already installed"
fi
sudo cp -r html /var/www/
sudo rm /var/www/html/index.html
sudo chown -R www-data:www-data /var/www/html
sudo chmod -R 0755 /var/www/html
sudo cp raprec.service /lib/systemd/system
sudo chown root:root /lib/systemd/system/raprec.service
sudo chmod 0755 /lib/systemd/system/raprec.service
sudo systemctl daemon-reload
sudo systemctl enable raprec
sudo cp hostapd-rap.conf /etc/hostapd
sudo cp dnsmasq.conf /etc
sudo mkdir /var/www/html/vids
sudo chown -R www-data:www-data /var/www/html

installDate=$(date)
cp roadapplepi.sql roadapplepi-configd.sql
echo "INSERT INTO env (name, value) VALUES (\"rapVersion\", \"$softwareVersion\"), (\"installDate\", \"$installDate\");" >> roadapplepi-configd.sql
sudo mysql < roadapplepi-configd.sql
EOF
