#!/bin/bash


# Run a vanilla server

# This is mostly an example on how to run the docker locally
# setting the root password at run time here is for convenience 
# for testing, without baking in the root password in the image itself
# By default, if not set, the root password is not set, and there is no way to access anything
# This is the default secure behavior
# The rust rcon password is also randomly generated, and obtainable throught the journalctl logs or reading the rust.env file
# on the filesystem under /home/steam/steamcmd/rust

if [ ! $IMAGE_NAME ]; then
    IMAGE_NAME=ghcr.io/gerporgl/rust-server:latest
fi

mkdir -p ./rust_data

podman=$(podman -v 2>/dev/null | grep -c -i podman)
if [ "$podman" == "1" ]; then
    # This is to keep the user id the same as in the container for the mounted file system,
    # so the steam user is id 1000, and may be the same as the local user, so that is easier to manage
    # There are others ways of doing that, and this is optional
	opts="--userns=keep-id"
	command=podman
	echo "You have podman installed"
    podman rm -fi pure-rust-server-container
else
    opts=" --tmpfs /run
            --tmpfs /run/lock
            --tmpfs /tmp
            --tmpfs /run/dbus
            --security-opt systempaths=unconfined
            --security-opt label=disable
            --cgroupns host
            -v /sys/fs/cgroup:/sys/fs/cgroup:rw "
    command=docker
    echo "You are NOT using podman... some permissions adjustments were needed for Docker. Podman or LXC is recommended instead."
    docker rm -f pure-rust-server-container
fi

echo "============================================================================"
echo "You have to set a root password first"
echo "Once the container starts afterward and you are prompted for the login,"
echo "use root and your new password. If you set an empty password this will also work..."
echo "To stop the container and delete it, just use the poweroff command when inside the container"
echo "or stop the container with docker stop rust-server in a separate terminal"
echo "============================================================================"

read -s -p "Enter the desired root password: " root_password && echo ""
echo "Ok"

$command create --rm -it \
    -p 127.0.0.1:2222:22 `#  SSH port remap to non privileged port 2222 ` \
    -p 28015:28015/udp `#  Game port` \
    -p 28016:28016/udp `#  Query port` \
    -p 28017:28017 `# Rust+ App port` \
    -p 127.0.0.1:28666:28666 `#  RCON port (not secure, only expose on localhost or local network)` \
    -p 127.0.0.1:8080:8080 `#  Webrcon (not secure, only expose on localhost or local network)` \
    $opts \
    -v $(pwd)/rust_data:/home/steam/steamcmd/rust $@ \
    --name pure-rust-server-container \
    $IMAGE_NAME

tmpfile=$(mktemp)
tmpfile_out=$(mktemp)
$command cp pure-rust-server-container:/etc/shadow $tmpfile
awk -v password=$(echo $root_password | openssl passwd -1 -stdin) \
      'BEGIN{FS=OFS=":"} $1=="root" {$2=password}1' $tmpfile > $tmpfile_out
$command cp $tmpfile_out pure-rust-server-container:/etc/shadow
rm $tmpfile && rm $tmpfile_out
echo "Password was set"

$command start pure-rust-server-container
$command attach pure-rust-server-container
