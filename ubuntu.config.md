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
- create first admin user (jenkinsPassw0rd!)
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