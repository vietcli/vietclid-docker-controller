#!/bin/bash

### Set default parameters
action=$1
domain=$2
rootDir=$3
owner=$(who am i | awk '{print $1}')
email='webmaster@lvietclidbocalhost'
userDir=$"/home/$SUDO_USER/vietclid/"
userDataDir=$"/home/$SUDO_USER/vietclid/data"
userLogDir=$"/home/$SUDO_USER/vietclid/log"
userConfigurationDir=$"/home/$SUDO_USER/vietclid/conf.d"
vietclidDefaultPassword='vietcli'
vietclidNet='vietclidNet'
vietclidNetIp='172.18.0.1'
vietclidDatabaseContainerName='vietclid-database-server'
vietclidDatabaseContainerIP='172.18.0.2'

##Docker base images
vietcliWebsaseImage='vietduong/vietcli-webbase-image'
databaseImage='mysql:latest'

### don't modify from here unless you know what you are doing ####


## Step 1 Check root permission##

if [ "$(whoami)" != 'root' ];
then
    echo $"You have no permission to run $0 as non-root user. Use sudo"
    exit 1;
fi

## Step 2 Check action request ##

if [ "$action" != 'create' ] && [ "$action" != 'delete' ] && [ "$action" != 'ifconfig' ]; then
    echo $"You need to prompt for action (create, createmage2, ifconfig or delete) -- Lower-case only"
    exit 1;
fi


## Step 3 Check docker if installed##

###Check if docker was installed###
which docker

if [ $? -ne 0 ]
then
    if lsb_release -s -d | grep -q "Ubuntu 16.04"; then
        echo $"Installing docker..."
        apt-get update
        apt-get install docker.io
        usermod -aG docker $SUDO_USER

    else
        echo $"You need to install docker before try again"
        echo $"Installing docker by below:"
        echo $"sudo apt-get update"
        echo $"sudo apt-get install --no-install-recommends apt-transport-https curl software-properties-common"
        echo $"sudo curl -fsSL 'https://sks-keyservers.net/pks/lookup?op=get&search=0xee6d536cf7dc86e2d7d56f59a178ac6c6238f52e' | sudo apt-key add -"
        echo $"sudo add-apt-repository \"deb https://packages.docker.com/1.13/apt/repo/ ubuntu-$(lsb_release -cs) main\""
        echo $"sudo apt-get -y install docker-engine"
        echo $"sudo gpasswd -a $SUDO_USER docker "
        exit 1;

    fi
else
    docker --version | grep "Docker version"

    if [ $? -ne 0 ]
    then
        echo $"You need to install docker before try again (Tested with Docker 1.13.1"
        exit 1;
    fi

    ## Set docker permission for current user
    usermod -aG docker $SUDO_USER

fi

## Step 4 Check mysql if installed ##

### Check if mysql is installed ###
if ! type mysql >/dev/null 2>&1; then
    if lsb_release -s -d | grep -q "Ubuntu 16.04"; then
        echo $"Installing mysql-client..."
        apt-get update
        apt-get install mysql-client

    else
        echo $"You need to install mysql before try again."
        exit 1;

    fi

fi

## Install pwgen to generate random password

if ! which pwgen > /dev/null; then
    if lsb_release -s -d | grep -q "Ubuntu 16.04"; then
        echo $"Installing pwgen..."
        apt-get update
        apt-get install pwgen

    else
        echo $"You need to install pwgen before try again."
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
logDir=$"${userDir}log/${domain//./}"

### get available IP

if ! ping -c1 -w3 $vietclidNetIp >/dev/null 2>&1
then
    ##echo "Ping did not respond; IP address either free or firewalled" >&2
    docker network create --subnet=172.18.0.0/16 $vietclidNet
    dockerContainerIp="172.18.0.11"
    dockerContainerNet=$vietclidNet
else
    i=11
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

###Check if Vietclid folder was created###
if ! [ -d $userDir ];
then
    ### create the main directory
    mkdir $userDir

    ### Create a directory for log
    mkdir $userLogDir

    ### Create a directory for data
    mkdir $userDataDir

    ### Create a directory for configuration
    mkdir $userConfigurationDir

    ### give permission to root dir
    chmod 755 -R $userDir
    chown $SUDO_USER:$SUDO_USER -R $userDir

    echo -e $"Vietclid folder was created on $userDir with permission 755 \n"

fi

###Check if docker mysql image was installed###

