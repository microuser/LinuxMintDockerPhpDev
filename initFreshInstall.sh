#!/bin/bash
##Supported Linux Install Precondition
release=$(lsb_release -cs)
if [ "$release" == "tessa" ] 
then
    #needed to edit this command for linux mint 19 (based on 18.04)
	release=bionic
elif [ "$release" != "bionic" ] 
then
    echo "This script only supports Linux Mint 19 (Tessa) or Ubuntu 18.04 (bionic)"
    exit 1
fi

function AddGroupsFirst(){
    if ! id -nG "$USER" | grep -qw "docker" 
    then
        sudo groupadd docker
        sudo usermod -aG docker $USER
        echo Due to shell complexities, please return this program.
        exit 0
    fi

    if ! id -nG "$USER" | grep -qw "www-data" 
    then
        sudo groupadd www-data
        sudo usermod -aG www-data $USER
        echo Due to shell complexities, please return this program.
        exit 0
    fi

}

function InstallNow(){
    for package in "$@"
    do
        if dpkg --get-selections | egrep '^'"$package"'[[:space:]]+.*$' > /dev/null
        then
            echo "Package already installed: $package" | tee WebProgram.log
        else
            sudo apt-get -y install $package | tee WebProgram.log
        fi
    done
}

function UpdateLinux()
{
    #Upgrade from stale install
    sudo apt-get update
    sudo sudo dpkg --configure -a
    sudo apt-get upgrade -y
}

function InstallVms()
{
    sudo apt-get install virtualbox -y

    #Docker compose
    InstallNow apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $release stable"
    InstallNow docker-ce docker-compose
    docker -v
}

function InstallBrowsers(){

    InstallNow chromium-browser
    
    #chrome
    InstallNow libxss1 libappindicator1 libindicator7

    if ! dpkg --get-selections | egrep '^'"google-chrome-stable"'[[:space:]]+.*$' > /dev/null
    then
        cd ~/Downloads
        wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
        sudo apt install ./google-chrome*.deb
    else
        echo "Package already installed: google-chrome-stable"
    fi
}



function SetupSsh()
{
    if [ ! -f ~/.ssh/id_rsa ] 
    then
        echo Setting up SSH Keys. Press enter a bunch...
        ssh-keygen
    fi
}

function InstallEditors(){

    InstallNow netbeans sublime-text snapd git
    #netbeans dies with ipv6. disabled for linux as a whole. the workarounds as default_java_options in /etc/netbetbeans.cfg don't work well either
    sysctl -w net.ipv6.conf.all.disable_ipv6=1
    sysctl -w net.ipv6.conf.default.disable_ipv6=1

        
    sudo snap install atom --classic
}

function InstallPhp(){
    InstallNow python-software-properties
    #add-apt-repository ppa:ondrej/php
    apt-get update
    InstallNow apache2 libapache2-mod-php7.2
    sudo apt-get install php php-cli php-mbstring php-xml
    

    if ! which composer 
    then
        curl -sS https://getcomposer.org/installer | php
        sudo mv composer.phar /usr/local/bin/composer
        sudo chmod +x /usr/local/bin/composer
    fi

    cd /var/www/
    sudo chown $USER:www-data /var/www
    sudo chmod 775 /var/www
    if [ ! -d /var/www/laravel ] 
    then

        sudo usermod -aG www-data $USER
        git clone https://github.com/laravel/laravel.git
        cd /var/www/laravel
        composer install
        chown -R www-data.www-data /var/www/laravel
        chmod -R 755 /var/www/laravel
        chmod -R 777 /var/www/laravel/storage
        mv .env.example .env
        php artisan key:generate


        cat << EOL
CREATE DATABASE laravel;
GRANT ALL ON laravel.* to 'laravel'@'localhost' IDENTIFIED BY 'secret';
FLUSH PRIVILEGES;
quit
EOL
        echo press enter
        read a

        subl /var/www/laravel/.env        

cat << EOL
<VirtualHost *:80>

        ServerAdmin webmaster@localhost
        DocumentRoot /var/www/laravel/public

        <Directory />
                Options FollowSymLinks
                AllowOverride None
        </Directory>
        <Directory /var/www/laravel>
                AllowOverride All
        </Directory>

        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined

</VirtualHost>
EOL

        subl /etc/apache2/sites-enabled/000-default.conf
        sudo service apache2 restart

    fi
}

function Main
{
    AddGroupsFirst
    UpdateLinux
    InstallVms
    InstallBrowsers
    SetupSsh
    InstallEditors
    InstallPhp
}

Main
