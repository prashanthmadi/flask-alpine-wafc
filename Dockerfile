FROM python:2.7.15-alpine3.8

COPY sshd_config /etc/ssh/

RUN apk --update add g++ \
    libffi-dev \
    openssl-dev \
    openssh \
    openrc \
    bash \
    && echo "root:Docker!" | chpasswd \
    && echo "cd /home" >> /etc/bash.bashrc 

# Fixing issues from https://github.com/gliderlabs/docker-alpine/issues/42
RUN  \
    # Tell openrc its running inside a container, till now that has meant LXC
    sed -i 's/#rc_sys=""/rc_sys="lxc"/g' /etc/rc.conf &&\
    # Tell openrc loopback and net are already there, since docker handles the networking
    echo 'rc_provide="loopback net"' >> /etc/rc.conf &&\
    # no need for loggers
    sed -i 's/^#\(rc_logger="YES"\)$/\1/' /etc/rc.conf &&\
    # can't get ttys unless you run the container in privileged mode
    sed -i '/tty/d' /etc/inittab &&\
    # can't set hostname since docker sets it
    sed -i 's/hostname $opts/# hostname $opts/g' /etc/init.d/hostname &&\
    # can't mount tmpfs since not privileged
    sed -i 's/mount -t tmpfs/# mount -t tmpfs/g' /lib/rc/sh/init.sh &&\
    # can't do cgroups
    sed -i 's/cgroup_add_service /# cgroup_add_service /g' /lib/rc/sh/openrc-run.sh &&\
    # clean apk cache
    rm -rf /var/cache/apk/*

# Caching module installation 
COPY requirements.txt /
RUN pip install -r requirements.txt

# Running startup script after bootup https://wiki.gentoo.org/wiki//etc/local.d
COPY init_container.sh /etc/local.d/init.start
RUN chmod +x /etc/local.d/init.start \
    && rc-update add local default

# Enable local script run logging
COPY local /etc/conf.d/local

COPY . /app
WORKDIR /app

EXPOSE 2222 5000

CMD env | grep _ >> /etc/env.d/99local && /sbin/init
