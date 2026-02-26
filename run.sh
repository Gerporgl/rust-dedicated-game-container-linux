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
else
	uidopt=""
	command=docker
	echo "You are NOT using podman... this will not work. You'll need to install podman."
    echo "Good luck!"
    exit 1
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

podman rm -fi pure-rust-server-container
$command create --rm -it \
    -p 0.0.0.0:2222:22 \
    -p 0.0.0.0:28015:28015/udp \
    -p 0.0.0.0:27015:27015/udp \
    -p 0.0.0.0:28016:28016 \
    -p 0.0.0.0:14080:8080 \
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
