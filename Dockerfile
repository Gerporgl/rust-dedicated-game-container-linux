# We now just use bare ubuntu, it works best with lxc and systemd tty console and shutdown
# and steamcmd is very trivial to install and we already were downloading it everytime on start
# there doesn't seem to be any need to have it installed with a special
# image or distro package
FROM ubuntu:24.04 as file_system_setup

# Default Node.js version
ARG NODE_VERSION=24

# We run with systemd, so we must be root
# the rust service run as the steam user (see rust-server.service)
# The whole thing is a container anyway, being root inside does not give it root provilege outside
# especially when running it in non privileged mode as non-root in the host system
USER root

# Install dependencies and verify that Node.js is working
RUN apt-get update && \
    apt-get remove -y unminimize && apt-get install -y --no-install-recommends \
    ca-certificates \
    software-properties-common curl && \
    add-apt-repository multiverse && apt-get update && \
    curl -sL https://deb.nodesource.com/setup_$NODE_VERSION.x | bash - && \
    apt-get install -y --no-install-recommends \
    # Install nodejs, along with all dependencies... such as python3 that seems required
    nodejs \
    # We use nginx to serve webrcon static pages
    nginx \
    # This is required (and the only thing really needed), for steamcmd (and rust) to run
    lib32stdc++6 \

    # for bsdtar that supports zip format
    libarchive-tools \
    # There is a ssh server running out of the box, but there is no authorized key by default and no
    # password authentication allowed with our custom config
    openssh-server \
    # For sudoing some scripts we require sudo to give ourself ownership on mounted volumes
    # as well as giving users who have ssh root access to also login with the steam user via ssh directly
    sudo \
    # For convenience, instal nano
    nano \
    # Network tools such as ping and host command
    iputils-ping \
    bind9-host \
    # Full systemd init entrypoint
    init \
    # Networkd based stack (better ipv6 and dhcp support than network interfaces when running on proxmox/lxc)
    networkd-dispatcher && \
    apt-get -y autoremove && \
    apt-get -y clean  && \
    echo "Nodejs version: $(node -v) npm version: $(npm -v)" && \
    rm -rf \
    /var/lib/apt/lists/* \
    /var/tmp/* \
    /tmp/* && \
    # Remove clutter messages on login
    # Perhaps replace this in future with rust related info (players online, useful help and commands (rcon, etc.))
    rm /etc/update-motd.d/10* && rm /etc/update-motd.d/50* && rm /etc/update-motd.d/60* && \
    # Remove default nginx stuff
    rm -fr /usr/share/nginx/html/* && \
    rm -fr /etc/nginx/sites-available/* && \
    rm -fr /etc/nginx/sites-enabled/* && \
    # Enable some service and remove a bunch of unwanted automatic timers
    # Updates will have to be run manually or with new containers builds
    # Perhaps these could be done on rust updates in the future, and force a container restart
    systemctl enable systemd-networkd.service && \ 
    rm /etc/systemd/system/timers.target.wants/apt* && \
    rm /etc/systemd/system/timers.target.wants/dpkg* && \
    rm /etc/systemd/system/timers.target.wants/e2scrub* && \
    rm /etc/systemd/system/timers.target.wants/fstrim* && \
    rm /etc/systemd/system/timers.target.wants/motd* && \
    rm /usr/lib/systemd/system/apt-daily-upgrade.timer && \
    rm /usr/lib/systemd/system/apt-daily.timer && \
    rm /usr/lib/systemd/system/dpkg-db-backup.timer && \
    rm /usr/lib/systemd/system/e2scrub_all.timer && \
    rm /usr/lib/systemd/system/fstrim.timer && \
    rm /lib/systemd/system/motd-news.timer && \
    # Rename the ubuntu user (which uses the standard uid 1000) to be our steam user and create its home folder
    groupmod \
        -n steam ubuntu && \
    usermod -l steam \
        -d /home/steam \
        -G steam,users,staff \
        --shell /bin/false \
        ubuntu && \
    mkdir -p /home/steam && \
    sed -i -e '2iTERM=xterm-color\\' /root/.profile && \
    cp /root/.profile /home/steam/.profile && \
    cp /root/.bashrc /home/steam/.bashrc && \
	chown -R steam:steam /home/steam && \
    rm -f /home/ubuntu -R

# This is not so useful anymore, this env variable does not get carried in the systemd init and our service
# we have to set it again in our startup script...
# However we re-use it here in the Dockerfile later on
ENV STEAMCMDDIR /home/steam/steamcmd

RUN mkdir /app
WORKDIR /app

ADD node_apps /app

# Copy and extract webrcon html
ADD configs/home_bashrc /root/.bashrc
ADD configs/home_bashrc /home/steam/.bashrc
ADD configs/home_profile /root/.profile
ADD configs/home_profile /home/steam/.profile

ADD configs/nginx_rcon.conf /etc/nginx/nginx.conf
ADD configs/html/index.html /usr/share/nginx/html/
# This also extracts the webrcon files in one step
ADD configs/html/webrcon.tar.xz /app/html-templates/
    # Create the volume directories
RUN mkdir -p $STEAMCMDDIR /usr/share/nginx/html /var/log/nginx && \
    # Setup all nodejs apps
    cd /app/shutdown_app && npm install && \
    cd /app/restart_app && npm install && \
    cd /app/scheduler_app && npm install && \
    cd /app/heartbeat_app && npm install && \
    cd /app/rcon_app && npm install && ln -s /app/rcon_app/app.js /usr/bin/rcon

# Override the default sshd config to disable login with passwords through ssh
ADD configs/sshd_config /etc/ssh/sshd_config

RUN mkdir -p /root/.ssh && touch /root/.ssh/authorized_keys && \
    chsh -s /bin/bash steam 

# Add default environment variables for the server as well as any rust data folder we want to override
# which are copied over the steamcmd data folder on first start if no file exists
ADD configs/rust.default.env /app/rust.default.env
ADD default_rust_data_overrides /app/default_rust_data_overrides

# Add our systemd service
ADD configs/rust-server.service /etc/systemd/system/
# Add the steamcmd installation script
ADD configs/install.txt /app/install.txt

# Add all scripts in one shot and make them executable
ADD --chmod=755 scripts /app

# Fix permissions
RUN chown -R steam:steam \
    $STEAMCMDDIR \
    /home/steam \
    /app \
    /usr/share/nginx/html \
    /var/log/nginx

# These should be done here, after changing ownership so that these files remain editable only by root
RUN chown root:root /app/cat_authkeys.sh && echo "steam ALL=NOPASSWD: /app/cat_authkeys.sh" >> /etc/sudoers && \
    chown root:root /app/chown_steam.sh && echo "steam ALL=NOPASSWD: /app/chown_steam.sh" >> /etc/sudoers && \
    # Enable our systemd service so that it starts automatically
    systemctl enable rust-server.service

ADD --chmod=000 LICENSE.md /app
# This step may not be desirable, as it squash all layers into a single file system layer and loses all previous layers
# traces
FROM scratch as rust-server

USER root
COPY --from=file_system_setup / /

LABEL org.opencontainers.image.ref.name=ubuntu
LABEL org.opencontainers.image.version=24.04

# Comment the following line, it is mostly only to add your own ssh public key to test ssh locally
# Container orchestrator should allow you to configure the key at setup time (for example proxmox CT will do that)
#ADD --chmod=644 authorized_keys /root/.ssh/authorized_keys
# To signal systemd to stop, it is better to use this signal, otherwise LXC on proxmox will not shutdown when using the host shutdown functionality
# see https://man7.org/linux/man-pages/man1/systemd.1.html
STOPSIGNAL SIGRTMIN+3

# Use full systemd init, better for managing a large server game like rust, more convenient
# for managing logs with timestamps, auto restarts with expenential backoff, etc.
# Runs well on lxc and proxmox with full tty console support.
# This is still very lightweight as a container, and rust is the largest resource consumer anyway.
ENTRYPOINT ["/sbin/init"]
#ENTRYPOINT ["/bin/bash"]

