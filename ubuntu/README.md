# ubuntu : create user

~~~
adduser newusername
~~~

## append sudo group
~~~
usermod -aG sudo newusername
~~~

# ubuntu java environment

## java
~~~
$ sudo apt-get update
$ sudo apt-get install openjdk-8-jdk
$ java -version
$ which java
$ readlink -f {which java directory}
$ sudo vi /etc/profile

export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export PATH=$JAVA_HOME/bin;$PATH
export CLASS_PATH=$JAVA_HOME/lib;$CLASS_PATH

$ source /etc/profile
$ echo $CLASS_PATH
~~~

## jenkins
~~~
$ wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo apt-key add -
$ echo deb http://pkg.jenkins.io/debian-stable binary/ | sudo tee /etc/apt/sources.list.d/jenkins.list
$ sudo apt-get update
$ sudo apt-get install jenkins
$ sudo systemctl start jenkins
$ sudo vi /etc/default/jenkins

  HTTP_PORT=8080

$ sudo systemctl restart jenkins
$ sudo cat /var/lib/jenkins/secrets/initialAdminPassword

  {copy password}

$ sudo systemctl restart jenkins
~~~

- connect browser
- paste password
- install suggested plugins or select plugin to install
- create first admin user
- instance configuration
- Jenkins Management > Jenkins Tool Configuration
~~~
$ echo $JAVA_HOME
~~~
- JDK config

~~~
$ which git
~~~
- git config

~~~
$ mvn -version
~~~
- maven config
- save


## jenkins github ssh
~~~
$ sudo -u jenkins /bin/bash
~~~



### jenkins upgrade
```
cd /usr/share/jenkins

sudo service jenkins stop

sudo mv jenkins.war jenkins.war.old

sudo wget https://updates.jenkins-ci.org/latest/jenkins.war

sudo service jenkins start
```

### jenkins.service java version
##### version swich : 11 <-> 17
```
$ cd /usr/bin
$ ll java
lrwxrwxrwx 1 root root 22 Jul  6  2021 java -> /etc/alternatives/java*

$ cd /etc/alternatives
$ ll java
lrwxrwxrwx 1 root root 43 Nov  8 14:20 java -> /usr/lib/jvm/java-17-openjdk-amd64/bin/java*

$ update-alternatives --config java

There are 3 choices for the alternative java (providing /usr/bin/java).

  Selection    Path                                            Priority   Status
------------------------------------------------------------
* 0            /usr/lib/jvm/java-17-openjdk-amd64/bin/java      1711      auto mode
  1            /usr/lib/jvm/java-11-openjdk-amd64/bin/java      1111      manual mode
  2            /usr/lib/jvm/java-17-openjdk-amd64/bin/java      1711      manual mode
  3            /usr/lib/jvm/java-8-openjdk-amd64/jre/bin/java   1081      manual mode

Press <enter> to keep the current choice[*], or type selection number: 1
update-alternatives: using /usr/lib/jvm/java-11-openjdk-amd64/bin/java to provide /usr/bin/java (java) in manual mode

$ ll java
lrwxrwxrwx 1 root root 43 Nov  8 14:23 java -> /usr/lib/jvm/java-11-openjdk-amd64/bin/java*

```


## nginx
~~~
$ sudo apt-get update
$ sudo apt-get install nginx
$ sudo systemctl start nginx
~~~


## maven (mac os)
- https://maven.apache.org/download.cgi
- download *.tar.gz file
- decompress downloaded file
- move to Library directory
- vi ./.zshrc
~~~
export MVN_HOME=${HOME}/Library/..{decompresed directory}
export PATH=$MVN_HOME:${PATH}
~~~
- save profile
- source ~/.zshrc
- mvn -version

## maven (ubuntu)
~~~
$ mvn -version
~~~

if it is not
~~~
$ sudo apt install maven
~~~

## mysql( version 8 =< )
~~~
$ sudo apt-get update
$ sudo apt-get install mysql-server
$ mysql --version
$ sudo mysql -u root -p

mysql> alter user 'root'@'localhost' identified with mysql_native_password by '1234';
mysql> select Host, User, authentication_string from user;
mysql> flush privileges;
mysql> exit;

$ cd /etc/mysql/mysql.conf.d
### not mysql.cnf
$ sudo vi mysqld.cnf

  bind-address = 0.0.0.0

### save

$ sudo service mysql restart
$ sudo mysql -u root -p

mysql> update user set Host='%' where User='root';
mysql> exit;
~~~


## nodejs
~~~
$ curl -fsSL https://deb.nodesource.com/setup_14.x | bash -
$ apt-get install -y nodejs
~~~

### configuration for jenkins
```
$ cd /etc/sudoers.d
$ sudo vi jenkins

  jenkins ALL=(ALL) NOPASSWD:ALL

$ sudo -u jenkins /bin/bash
$ node --version
$ exit

```

### change runlevel
```
# 0 poweroff.target 
# 1 rescue.target 
# 2, 3, 4 multi-user.target 
# 5 graphical.target
# 6 reboot.target

$ sudo systemctl set-default multi-user.target
Created symlink /etc/systemd/system/default.target → /lib/systemd/system/multi-user.target.
```