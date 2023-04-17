#!/bin/bash
#
# /etc/init.d/domino
#
### BEGIN INIT INFO
# Provides:          Domino 
# Required-Start:    $syslog $remote_fs $network
# Required-Stop:     $syslog $remote_fs $network
# Default-Start:     3 5
# Default-Stop:      0 1 2 6
# Short-Description: Domino providing IBM Lotus Domino Server
# Description:       Start Domino to provide an IBM Lotus Domino Server
### END INIT INFO
# 

. /etc/init.d/functions
DATADIR=/hdd/ext1/notesdata
RETVAL=0

start() {
	echo -n "Starting Domino Server"
	sudo -u notes /opt/hcl/domino/bin/server "=$DATADIR/notes.ini" -jc -c &
	RETVAL=$?

	# Remember status and be verbose
	echo 
	[ $RETVAL -eq 0 ]
	return $RETVAL
}

stop() {
	echo -n "Shutting down Domino Server"
	sudo -u notes /opt/hcl/domino/bin/server "=$DATADIR/notes.ini" -q
	RETVAL=$?

	# Remember status and be verbose
	RETVAL=0   # have to force this since since there's no way of really 
                        # knowing
	echo
	[ $RETVAL -eq 0 ]
	return $RETVAL
}

restart() {
	# Stop the service and regardless of whether it was running or not, 
        # start it again.
	stop
	start
}

case "$1" in
    start)
	start
	;;
    stop)
	stop
	;;
    restart)
	restart
	;;
    *)
 echo "Usage: $0 {start|stop|restart}"
 exit 1
 ;;
esac
exit $RETVAL