if [ ! "$(docker ps -a | grep ${vietclidDatabaseContainerName})" ];
then
    echo -e $"[RUNNING] Creating database server container \n"

    ## Create database log folder
    databaseServerLogDir=$"${userLogDir}/${vietclidDatabaseContainerName}"

    if [ ! -d "$databaseServerLogDir" ]; then
        mkdir $databaseServerLogDir

        chmod 755 -R $databaseServerLogDir
        chown $SUDO_USER:$SUDO_USER -R $databaseServerLogDir

    fi

    ## Create database data folder
    databaseServerDataDir=$"${userDataDir}/${vietclidDatabaseContainerName}"

    if [ ! -d "$databaseServerDataDir" ]; then
        mkdir $databaseServerDataDir

        chmod 755 -R $databaseServerDataDir
        chown $SUDO_USER:$SUDO_USER -R $databaseServerDataDir

    fi

    ## Create database configuration folder
    databaseServerConfigurationDir=$"${userConfigurationDir}/${vietclidDatabaseContainerName}"

    if [ ! -d "$databaseServerConfigurationDir" ]; then
        mkdir $databaseServerConfigurationDir

        cat > $databaseServerConfigurationDir/vietcli.cnf << "EOF"
[mysqld]
innodb_data_file_path = ibdata1:10M:autoextend:max:4096M
tmp_table_size = 4096M
max_heap_table_size = 4096M
explicit_defaults_for_timestamp = 1
innodb_lock_wait_timeout=360

# What's the threshold for a slow query to be logged?
long_query_time = 0.5

# Where should the queries be logged to?
slow_query_log_file = /var/log/mysql/mysql-slow.log

# Enable slow query logging - note the dashes rather than underscores
slow-query-log = 1

# Not using indexes regardless of the setting in long_query_time
#log-queries-not-using-indexes
EOF

        chmod 755 -R $databaseServerConfigurationDir
        chown $SUDO_USER:$SUDO_USER -R $databaseServerConfigurationDir

    fi


    ### Create a docker container for default DB Server

    echo -e $"-------------------------|Use default password for root (default password: $vietclidDefaultPassword)? (y/n)"
    read useDefaultPassword

    if [ "$useDefaultPassword" == 'y' -o "$useDefaultPassword" == 'Y' ]; then
        mysqlRootPassword=$vietclidDefaultPassword

    else
        ROOT_PASSWORD=`pwgen -c -n -1 12`
        mysqlRootPassword=ROOT_PASSWORD
        #This is so the passwords show up in logs.
        echo root password: $ROOT_PASSWORD

    fi

    ### Create docker container
    ##docker run --restart=always --net $dockerContainerNet --ip $vietclidDatabaseContainerIP  --name $vietclidDatabaseContainerName -v $databaseServerConfigurationDir:/etc/mysql/conf.d -v $databaseServerDataDir:/var/lib/mysql -e MYSQL_ROOT_PASSWORD=$mysqlRootPassword -d $databaseImage
    docker run --restart=always --net $dockerContainerNet --ip $vietclidDatabaseContainerIP  --name $vietclidDatabaseContainerName -v $databaseServerConfigurationDir:/etc/mysql/conf.d -v $databaseServerLogDir:/var/log/mysql -v $databaseServerDataDir:/var/lib/mysql -e MYSQL_ROOT_PASSWORD=$mysqlRootPassword -d $databaseImage
    docker run exec $vietclidDatabaseContainerName chown mysql:root /var/log/mysql

    #Write root password to log
    echo $mysqlRootPassword > $databaseServerLogDir/mysql-root-pw.txt

    echo -e $"-------------------------|root password was written on ${databaseServerLogDir}/mysql-root-pw.txt \n"
    echo -e $"-------------------------|Connect by SSH: mysql -h$vietclidDatabaseContainerIP -P3306 -uroot -p"$mysqlRootPassword" \n"

fi

