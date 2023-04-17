```sh
$ sudo apt-get update
$ sudo apt-get install mysql-server
```

```
... installing messages ...\
.\
.\
.\
reading /usr/share/mecab/dic/ipadic/Verb.csv ... 130750\
emitting double-array: 100% |###########################################| \
reading /usr/share/mecab/dic/ipadic/matrix.def ... 1316x1316\
emitting matrix      : 100% |###########################################| \
\
done!\
update-alternatives: using /var/lib/mecab/dic/ipadic-utf8 to provide /var/lib/mecab/dic/debian (mecab-dictionary) in auto mode\
Setting up mysql-server-8.0 (8.0.31-0ubuntu0.20.04.1) ...\
update-alternatives: using /etc/mysql/mysql.cnf to provide /etc/mysql/my.cnf (my.cnf) in auto mode\
Renaming removed key_buffer and myisam-recover options (if present)\
mysqld will log errors to /var/log/mysql/error.log\
\
mysqld is running as pid 3733487\
Created symlink /etc/systemd/system/multi-user.target.wants/mysql.service → /lib/systemd/system/mysql.service.\
Setting up mysql-server (8.0.31-0ubuntu0.20.04.1) ...\
Processing triggers for systemd (245.4-4ubuntu3.17) ...\
Processing triggers for man-db (2.9.1-1) ...\
Processing triggers for libc-bin (2.31-0ubuntu9.9) ...\
```

```sh
$ mysql --version
mysql  Ver 8.0.31-0ubuntu0.20.04.1 for Linux on x86_64 ((Ubuntu))
```

```sh
$ mysql
```

```
mysql> use mysql;
  changed database;

mysql> alter user 'root'@'localhost' identified with mysql_native_password by '1234';
  Query OK, 0 rows affected (0.07 sec)

mysql> create user 'hsmirae'@'localhost' identified by '1234';
  Query OK, 0 rows affected (0.04 sec)

mysql> grant create, alter, drop, insert, update, delete,select, references, reload on *.* to 'hsmirae'@'localhost' with grant option;
  Query OK, 0 rows affected (0.10 sec)

mysql> flush privileges;
  Query OK, 0 rows affected (0.18 sec)

mysql> exit;
  Bye

$
```

```
$ cd /etc/mysql/mysql.conf.d

$ vi mysqld.cnf

  bind-address = 0.0.0.0 #change address

  :wq!

$ service mysql restart
```

```
$ mysql -u root -p

mysql> update user set Host='%' where User='hsmirae';
Query OK, 1 row affected (0.13 sec)
Rows matched: 1  Changed: 1  Warnings: 0

mysql> exit;
Bye

$ service mysql restart

```
