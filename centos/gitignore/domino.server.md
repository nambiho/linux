https://help.hcltechsw.com/domino/12.0.2/admin/inst_installingdominoservers_c.html

# Domino Server
```
$ cd ~
$ mkdir /tmp/domino/server
$ mkdir /tmp/domino/langpack
$ cd /mnt/usb
$ tar -xvf ./Domino_12.0.2_Linux_English.tar -C /tmp/domino/server
$ tar -xvf ./Domino_12.0.2_SLP_Korean.tar -C /tmp/domino/langpack
$ cd /tmp/domino/server
$ ./install


1) Login as the appropriate user: notes
2) Change to data directory using the command: cd /hdd/ext1/domino/data
3) Configure the server using the command: /opt/hcl/domino/bin/server
    To configure server remotely, the remote server setup tools is required
    and you cna use the command: /opt/hcl/domino/bin/server -listen'
    After issuing the command, additional instructions will appear for remote
    server setup. For additional details see the section 'Using the Domino Server
    Setup remotely' in the HCL Domino Administration Help Documentation.


$ ./server
WARNING: the maximum number of file handles (ulimit -n)
           allowed for Domino is 4096.
         Recommendation is to set the allowable maximum to 60000.
/proc/sys/kernel/sem has been set to "250       256000  32      1024".
/proc/sys/net/ipv4/tcp_fin_timeout has been set to "15".
/proc/sys/net/ipv4/tcp_max_syn_backlog has been set to "16384".
/proc/sys/net/ipv4/tcp_tw_reuse has been set to "1".
/proc/sys/net/ipv4/ip_local_port_range has been set to "1024    65535".
./java -ss512k -Xmso5M -cp jhall.jar:cfgdomserver.jar:./ndext/ibmdirectoryservices.jar lotus.domino.setup.WizardManagerDomino -data /hdd/ext1/domino/data
*Warning all runtime debug info will be logged to /hdd/ext1/domino/data/setuplog.txt
Please edit your shell's DISPLAY environment variable to reflect an unlocked terminal that you would like to launch the Domino Setup Program on.


$ vi /etc/security/limits.conf

    *       hard    nofile  60000
    *       soft    nofile  60000

    root   hard    nofile  60000
    root   hard    nofile  60000


$ alternatives --install /usr/bin/java java /usr/lib/jvm/jdk-17.0.6+10/bin/java 1
$ alternatives --install /usr/bin/javac javac /usr/lib/jvm/jdk-17.0.6+10/bin/javac 1
```

- [firewall-cmd]{https://sd23w.tistory.com/465}