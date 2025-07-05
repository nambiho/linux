# Rocky linux 9

# install key
### change display
- "ctrl + alt + 1" ~ "ctrl + alt + 6"

# RAID
~~~
$ lsblk -f
$ fdisk /dev/sda
    d
    n
    t
    29
    w

    # fdisk /dev/sdb sdc sdd


$ mdadm --create /dev/md0 --level=1 --raid-device=2 /dev/sd[a-b]1
$ mdadm --create /dev/md1 --level=1 --raid-device=2 /dev/sd[c-d]1
$ mdadm --detail --scan
$ cat /proc/mdstat
$ mkfs.xfs /dev/md0
$ mks.xfs /dev/md1
$ rpm --checksig ~~.rpm
~~~

[create raid](https://tpcable.co.kr/96)
[delete raid](https://riric-technology.tistory.com/14)
[fdisk](https://www.cyberciti.biz/faq/linux-disk-format/)
[disk](https://discussion.fedoraproject.org/t/fedora-live-install-to-hard-drive-duplicate-uuid-issue/81136/4)
[install](https://blog.dalso.org/article/rocky-linux-9-%EC%84%A4%EC%B9%98%ED%95%98%EA%B8%B0)
[install](https://ansan-survivor.tistory.com/516)
[raid card update](https://firstit.tistory.com/2)
[hpe raid](https://tuxfixer.com/raid-1-configuration-on-hp-proliant-gen-9-server-using-hp-ssa/)
[rpm](https://www.lesstif.com/system-admin/rpm-command-7635004.html)
[rpm](https://ko.linux-console.net/?p=857#gsc.tab=0)


# ftp
~~~
$ dnf -y install vsftpd
$ systemctl enabled vsftpd
$ systemctl restart vsftpd
$ firewall-cmd --permanent --zone=public --add-service=ftp
$ firewall-cmd --reload
$ firewall-cmd --list-all
~~~

# fail2ban
[ref 1](https://ko.linux-console.net/?p=6629#gsc.tab=0)
[ref 2](https://idroot.us/install-fail2ban-rocky-linux-9/)
~~~
$ dnf -y update
$ dnf -y install dnf-utils
$ dnf -y install epel-release
$ dnf -y install fail2ban
$ systemctl stop fail2ban
$ cd /etc/fail2ban
$ cp jail.conf jail.local
$ vi jail.local
    [Default]
    bantime = 60m
    [sshd]
    enabled = true
$ systemctl enable fail2ban
$ systemctl start fail2ban
~~~

# Docker
[ref 1](https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-on-rocky-linux-9)
[ref 2](https://www.uname.in/209)
[ref 3](https://ko.linux-console.net/?p=6553#gsc.tab=0)
~~~
$ dnf check-update
$ dnf -y remove podman containers-common
$ dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
$ dnf -y install docker-ce docker-ce-cli containerd.io
$ systemctl start docker
$ systemctl status docker
$ systemctl enable docker
$ usermod -aG docker $(whoami)
~~~


# Mongodb
[ref 1](https://idroot.us/install-mongodb-rocky-linux-9/)
[ref 2](https://ko.linux-console.net/?p=4100#gsc.tab=0)
[ref 3](https://github.com/mongodb/mongodb-selinux)
~~~
$ cd /etc/yum.repo.d
$ vi mongodb-org-6.0.repo
    [mongodb-org-6.0]
    name=MongoDB Repository
    baseurl=https://repo.mongodb.org/yum/redhat/9Server/mongodb-org/6.0/x86_64/
    gpgcheck=1
    enabled=1
    gpgkey=https://pgp.mongodb.com/server-6.0.asc
$ dnf -y install mongodb-org
$ mongod --version
$ systemctl start mongod
$ systemctl enable mongod
$ mongosh
~~~

# install java
[ref 1](https://ko.linux-console.net/?p=3214#gsc.tab=0)
~~~
$ dnf -y install java-11-openjdk
$ dnf -y install java-17-openjdk
$ alternatives --list
$ alternatives --config java
~~~

# nodejs
[ref](https://www.digitalocean.com/community/tutorials/how-to-install-node-js-on-rocky-linux-8)
~~~
$ dnf -y install nodejs

$ cd /data/nodejs
$ curl -sL https://rpm.nodesource.com/setup_18.x -o nodesource_setup.sh
$ bash nodesource_setup.sh
$ dnf -y remove nodejs
$ dnf -y install nodejs
$ node -v
~~~

[ref](https://forums.rockylinux.org/t/install-npm-and-nodejs/5974/2)
~~~
$ dnf module list nodejs
$ dnf module install nodejs:18
~~~
### change version
~~~
$ dnf module reset nodejs
$ dnf module install nodejs:20
~~~

# git
[ref](https://www.linuxcapable.com/how-to-install-git-on-rocky-linux/)
~~~
$ dnf -y install git
~~~

# gitea
[ref](https://docs.gitea.com/installation/install-from-binary)
~~~
$ cd /data/source
$ mkdir gitea
$ cd gitea
$ wget -O gitea https://dl.gitea.com/gitea/1.21.2/gitea-1.21.2-linux-amd64
$ chmod +x gitea
$ groupadd --system git
$ adduser --system --shell /bin/bash --comment 'Git Version Control' --gid git --home-dir /home/git --create-home git
$ mkdir -p /var/lib/gitea/{custom,data,log}
$ chown -R git:git /var/lib/gitea/
$ chmod -R 750 /var/lib/gitea/
$ mkdir /etc/gitea
$ chown root:git /etc/gitea
$ chmod 770 /etc/gitea
$ vi ~/.bash_profile
    GITEA_WORK_DIR=/var/lib/gitea/
    export GITEA_WORK_DIR
$ . ~/.bash_profile
$ cp gitea /usr/local/bin/gitea
$ touch /usr/lib/systemd/system/gitea.service
    [copy & paste] https://github.com/go-gitea/gitea/blob/release/v1.21/contrib/systemd/gitea.service
$ systemctl status gitea
$ systemctl enable gitea
$ systemctl start gitea
~~~
- http://[server ip]:3000
- environment gitea & save
- changed work directory from "/var/lib/gitea" to "/data/gitea"
### config gitea.hsmirae.com
~~~
$ semanage permissive -a httpd_t
$ cd /etc/nginx/conf.d
$ vi gitea.hsmirae.com.conf
$ systemctl stop nginx
$ systemctl start nginx
~~~


# nginx
[ref](https://www.digitalocean.com/community/tutorials/how-to-install-nginx-on-rocky-linux-8)
~~~
$ dnf -y install nginx
$ firewall-cmd --zone=public --permanent --add-server=http
$ firewall-cmd --zone=public --permanent --add-server=https
$ firewall-cmd --reload
$ systemctl start nginx
$ systelctl enable nginx
~~~


# letsencrypt
~~~
$ dnf install -y certbot python3-certbot-nginx
$ certbot --nginx -d hsmirae.com
$ 0 */12 * * * root test -x /usr/bin/certbot -a \! -d /run/systemd/system && perl -e 'sleep int(rand(43200))' && certbot -q renew
~~~


# mysql
[ref 1](https://wiki.crowncloud.net/?How_to_Install_MySQL_on_Rocky_Linux_9)
[ref 2](https://www.digitalocean.com/community/tutorials/how-to-install-mysql-on-rocky-linux-9)
[ref 3](https://www.teckassist.com/installing-mysql-on-rocky-linux-9-a-step-by-step-guide/)
~~~
$ dnf -y install mysql mysql-server
$ systemctl stop mysqld
$ cd /var/lib/mysql
$ rsync -av /var/lib/mysql/* /data/mysql/
$ cd /etc/my.cnf.d
$ vi mysql.server.cnf
    [mysqld]
    datadir=/data/mysql
    socket=/data/mysql/mysql.sock
    skip-name-resolve=on
$ vi client.cnf
    [client]
    socket=/data/mysql/mysql.sock
$ semanage fcontext -l | grep mysqld
$ semanage fcontext -a -t mysqld_db_t "/data/mysql(-files|-keyring)?(/.*)?"
$ semanage fcontext -l | grep mysqld
$ restorecon -R /data/mysql
$ systemctl start mysqld

$ mysql_secure_installation

    Securing the MySQL server deployment.

    Connecting to MySQL using a blank password.

    VALIDATE PASSWORD COMPONENT can be used to test passwords
    and improve security. It checks the strength of password
    and allows the users to set only those passwords which are
    secure enough. Would you like to setup VALIDATE PASSWORD component?

    Press y|Y for Yes, any other key for No: y

    There are three levels of password validation policy:

    LOW    Length >= 8
    MEDIUM Length >= 8, numeric, mixed case, and special characters
    STRONG Length >= 8, numeric, mixed case, special characters and dictionary                  file

    Please enter 0 = LOW, 1 = MEDIUM and 2 = STRONG: 1
    Please set the password for root here.

    New password: 

    Re-enter new password: 

    Estimated strength of the password: 100 
    Do you wish to continue with the password provided?(Press y|Y for Yes, any other key for No) : y
    By default, a MySQL installation has an anonymous user,
    allowing anyone to log into MySQL without having to have
    a user account created for them. This is intended only for
    testing, and to make the installation go a bit smoother.
    You should remove them before moving into a production
    environment.

    Remove anonymous users? (Press y|Y for Yes, any other key for No) : y
    Success.


    Normally, root should only be allowed to connect from
    'localhost'. This ensures that someone cannot guess at
    the root password from the network.

    Disallow root login remotely? (Press y|Y for Yes, any other key for No) : y
    Success.

    By default, MySQL comes with a database named 'test' that
    anyone can access. This is also intended only for testing,
    and should be removed before moving into a production
    environment.


    Remove test database and access to it? (Press y|Y for Yes, any other key for No) : 

    ... skipping.
    Reloading the privilege tables will ensure that all changes
    made so far will take effect immediately.

    Reload privilege tables now? (Press y|Y for Yes, any other key for No) : y
    Success.

    All done! 

$ mysql -u root

mysql> alter user 'root'@'localhost' identified with mysql_native_password by '1234';
mysql> create user 'root'@'%' identified by '1234';
mysql> grant all on *.* to 'root'@'%' with grant option;
mysql> flush privileges;
~~~

# Domino
~~~
$ dnf -y update
$ dnf -y install gdb
$ cd /etc/security
$ vi limits.conf
    *       hard    nofile  60000
    *       soft    nofile  60000
    root   hard    nofile  60000
    root   soft    nofile  60000

$ cd /data/source/domino/domino14
$ tar -xvf Domino.tar
$ cd linux64
$ adduser notes -p [user password]
$ ./install
$ cd /data/notesdata

$ firewall-cmd --permanent --zone=public --add-port=3003/tcp
$ firewall-cmd --reload
$ firewall-cmd --list-all

$ /opt/hcl/domino/bin/server -listen

    # remote setting

$ ./server

$ cd /etc/rc.d
$ vi rc.local
    su - notes -c "domstart"
$ chmod +x rc.local
~~~

### domino command script
[ref 1](https://nashcom.github.io/domino-startscript/startscript/quickstart/)
[ref 2](https://www.nashcom.de/nshweb/pages/startscript.htm)
~~~
$ cd /src/domino
$ mkdir script
$ cd script
$ git clone https://github.com/nashcom/domino-startscript.git
$ cd domino-startscript

	(replace DOMINO_DATA_PATH in DominoOneTouchSetup.sh, entrypoint.sh, install_script, rc_domino_script)

$ ./install_script

======== ./sysconfig/rc_domino_config

Installing StartScript & Config

[/usr/bin/domino] installed
[/opt/nashcom/startscript/rc_domino_script] installed
[/opt/nashcom/startscript/rc_domino_readme.txt] installed
[/opt/nashcom/startscript/nshinfo.sh] installed
[/opt/nashcom/startscript/DominoOneTouchSetup.sh] installed
[/opt/nashcom/startscript/nshcfg.sh] installed
[/opt/nashcom/startscript/domino-example.cfg] installed
[/opt/nashcom/startscript/rc_domino_config_4.0.2.txt] installed
[/etc/sysconfig/rc_domino_config] installed
[/data1/hcl/notesdata/systemdbs.ind] installed
[/etc/sysconfig/domino.cfg] installed
[/etc/systemd/system/domino.service] installed

Enabling Service
Created symlink /etc/systemd/system/multi-user.target.wants/domino.service → /etc/systemd/system/domino.service.


Done

~~~

# Domino REST API
[Reference](https://opensource.hcltechsw.com/Domino-rest-api/tutorial/quickstart.html)
[opensource](https://opensource.hcltechsw.com/howto/database/enablingadb.html)
[uninstall](https://opensource.hcltechsw.com/Domino-rest-api/howto/install/uninstall.html)
~~~
$ tar -xvzf ./Domino_REST_API_14_tar.gz -C ./restapi
$ cd restapi
$ java -jar ./restapiInstall-r14.jar -d="/data/notesdata" -i="/data/notesdata/notes.ini" -r="/opt/hcl/restapi" -p="/opt/hcl/domino/notes/latest/linux" -a
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


# Jenkins
[Ref 1](https://www.linuxbuzz.com/install-jenkins-on-rhel-rockylinux-almalinux/)
[Ref 2](https://www.howtoforge.com/how-to-install-jenkins-on-rocky-linux-9/)
~~~
$ wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
$ rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
$ dnf -y install jenkins
$ systemctl daemon-reload
$ systemctl enable jenkins
$ firewall-cmd --permanent --zone=public --add-port=50000/tcp
$ firewall-cmd --reload
$ firewall-cmd --list-all
$ systemctl start jenkins
$ cat /var/lib/jenkins/secrets/initialAdminPassword
~~~
- open http://[server]:50000
- config jenkins


# Python
### python3.11.11
~~~
$ dnf install python3.11 -y
$ python
~~~
### alternatives
~~~
$ alternatives --install /usr/bin/python python /usr/bin/python3.9 1
$ alternatives --install /usr/bin/python python /usr/bin/python3.11 2
$ alternatives --config python
~~~
### pip3.11
~~~
$ dnf install python3.11-pip
~~~
### pip for user
~~~
$ dnf remove python3.11-pip
$ cd /data/source/python
$ wget https://bootstrap.pypa.io/get-pip.py
$ python3 get-pip.py --user
~~~

