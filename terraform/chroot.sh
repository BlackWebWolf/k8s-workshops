#!/bin/bash

#
# This script creates a chrooted user, scp enabled, on an Amazon Linux aws instance
#
# 2017-10-05
#

# change username and password here:
#username="abc"
#password="123456"
#
## create groups
#groupadd sftp
#
## create chrooted user
#useradd -m $username -G sftp
#echo $username:$password | chpasswd
#
## enable password authentication in sshd
#cp /etc/ssh/sshd_config /etc/ssh/sshd_config.before_chroot
#cat /etc/ssh/sshd_config | sed -e "s/PasswordAuthentication no/PasswordAuthentication yes/" > /etc/ssh/temp_sshd_config
#mv -f /etc/ssh/temp_sshd_config /etc/ssh/sshd_config
#
## disable default sftp subsystem configuration in sshd
#sed -e '/Subsystem sftp/ s/^#*/#/' -i /etc/ssh/sshd_config
#
## add sftp subsystem configuration to sshd
#echo "Subsystem sftp internal-sftp" >> /etc/ssh/sshd_config
#echo "Match Group sftp" >> /etc/ssh/sshd_config
#echo "    ChrootDirectory %h" >> /etc/ssh/sshd_config
#echo "    AllowTcpForwarding no" >> /etc/ssh/sshd_config
#
## restart ssh service
#/etc/init.d/sshd restart

# create the chrooted directory structure
mkdir /usr/local/openvpn-as/bin
mkdir /usr/local/openvpn-as/dir
mkdir /usr/local/openvpn-as/usr
mkdir /usr/local/openvpn-as/usr/bin
mkdir /usr/local/openvpn-as/usr/libexec
mkdir /usr/local/openvpn-as/lib/
mkdir /usr/local/openvpn-as/etc
mkdir /usr/local/openvpn-as/dev
mkdir /usr/local/openvpn-as/dev/pts

# copy all dependencies
cp --parents `ldd /bin/bash | cut -d " " -f 3` /usr/local/openvpn-as
cp --parents `ldd /bin/ls | cut -d " " -f 3` /usr/local/openvpn-as/
cp /usr/lib64/libnss3.so /usr/local/openvpn-as/lib64/
cp /usr/lib64/libtic.so.5 /usr/local/openvpn-as/lib64/
cp /lib64/ld-linux-x86-64.so.2 /usr/local/openvpn-as/lib64/
cp /usr/lib64/libssl3.so /usr/local/openvpn-as/lib64/
cp /bin/bash /usr/local/openvpn-as/bin/
cp /bin/ls /usr/local/openvpn-as/bin/
cp /lib64/libnss* /usr/local/openvpn-as/lib64/
cp /usr/lib64/libnss* /usr/local/openvpn-as/usr/lib64/
cp --parents `find . -type f -exec ldd '{}' \; | awk '{print $3}' | sort | uniq | grep -v '('` /usr/local/openvpn-as/
cp -vf /etc/{passwd,group} /usr/local/openvpn-as/etc/
cp -r /etc/ld.so* /usr/local/openvpn-as/etc/

# create non-files
mknod -m 666 /usr/local/openvpn-as/dev/null c 1 3
mknod -m 666 /usr/local/openvpn-as/dev/tty c 5 0
mknod -m 666 /usr/local/openvpn-as/dev/zero c 1 5
mknod -m 666 /usr/local/openvpn-as/dev/random c 1 8
mount --bind /dev/pts /usr/local/openvpn-as/dev/pts

# get the directory permissions right
chown openvpn_as.openvpn_as /usr/local/openvpn-as/. -R
chmod 0755 /usr/local/openvpn-as/bin
chmod 0666 /usr/local/openvpn-as/.bashrc
chown root.root /usr/local/openvpn-as
chmod 0755 /usr/local/openvpn-as

yum --installroot=/usr/local/openvnp_as --releasever= --nogpg --enablerepo=amzn2-core install yum-utils centos-release openssh-clients wget vi nano zip unzip tar mariadb findutils iputils bind-utils yum glibc.i686 nspr ncurses-compat-libs
mknod -m 666 /dev/random c 1 8
mknod -m 666 /dev/urandom c 1 9

ln -s /etc/resolv.conf /usr/local/openvnp_as/etc/resolv.conf
mount
cp /etc/resolv.conf /usr/local/openvnp_as/etc/