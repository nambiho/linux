# Server Information
- server : ubuntu0
- pick name : hsmirae
- password : 
- root pass : 
  
# SSH
### install openssh-server :
~~~
$ sudo apt-get install openssh-server
$ apt install net-tools
~~~

### check
- root password
- PermitRootLogin prohibit-password -> PermitRootLogin yes
- PasswordAuthentication no -> PasswordAuthentication yes
- UseLogin no -> UseLogin yes

### run
~~~
$ ssh -p 22 root@192.168.0.23 -v
~~~


# memory check
~~~
$ dmidecode -t memory | more
$ free -h
~~~


# port check
~~~
$ netstat -tnlp
$ ss -lntu
$ nmap -n -PN -sT -sU -p- localhost
$ lsof -i
~~~


# service list
~~~
$ service --status-all
$ ps -ef
~~~

# apt package check
~~~
$ apt-cache search [keyword]
$ dpkg -l
$ dpkg -l nginx
~~~

# java
### install java
~~~
$ cd /etc/apt
$ mkdir keyrings
$ apt-get update
$ wget -O - https://packages.adoptium.net/artifactory/api/gpg/key/public | tee /etc/apt/keyrings/adoptium.asc
$ echo "deb [signed-by=/etc/apt/keyrings/adoptium.asc] https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" | tee /etc/apt/sources.list.d/adoptium.list
$ apt-get install temurin-17.jdk
$ vi /etc/profile

    export JAVA_HOME=$(dirname $(dirname $(readlink -f /usr/bin/java)))
    export PATH=$PATH:$JAVA_HOME/bin

$ echo $JAVA_HOME
~~~

### delete java
~~~
$ sudo apt-get purge temurin*
~~~



# Docker
~~~
$ sudo apt-get remove docker docker-engine docker.io containerd runc
$ sudo apt-get update
$ sudo apt-get install ca-certificates curl gnupg
$ sudo mkdir -m 0755 -p /etc/apt/keyrings
$ curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
$ echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
$ sudo apt-get update
$ sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
$ sudo docker run hello-world
~~~


# nginx
~~~
$ apt install nginx
~~~

### configuration nginx
~~~
$ cd /etc/nginx/sites-available
$ vi miraean.site

  # server setting

$ service nginx restart
~~~


# nodejs
[Source github](https://deb.nodesource.com)
~~~
$ curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
$ apt-get update
$ sudo apt-get install -y nodejs
$ node --version
~~~

# mysql
~~~
$ apt update
$ apt install mysql-server
$ mysql --version
~~~

# certbot
### required
- registed url in dns

### console command for nginx
- $ sudo certbot certonly --nginx 
- $ sudo certbot --nginx
~~~
$ sudo service snapd stop
$ sudo apt upgrade snapd
$ sudo apt autoremove
$ sudo servie snapd start
$ sudo snap install core
$ sudo snap refresh core
$ sudo snap install --classic certbot
$ sudo ln -s /snap/bin/certbot /usr/bin/certbot
$ sudo ufw allow 443
$ sudo certbot certonly --standalone -d miraean.site

$ tail -f /var/log/letsencrypt/letsencrypt.log
~~~


# Shutdown
~~~
$ poweroff
~~~