#!/bin/sh
LOGFILE=/var/log/bootstrap-salt-minion.log 

log() {
    message="$@"
    echo $message
    echo $message >>$LOGFILE
}

UNAME=`uname`
if [ "$UNAME" != "Linux" ] ; then
    log "Sorry, this OS is not supported."
    exit 1
fi

set -e
trap "echo Installation failed." EXIT

if [ "$UNAME" = "Linux" ] ; then
    do_with_root() {
        if [ `whoami` = 'root' ] ; then
            RESULT=$($*)
            log $RESULT
        else
            log "Salt requires root privileges to install. Please re-run this script as root."
            exit 1
        fi
    }
 
    if [ -f /etc/lsb-release ] ; then
        OS=$(lsb_release -si)
        CODENAME=$(lsb_release -sc)

        if [ $OS = 'Ubuntu' ]; then
            if [ $CODENAME = 'oneiric' ]; then
                log "Installing for Ubuntu Oneiric."
                do_with_root apt-get update
                do_with_root apt-get -y install python-software-properties
                do_with_root add-apt-repository -y 'deb http://us.archive.ubuntu.com/ubuntu/ oneiric universe'
                do_with_root add-apt-repository -y ppa:saltstack/salt
                do_with_root apt-get update
                do_with_root apt-get -y install msgpack-python salt-minion
                do_with_root add-apt-repository -y --remove 'deb http://us.archive.ubuntu.com/ubuntu/ oneiric universe'
            elif [ $CODENAME = 'lucid' -o $CODENAME = 'precise' ]; then
                log "Installing for Ubuntu Lucid/Precise."
                do_with_root apt-get update
                do_with_root apt-get -y install python-software-properties
                do_with_root add-apt-repository -y ppa:saltstack/salt
		do_with_root apt-get update
                do_with_root apt-get -y install salt-minion
            else
                log "Ubuntu $CODENAME is not supported."
                exit 1
            fi
        elif [ $OS = 'Debian' ]; then
            if [ $CODENAME = 'wheezy' -o $CODENAME = 'jessie' ]; then
                log "Installing for Debian Weezy/Jessie."
                do_with_root apt-get -y install salt-minion
            else
                log "Debian $CODENAME is not supported."
                exit 1
            fi
        else
            log "Debian variant $OS not supported."
            exit 1
        fi
    elif [ -f /etc/debian_version ] ; then
        DVER=$(cat /etc/debian_version)
        if [ $DVER = '6.0'  ]; then
            log "Installing for Debian Squeeze."
            do_with_root echo "deb http://backports.debian.org/debian-backports squeeze-backports main" >> /etc/apt/sources.list.d/backports.list
            do_with_root apt-get update
            do_with_root apt-get -t squeeze-backports -y install salt-minion
        else
            log "Debian version $VER not supported."
            exit 1
        fi
    else
        log "Unable to install. Bootstrapping only supported on Debian/Ubuntu."
        exit 1
    fi
fi

log "Salt has been installed!"
trap - EXIT

