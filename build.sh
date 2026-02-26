#!/bin/bash

if [ "$podman" == "1" ]; then
	command=podman
else
	command=docker
	echo "You are NOT using podman! Good luck!"
fi

DOCKER_BUILDKIT=1 $command build --target rust-server -t rust-server:latest .
