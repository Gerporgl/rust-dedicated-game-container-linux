#!/bin/bash


# Run a vanilla server

# This is mostly an example on how to run the docker locally
# setting the root password at run time here is for convenience 
# for testing, without baking in the root password in the image itself
# By default, if not set, the root password is not set, and there is no way to access anything
# This is the default secure behavior
# The rust rcon password is also randomly generated, and obtainable throught the journalctl logs or reading the rust.env file
# on the filesystem under /home/steam/steamcmd/rust

mkdir -p ./rust_data

echo "============================================================================"
echo "You have to set a root password first"
echo "Once the container starts afterward and you are prompted for the login,"
echo "use root and your new password. If you set an empty password this will also work..."
echo "To stop the container and delete it, just use the poweroff command when inside the container"
echo "or stop the container with docker stop rust-server in a separate terminal"
echo "============================================================================"

read -s -p "Enter the desired root password: " root_password && echo ""
echo "Ok"

docker rm -fi rust-server > /dev/null
docker create --rm -it \
    -p 0.0.0.0:2222:22 \
    -p 0.0.0.0:28015:28015/udp \
    -p 0.0.0.0:27015:27015/udp \
    -p 0.0.0.0:28016:28016 \
    -p 0.0.0.0:8080:8080 \
    --userns=keep-id \
    -v $(pwd)/rust_data:/home/steam/steamcmd/rust $@ \
    --name rust-server \
    rust-server:latest > /dev/null

tmpfile=$(mktemp)
tmpfile_out=$(mktemp)
docker cp rust-server:/etc/shadow $tmpfile
awk -v password=$(echo $root_password | openssl passwd -1 -stdin) \
      'BEGIN{FS=OFS=":"} $1=="root" {$2=password}1' $tmpfile > $tmpfile_out
docker cp $tmpfile_out rust-server:/etc/shadow
rm $tmpfile && rm $tmpfile_out
echo "Password was set"

docker start rust-server > /dev/null
docker attach rust-server 


