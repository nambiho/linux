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
$ apt-get update
$ wget -O - https://packages.adoptium.net/artifactory/api/gpg/key/public | tee /etc/apt/keyrings/adoptium.asc
$ echo "deb [signed-by=/etc/apt/keyrings/adoptium.asc] https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" | tee /etc/apt/sources.list.d/adoptium.list
$ apt-get install temurin-17.jdk
~~~

### delete java
~~~
$ sudo apt-get purge temurin*
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

# certbot
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
~~~


# Shutdown
~~~
$ poweroff
~~~