#!/bin/bash

DOCKER_BUILDKIT=1 docker build --target rust-server -t rust-server:latest .
