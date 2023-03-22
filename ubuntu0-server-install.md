# Server Information
- server : ubuntu0
- pick name : hsmirae
- password : 
- root pass : 
  
# SSH
### install openssh-server :
~~~
$ sudo apt-get install openssh-server
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

# Shutdown
~~~
$ poweroff
~~~