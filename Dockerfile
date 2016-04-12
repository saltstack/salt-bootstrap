FROM ubuntu-upstart:14.04
MAINTAINER "SaltStack Team"

# Bootstrap script options: install Salt Master by default
ENV BOOTSTRAP_OPTS='-M'
# Version of salt to install: stable or git
ENV SALT_VERSION=stable

COPY bootstrap-salt.sh /tmp/

# Prevent udev from being upgraded inside the container, dpkg will fail to configure it
RUN echo udev hold | dpkg --set-selections
# Upgrade System and Install Salt
RUN sudo sh /tmp/bootstrap-salt.sh -U -X -d $BOOTSTRAP_OPTS $SALT_VERSION && \
    apt-get clean
RUN /usr/sbin/update-rc.d -f ondemand remove; \
    update-rc.d salt-minion defaults && \
    update-rc.d salt-master defaults || true

EXPOSE 4505 4506
