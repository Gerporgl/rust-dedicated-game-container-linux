#!/bin/bash

podman=$(podman -v 2>/dev/null | grep -c -i podman)
if [ "$podman" == "1" ]; then
	command=podman
else
	command=docker
	echo "You are NOT using podman! Good luck!"
fi

 DOCKER_BUILDKIT=1 $command build $@ -t rust-server:latest .
