#!/bin/bash

podman tag rust-server:latest registry.asqw.net/rust-server:latest
podman push registry.asqw.net/rust-server:latest