#!/bin/bash
# This runs as root with a sudoer config set in Dockefile to allow us to grab authorized_keys that may be configured
# by the container agent (such as LXC on proxmox)
cat /root/.ssh/authorized_keys # We only cat the keys, then the calling script can do what it wants