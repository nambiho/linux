# CentOS 7

- download centos 7
- make boot disk
- install

```
$ yum update
```

# firewall
~~~
$ firewall-cmd --permanent --zone=public --add-port=80/tcp
$ firewall-cmd --permanent --zone=public --add-port=1352/tcp
$ firewall-cmd --permanent --zone=public --add-port=8080/tcp
$ firewall-cmd --permanent --zone=public --add-port=9000/tcp
$ firewall-cmd --permanent --zone=public --add-port=3306/tcp
$ firewall-cmd --permanent --zone=public --add-port=8585/tcp
$ firewall-cmd --reload
$ firewall-cmd --list-all
~~~

# Domino Server
~~~
$ cd ~
$ mkdir /tmp/domino/server
$ mkdir /tmp/domino/langpack
$ cd /mnt/usb
$ tar -xvf ./Domino_12.0.2_Linux_English.tar -C /tmp/domino/server
$ tar -xvf ./Domino_12.0.2_SLP_Korean.tar -C /tmp/domino/langpack
$ cd /tmp/domino/server
$ vi /etc/security/limits.conf

    *       hard    nofile  60000
    *       soft    nofile  60000
    root   hard    nofile  60000
    root   hard    nofile  60000

$ ./install
$ adduser notes -p password
$ addgroup notes
$ usermod -a -G notes notes
$ cd /tmp/domino/langpack
$ ./LNXDomLP -i silent -DSILENT_INI_PATH="/hdd/ext1/notesdata/LPSilent.ini"
$ cd /opt/hcl/domino/bin
$ su - notes
$ ./server -listen

    # remote setting

$ ./server
~~~

# Nodejs
~~~
$ wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
$ . ~/.bashrc
$ nvm install node
$ node --version
~~~

# git
~~~
$ yum remove git
$ yum install git
~~~

# nginx
~~~
$ yum install epel-release
$ yum update
$ yum install -y nginx
$ nginx -version
$ vi /etc/nginx/conf.d/default.conf
$ systemctl start nginx
~~~

# openssl
~~~
$ yum install perl-IPC-Cmd
$ yum groupinstall "Development Tools"
$ yum remove openssl

$ cd /tmp
$ wget https://openssl.org/source/openssl-3.0.8.tar.gz
$ tar -xvf openssl-3.0.8.tar.gz
$ mv openssl-3.0.8 /usr/src/openssl-3.0.8
$ cd /usr/src/openssl-3.0.8
$ ./config --prefix=/usr/local/openssl shared
$ make
$ make install
$ make test
$ ln -s /usr/local/openssl/bin/openssl /usr/bin/openssl
$ ln -s /usr/local/openssl/include/openssl /usr/include/openssl
$ ln -s /usr/local/openssl/lib64/libssl.so.3 /usr/lib64/libssl.so.3
$ ln -s /usr/local/openssl/lib64/libcrypto.so.3 /usr/lib64/libcrypto.so.3
~~~


# mysql
- [Site](https://www.digitalocean.com/community/tutorials/how-to-install-mysql-on-centos-7)
- [Mysql version](https://dev.mysql.com/downloads/repo/yum/)
~~~
$ cd /tmp
$ curl -sSLO https://dev.mysql.com/get/mysql80-community-release-el7-5.noarch.rpm
$ md5sum mysql80-community-release-el7-5.noarch.rpm 
    e2bd920ba15cd3d651c1547661c60c7c  mysql80-community-release-el7-5.noarch.rpm
$ rpm -ivh mysql80-community-release-el7-5.noarch.rpm
$ yum install mysql-server
$ mysql --version
$ systemctl start mysqld
$ systemctl status mysqld
$ grep 'temporary password' /var/log/mysqld.log
    2023-04-10T09:08:14.127724Z 6 [Note] [MY-010454] [Server] A temporary password is generated for root@localhost: gNFuunwa=9+l
$ mysql -u root -p

mysql> set global validate_password.policy=LOW;
mysql> UPDATE mysql.user SET authentication_string='user password' WHERE User='root';


$ rsync -av /var/lib/mysql/* /hdd/ext1/mysql/
$ cd /etc/
$ vi my.cnf

    datadir=/hdd/ext1/mysql/
    socket=/hdd/ext1/mysql/mysql.sock

    [client]
    socket=/hdd/ext1/mysql/mysql.sock

$ yum install policycoreutils-python
$ semanage fcontext -l | grep mysql
$ semanage fcontext -a -t mysqld_db_t "/hdd/ext1/mysql(/.*)?"
$ restorecon -R /hdd/ext1/mysql
$ systemctl start mysqld
~~~

# docker
- [page](https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-on-centos-7)
~~~
$ yum check-updqte
$ curl -fsSL https://get.docker.com/ | sh
$ docker version
$ systemctl start docker
~~~

# vault
- [page](https://blog.naver.com/PostView.nhn?blogId=wideeyed&logNo=222084349160)
```
$ yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
$ yum -y install vault
$ vault version
```

# mongodb
- [page](https://www.mongodb.com/docs/manual/tutorial/install-mongodb-on-red-hat/)
```
$ cd /etc/yum.repos.d
$ vi mongodb.repo

    [mongodb-org-6.0]
    name=MongoDB Repository
    baseurl=https://repo.mongodb.org/yum/redhat/$releasever/mongodb-org/6.0/x86_64/
    gpgcheck=1
    enabled=1
    gpgkey=https://www.mongodb.org/static/pgp/server-6.0.asc

$ yum -y install mongodb-org
$ systemctl start mongod
```

# java
```
$ cd /hdd/ext1/jar
$ nohup java -jar test.jar &
$ tail -f nohup.out

# without log
$ nohup java -jar test.jar 1>/dev/null 2>&1 &

# stop
$ ps -ef | grep java
$ kill -9 [java pid]
```
