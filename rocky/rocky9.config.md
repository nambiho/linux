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

# git
[ref](https://www.linuxcapable.com/how-to-install-git-on-rocky-linux/)
~~~
$ dnf -y install git
~~~

# nginx
[ref](https://www.digitalocean.com/community/tutorials/how-to-install-nginx-on-rocky-linux-8)
~~~
$ dnf -y install nginx
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

$ cd /data/source/domino/domino12
$ tar -xvf Domino.tar
$ cd Domino
$ adduser notes -p [user password]
$ ./install
$ ./server -listen

    # remote setting

$ ./server
~~~
