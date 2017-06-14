#!/bin/bash

### Set Language
DEFAULT_DOMAIN=Vietclid

### Set default parameters
action=$1
domain=$2
rootDir=$3
owner=$(who am i | awk '{print $1}')
email='webmaster@localhost'
#sitesEnable='/etc/apache2/sites-enabled/'
#sitesAvailable='/etc/apache2/sites-available/'
userDir='/var/www/'
vietclidNet='vietclidNet'
vietclidNetIp='172.18.0.1'
#sitesAvailabledomain=$sitesAvailable$domain.conf

### don't modify from here unless you know what you are doing ####

if [ "$(whoami)" != 'root' ]; then
	echo $"You have no permission to run $0 as non-root user. Use sudo"
		exit 1;
fi

if [ "$action" != 'create' ] && [ "$action" != 'delete' ] && [ "$action" != 'ifconfig' ]
	then
		echo $"You need to prompt for action (create or delete) -- Lower-case only"
		exit 1;
fi

###Check if docker was installed###
which docker

if [ $? -ne 0 ]
then
    echo $"You need to install docker before try again"
    exit 1;
else
    docker --version | grep "Docker version"

    if [ $? -ne 0 ]
    then
        echo $"You need to install docker before try again"
        exit 1;
    fi
fi

while [ "$domain" == "" ]
do
	echo -e $"Please provide domain. e.g.dev,staging"
	read domain
done


if [ "$rootDir" == "" ]; then
	rootDir=${domain//./}
fi

### if root dir starts with '/', don't use /var/www as default starting point
if [[ "$rootDir" =~ ^/ ]]; then
	userDir=''
fi

rootDir=$userDir$rootDir

### get available IP

if ! ping -c1 -w3 $vietclidNetIp >/dev/null 2>&1
then
        ##echo "Ping did not respond; IP address either free or firewalled" >&2
        docker network create --subnet=172.18.0.0/16 $vietclidNet
        dockerContainerIp="172.18.0.2"
        dockerContainerNet=$vietclidNet
else
    i=2
    while (( i <= 100 ))
    do
            if ! grep -qs "172.18.0.$i" /etc/hosts;
            then
                dockerContainerIp="172.18.0.$i"
                dockerContainerNet=$vietclidNet
                i=100
            fi
            i=$((i + 1))
    done
fi

if [ "$action" == 'create' ]
	then
		### check if domain already exists
        if grep -qs $domain /etc/hosts;
        then
			echo -e $"This domain already exists.\nPlease Try Another one"
			exit;
        fi

		### check if directory exists or not
		if ! [ -d $rootDir ]; then
			### create the directory
			mkdir $rootDir
			### give permission to root dir
			chmod 755 $rootDir
			chown $USER:$USER $rootDir
			### write test file in the new domain dir
			if ! echo "<?php echo phpinfo(); ?>" > $rootDir/vietcli.php
			then
				echo $"ERROR: Not able to write in file $rootDir/vietcli.php. Please check permissions"
				exit;
			else
				echo $"Added content to $rootDir/vietcli.php"
			fi
		fi

		### create docker container
		id=$(docker run --net $dockerContainerNet --ip $dockerContainerIp -v $rootDir:/home/vietcli/files --name $domain -d vietduong/centos-nginx-phpfpm)
		echo -e $"[RUNNING] docker run --net $dockerContainerNet --ip $dockerContainerIp -v $rootDir:/var/www --name $domain -d vietduong/vietcli-centos-image "

        if ! docker top $id &>/dev/null
		then
			echo -e $"There is an ERROR creating $domain container"
			exit;
		else
			echo -e $"\nNew Virtual Host Created\n"
		fi

		### Add domain in /etc/hosts
		if ! echo "$dockerContainerIp	$domain" >> /etc/hosts
		then
			echo $"ERROR: Not able to write in /etc/hosts"
			exit;
		else
			echo -e $"Host added to /etc/hosts file \n"
			echo -e $"Now you can access by default with account vietcli (pass: vietcli) \n"
			echo -e $"ssh vietcli@$dockerContainerIp \n"
		fi

		if [ "$owner" == "" ]; then

		    if [ $SUDO_USER ];
		    then
                chown -R $SUDO_USER:$SUDO_USER $rootDir
                echo -e $"Set owner by SUDO_USER with value $SUDO_USER for $rootDir \n"
            elif [ $(whoami) ];
            then
                chown -R $(whoami):$(whoami) $rootDir
                echo -e $"Set owner by whoami with value $(whoami) for $rootDir \n"
		    fi

		else
			chown -R $owner:$owner $rootDir
			echo -e $"Set owner by owner with value $owner for $rootDir \n"
		fi

		### show the finished message
		echo -e $"Complete! \nYou now have a new Virtual Host \nYour new host is: http://$domain \nAnd its located at $rootDir"
		exit;

	elif [ "$action" == 'ifconfig' ]
	then
	    docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $domain

	else
		### check whether domain already exists
		if ! grep -qs $domain /etc/hosts
		then
			echo -e $"This domain does not exist.\nPlease try another one"
			exit;
		else
			### Delete domain in /etc/hosts
			newhost=${domain//./\\.}
			sed -i "/$newhost/d" /etc/hosts

			###Remoce docker container
			docker stop $domain
			docker rm $domain

		fi

		### check if directory exists or not
		if [ -d $rootDir ]; then
			echo -e $"Delete host root directory ? (y/n)"
			read deldir

			if [ "$deldir" == 'y' -o "$deldir" == 'Y' ]; then
				### Delete the directory
				rm -rf $rootDir
				echo -e $"Directory deleted"
			else
				echo -e $"Host directory conserved"
			fi
		else
			echo -e $"Host directory not found. Ignored"
		fi

		### show the finished message
		echo -e $"Complete!\nYou just removed docker container $domain"
		exit 0;
fi
