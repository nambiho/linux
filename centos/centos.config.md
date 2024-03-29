# CentOS 7

- download centos 7
- make boot disk
- install

```
$ yum update
```


# kernel
- [elrepo](http://elrepo.org/tiki/HomePage)
- [page](https://cjwoov.tistory.com/48)
```
$ uname -msr
$ cat /etc/redhat-release
$ cat /etc/os-release 
$ yum update
$ rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
$ yum install https://www.elrepo.org/elrepo-release-7.el7.elrepo.noarch.rpm
$ yum --enablerepo=elrepo-kernel install kernel-ml kernel-ml-devel
$ grep ^menuentry /boot/grub2/grub.cfg | cut -d "'" -f2

    CentOS Linux (6.3.2-1.el7.elrepo.x86_64) 7 (Core)
    CentOS Linux (3.10.0-1160.90.1.el7.x86_64) 7 (Core)
    CentOS Linux (3.10.0-1160.88.1.el7.x86_64) 7 (Core)
    CentOS Linux (3.10.0-1160.el7.x86_64) 7 (Core)
    CentOS Linux (0-rescue-c37853261cfe4f249ab9a8d5906759f7) 7 (Core)

$ grub2-set-default "CentOS Linux (6.3.2-1.el7.elrepo.x86_64) 7"
$ grub2-editenv list
$ reboot
$ yum -y install yum-utils

# count=* is option.
$ package-cleanup --oldkernels --count=2
```


# firewall
~~~
$ firewall-cmd --permanent --zone=public --add-port=80/tcp
$ firewall-cmd --permanent --zone=public --add-port=1352/tcp
$ firewall-cmd --permanent --zone=public --add-port=8080/tcp
$ firewall-cmd --permanent --zone=public --add-port=9000/tcp
$ firewall-cmd --permanent --zone=public --add-port=3306/tcp
$ firewall-cmd --permanent --zone=public --add-port=8585/tcp
$ firewall-cmd --permanent --zone=public --add-port=30033/tcp
$ firewall-cmd --reload
$ firewall-cmd --list-all
~~~




# ssh & fail2ban
```
$ yum update
$ yum -y install fail2ban
$ systemctl enable fail2ban
$ systemctl start fail2ban
$ tail -f /var/log/fail2ban.log
$ fail2ban-client status

$ vi /etc/fail2ban/jail.conf
    [sshd]
    enabled=true
    maxretry=5

$ vi /etc/ssh/sshd_config
    Port=30033

$ semanage port -a -t ssh_port_t -p tcp 30033
$ systemctl stop sshd
$ systemctl start sshd

# release ip
$ fail2ban-client set sshd unbanip xxx.xxx.xxx.xxx
```




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
    root   soft    nofile  60000

$ adduser notes -p [user password]
#$ groupadd notes
#$ usermod -a -G notes notes
$ ./install
$ cd /tmp/domino/langpack
$ ./LNXDomLP -i silent -DSILENT_INI_PATH="/hdd/ext1/notesdata/LPSilent.ini"
$ cd /opt/hcl/domino/bin
$ su - notes
$ ./server -listen

    # remote setting

$ ./server


# auth run on reboot
$ cd /etc/rc.d
$ vi rc.local
    su - notes -c "domstart"
$ chmod +x rc.local
~~~


# Domino REST API
[Reference](https://opensource.hcltechsw.com/Domino-rest-api/tutorial/quickstart.html)
[opensource](https://opensource.hcltechsw.com/howto/database/enablingadb.html)
[uninstall](https://opensource.hcltechsw.com/Domino-rest-api/howto/install/uninstall.html)
~~~
$ tar -xvzf ./Domino_REST_API_12_tar.gz -C ./Domino_REST_API
$ cd Domino_REST_API
$ java -jar ./restapiInstall-r12.jar -d="/hdd/ext1/notesdata" -i="/hdd/ext1/notesdata/notes.ini" -r="/opt/hcl/restapi" -p="/opt/hcl/domino/notes/latest/linux" -a
$ firewall-cmd --permanent --zone=public --add-port=8880/tcp
$ firewall-cmd --permanent --zone=public --add-port=8886/tcp
$ firewall-cmd --permanent --zone=public --add-port=8889/tcp
$ firewall-cmd --permanent --zone=public --add-port=8890/tcp
$ firewall-cmd --reload
$ firewall-cmd --list-all
~~~

### Open Notes Client
- names.nsf > select Server document
- Security tab
- select member for "Create databases $ templates" item
- save document
- restart server

### Connect to "http://server-url: 8880" on browser
- http://url:8880 접속




# nodejs
~~~
# nvm local
$ wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
$ . ~/.bashrc
$ nvm install node
$ node --version


# global
$ yum update
$ yum install http://opensource.wandisco.com/centos/7/git/x86_64/wandisco-git-release-7-1.noarch.rpm
$ yum -y install nodejs npm
$ node --version
$ npm --version
$ npm i -g npm@9.6.5
$ npm i -g n
$ n v16.20.0
    installing : node-v16.20.0
    mkdir : /usr/local/n/versions/node/16.20.0
    fetch : https://nodejs.org/dist/v16.20.0/node-v16.20.0-linux-x64.tar.xz
    copying : node/16.20.0
    installed : v16.20.0 (with npm 8.19.4)
~~~




# git
~~~
$ yum remove git
$ yum install git

$ cd node
$ mkdir miraean.git
$ git init --bare miraean.git
~~~

#### local pc
```
$ ssh-keygen -t rsa -b 4096 -C "[userid]@xxx.xxx.xxx.xxx"
    Enter file in which to save the key (/Users/nambiho/.ssh/id_rsa): [userid]_id_rsa
    .....

$ ssh-copy-id -i [userid]_id_rsa -p 30033 [userid]@xxx.xxx.xxx.xxx
$ git clone ssh://[userid]@xxx.xxx.xxx.xxx:/hdd/ext1/node/miraean.git
```




# nginx
- [reference](https://gonna-be.tistory.com/20)
~~~
$ yum install epel-release
$ yum update
$ yum install -y nginx
$ nginx -version
$ vi /etc/nginx/conf.d/default.conf
$ systemctl start nginx

# root directory
$ semanage fcontext -a -t httpd_sys_content_t [object]
$ chcon -R -t httpd_sys_content_t [directory]
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




# let's encrypt
- [reference](https://hoing.io/archives/11906)
```
$ cd /etc/nginx/conf.d
$ openssl dhparam -out ssl-dhparams.pem 4096
$ yum -y install epel-release yum-utils
$ yum install certbot certbot-nginx
```




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
    skip-name-resolve=on
    
    [client]
    socket=/hdd/ext1/mysql/mysql.sock

$ yum install policycoreutils-python
$ semanage fcontext -l | grep mysql
$ semanage fcontext -a -t mysqld_db_t "/hdd/ext1/mysql(/.*)?"
$ restorecon -R /hdd/ext1/mysql
$ systemctl start mysqld

$ mysql -u root -p

mysql> show variables like "general_log%";

    +------------------+-----------------------------+
    | Variable_name    | Value                       |
    +------------------+-----------------------------+
    | general_log      | OFF                         |
    | general_log_file | /hdd/ext1/mysql/local.log   |
    +------------------+-----------------------------+
    2 rows in set (0.01 sec)

mysql> set global general_log='ON';
mysql> exit

$ tail -f /hdd/ext1/mysql/local.log
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
- [page](https://www.joinc.co.kr/w/man/12/vault)
- [page](https://blog.outsider.ne.kr/1266)
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



# Redis
```
$ yum -y install redis
$ cd /etc
$ vi redis.conf
    bind 0.0.0.0
    port 60006
    requirepass [password]

$ systemctl start redis
$ systemctl enable redis
$ redis-cli -p 60006

127.0.0.1:60006> AUTH [password]
OK
127.0.0.1:60006> ping
PONG
127.0.0.1:60006> exit
```



# run java application
- [oauth](https://velog.io/@rnqhstlr2297/Spring-Security-OAuth2-%EC%86%8C%EC%85%9C%EB%A1%9C%EA%B7%B8%EC%9D%B8)
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




# log commands
```
$ tail -f /var/log/secure
$ last -f /var/log/btmp | more
$ last -f /var/log/wtmp
$ tail -f /var/log/fail2ban.log
```


# gitea server
- [Reference](https://docs.gitea.com/next/installation/database-prep)
```
$ mysql -u root -p

mysql> SET old_passwords=0;
mysql> create user 'gitea' identified by 'gitea';
mysql> create user 'gitea'@'%' identified by 'gitea';
mysql> create database giteadb character set 'utf8mb4' collate 'utf8mb4_unicode_ci';
Query OK, 1 row affected (0.01 sec)

mysql> grant all privileges on giteadb.* to 'gitea';
Query OK, 0 rows affected (0.01 sec)

mysql> flush privileges;
Query OK, 0 rows affected (0.00 sec)

mysql> grant all privileges on giteadb.* to 'gitea'@'localhost';
Query OK, 0 rows affected, 1 warning (0.01 sec)

mysql> flush privileges;
Query OK, 0 rows affected (0.00 sec)

mysql> exit
Bye

$ wget -O gitea https://dl.gitea.com/gitea/1.19.4/gitea-1.19.4-linux-amd64
$ groupadd --system git
$ adduser --system --shell /bin/bash --comment 'Git Version Control' --gid git --home-dir /home/git --create-home git
$ mkdir -p /var/lib/gitea/{custom,data,indexers,public,log}
$ chown -R git:git /var/lib/gitea/
$ chmod -R 750 /var/lib/gitea/
$ mkdir /etc/gitea
$ chown root:git /etc/gitea
$ chmod 770 /etc/gitea
$ cp gitea /usr/local/bin/gitea
$ touch /etc/systemd/system/gitea.service
$ vi /etc/systemd/system/gitea.service
    ## [Copy & Paste](https://github.com/go-gitea/gitea/blob/main/contrib/systemd/gitea.service)

```

- http://[ip]:3000
- 설정
    git.hsmirae.com
    3003
    gitadmin / gitadmin!



# jenkins
- [Reference](https://www.jenkins.io/doc/book/installing/linux/#red-hat-centos)
~~~
$ wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
$ rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
$ yum install jenkins
$ systemctl enable jenkins
$ vi /usr/lib/systemd/system/jenkins.service

    Environment="JENKINS_PORT=8800"

$ systemctl daemon-reload
$ systemctl start jenkins
$ firewall-cmd --permanent --zone-add=public --add-port=8800/tcp
$ firewall-cmd --reload
~~~

- Browser (localhost:8800)
~~~
$ cat /var/lib/jenkins/secrets/initialAdminPassword
~~~
- input administrator password



