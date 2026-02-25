# Another Rust Game Dedicated Server Container

## Introduction

Why create a new Rust Dedicated server container and not just linux GSM?

Because!!!!!!

There is probably no real reason, I've used LinuxGSM before, but also the old didstopia docker image from which this is based on because I was mostly familiar with that one.
I just wanted to customize a rust server that would allow linux and steamdeck players to be able to join out of the box, while still allowing the few Windows users out there to join normally.

I also wanted to have this container to use a main rust.env file to set everyting which can be mounted as a filesystem and would be read on each game restart, and not statically set on a "docker run" command for example.

This new container image uses the latest Ubuntu 24.04 LTS base, and node.js 24 for the management apps (the didstopia images do not seems to be maintained anymore)

It also run with a full systemd init which allow to run rust as a systemd service and have all the convenience of restarting it with expential backoffs, logging using journalctl with timestamps, etc. I was against that idea originally, as I prefered to have a simple bash entrypoint... but wrapping all logs properly with timestamps and everything else I wanted turned out to be very hugly and clunky... and after trying out the default Ubuntu container image in Proxmox CT with LXC, I really liked the idea of having a full systemd, and found that the number of processes is very low, and the startup time is almost instant. And since Rust takes a very long time to start and uses a lot of memory and disk space (in comparison), I did not see any reason to try to cut the corners.

The container also has a ssh server pre-installed and accessible, althought by default there is no allowed credentials.

I also focused on hosting this container with Proxmox VE and the built-in LXC containers, as it makes for a very efficient hosting solution compared to hosting this inside a vm in docker like I was doing before.

## Quick start

To build the image, and run your first rust server, simple run the following command:

```
./docker_run.sh
```
It will prompt you to set a root password, and will create a subfolder rust_data which will contain all the rust server files that you want to persist and care about.

An important detail to understand is that the root password is not set into the docker image itself, but is set at runtime. You can take a look inside docker_run_only.sh to see how it's done.

Initially, it will take some time to start as it needs to build the docker image first. Afterward, you can use docker_run_only.sh directly.

After the server started, it will download rust and enable the Carbon plugin framework with the correct configs to allow linux players to join, you can disable that in the rust.env if this is not what you want.

A default rust.env will be placed in ./rust_data/rust.env that you can edit afterward.
A new world seed will be generated, and a random rcon password as well.
Again, all of those can be changed, and the server just needs to be restarted to apply the new changes.

The webrcon will be accessible at http://localhost:8080 and the password is available in the rust.env file generated.

To view the rust server logs, you can use those commands inside the container:

To view live logs in real time
```
journalctl -u rust-server -f
```

To grab all logs
```
journalctl -u rust-server | cat
```

To view normally
```
journalctl -u rust-server
```

## Advanced use & other details

### rcon command

You can use the command line version of rcon, inside the container in a terminal.
For example:
```
rcon players
```
This should return the list of players on your server, if any.

### Setup your ssh public key to connect with ssh

An example can be found in docker_run_with_ssh.sh (TODO)

### rust.env configuration details

TODO

...

### Appendix

Original work and credits (a mix of both):
 * https://github.com/Didstopia/rust-server
 * https://github.com/eberdt/docker-rust-server