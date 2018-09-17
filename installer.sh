#!/usr/bin/env bash

#Tested on Ubuntu 18

# Install curl
sudo apt-get update && sudo apt-get install curl

# Download vietcli docker-compose collection
curl -L -O -C - https://raw.githubusercontent.com/vietcli/vietclid-docker-controller/master/vietcli-d.sh
curl -L -O -C - https://raw.githubusercontent.com/vietcli/vietclid-docker-controller/master/docker-clean.sh

# Set permission
sudo chmod +x vietcli-d.sh docker-clean.sh
sudo mv vietcli-d.sh /usr/local/sbin/vietcli-d

# Update docker and docker-compose
./docker-clean.sh
rm docker-clean.sh

# Final result!
echo -e $"============================================== \n"
echo -e $"Installed Vietcli Docker Controller for Ubuntu 18 version!! \n"
echo -e $"Usage : \n"
echo -e $"$ sudo vietcli-d --help \n"
echo -e $" \n"
echo -e $"After completed process, the docker container with IP 172.18.0.11 with be created! \n"
echo -e $"============================================== \n"