if [ "$action" == 'create' ]
then
    ### check if domain already exists
    if grep -qs $domain /etc/hosts;
    then
        echo -e $"This domain already exists on /etc/hosts file.\nPlease Try Another one"
        exit;
    fi

    ### check if directory exists or not
    if ! [ -d $rootDir ]; then
        ### create the directory
        mkdir $rootDir
        mkdir $rootDir/html
        ### give permission to root dir
        chmod 755 $rootDir
        chown $SUDO_USER:$SUDO_USER $rootDir
        ### write test file in the new domain dir
        if ! echo "<?php echo phpinfo(); ?>" > $rootDir/html/phpinfo.php
        then
            echo $"ERROR: Not able to write in file $rootDir/html/phpinfo.php. Please check permissions"
            exit;
        else
            echo "<h1>VietCLID Default Site</h1><h3>VietCLID has just created this site!</h3>" > $rootDir/html/index.html
            echo $"Added content to $rootDir/html/phpinfo.php"
        fi
    fi

    ## Create log folder
    if ! [ -d $logDir ]; then
        echo $"[RUNNING] Creating log folder $logDir"
        mkdir $logDir
    fi

    ## Create docker container
    echo -e $"[RUNNING] docker run --net $dockerContainerNet --ip $dockerContainerIp -v $logDir:/home/vietcli/.log -v $rootDir:/home/vietcli/files -e HTTP_SERVER_NAME=$domain --name $domain -d $vietcliWebsaseImage"
    id=$(docker run --net $dockerContainerNet --ip $dockerContainerIp -v $logDir:/home/vietcli/.log -v $rootDir:/home/vietcli/files -e HTTP_SERVER_NAME=$domain --name $domain -d $vietcliWebsaseImage)

    if ! docker top $id &>/dev/null
    then
        echo -e $"There is an ERROR creating $domain container"
        exit;
    else
        echo -e $"\nNew Virtual Host Created on Docker\n"
    fi

    ### Add domain in /etc/hosts
    if ! echo "$dockerContainerIp	$domain" >> /etc/hosts
    then
        echo $"ERROR: Not able to write in /etc/hosts"
        exit;
    else
        echo -e $"Host added to /etc/hosts file \n"

        if [ -d $logDir ]; then
            echo -e $"Log files will write down on $logDir \n"
        fi

        echo -e $"Now you can access by default with account vietcli (pass: vietcli) \n"
        echo -e $"ssh vietcli@$dockerContainerIp \n"
    fi

    if [ "$owner" == "" ]; then

        if [ $SUDO_USER ];
        then
            chown -R $SUDO_USER:$SUDO_USER $rootDir
        elif [ $(whoami) ];
        then
            chown -R $(whoami):$(whoami) $rootDir
        fi

    else
        chown -R $owner:$owner $rootDir
    fi

    # Create Database
    echo -e $"[RUNNING] Create Database... \n "
    if [ ! "$(docker ps | grep \"$vietclidDatabaseContainerName\")" ]; then
        docker start $vietclidDatabaseContainerName
        echo -e $"============================================== \n"
        echo -e $"Creating Database : ${domain//./} \n"
        echo -e $"Database Host : $vietclidDatabaseContainerIP port 3306 \n"
        echo -e $"Username / Password : root / $vietclidDefaultPassword \n"
        echo -e $"Database Name : root / $vietclidDefaultPassword \n"
        echo -e $"Usage:  mysql -h$vietclidDatabaseContainerIP -P3306 -uroot -p$vietclidDefaultPassword ${domain//./}\n"
        echo -e $"============================================== \n"

        docker start $vietclidDatabaseContainerName
        mysql -h$vietclidDatabaseContainerIP -P3306 -uroot -p"$vietclidDefaultPassword" --execute="CREATE DATABASE ${domain//./};"
    fi


    ### show the finished message
    echo -e $"Complete! \nYou now have a new Docker Container Host \nYour new host is: http://$domain \nAnd its located at $rootDir"
    exit;

elif [ "$action" == 'ifconfig' ]
then
    docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $domain

else
    ### check whether domain already exists
    if ! grep -qs $domain /etc/hosts
    then
        echo -e $"This domain does not exist on /etc/hosts file.\nPlease try another one"
        exit;
    else
        ### Delete domain in /etc/hosts
        newhost=${domain//./\\.}
        sed -i "/$newhost/d" /etc/hosts

        ###Remove docker container
        if [ ! "$(docker ps -a | grep \"$domain\")" ]; then
            echo -e $"Delete docker container $domain ? (y/n)"
            read deldir

            if [ "$deldir" == 'y' -o "$deldir" == 'Y' ]; then
                ### Stop and remove docker container
                docker stop $domain
                echo -e $"Stopped"

                docker rm $domain
                echo -e $"Deleted"

                echo -e $"The docker container was deleted"
            else
                echo -e $"The docker container was conserved"
            fi

        fi

        ###Remove Database
        if ! mysql -h$vietclidDatabaseContainerIP -P3306 -uroot -p"$vietclidDefaultPassword" -e "use ${domain//./}"; then

            echo -e $"Delete database ${domain//./} ? (y/n)"
            read deldir

            if [ "$deldir" == 'y' -o "$deldir" == 'Y' ]; then

                mysql -h$vietclidDatabaseContainerIP -P3306 -uroot -p"$vietclidDefaultPassword" --execute="DROP DATABASE ${domain//./};"
                echo -e $"Dropped"

            fi

        fi


    fi

    ### check if directory exists or not
    if [ -d $rootDir ]; then
        echo -e $"Delete host root directory ? (y/n)"
        read deldir

        if [ "$deldir" == 'y' -o "$deldir" == 'Y' ]; then
            ### Delete the directory
            rm -rf $rootDir

            if [ -d $logDir ]; then
                rm -rf $logDir
            fi

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