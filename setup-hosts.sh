#!/bin/bash
# Usage sudo ./setup-hosts.sh /etc/hosts

# This script adds a bunch of domains of the form ${service}.local.truesparrow to /etc/hosts.
# So instead of writing http://localhost:10003/ we'd write http://content.local.truesparrow.
# It's a nicer format and is similar to what happens in the TEST, DEV and PROD environments.
# However, just mapping these to 127.0.0.1 won't work with Docker for Mac. Because 127.0.0.1
# will be interpreted as the loopback in the container's view of the world, and the other
# services won't be visible there. Not 100% on how docker networking works, but that's the
# gist of it. So we need a different address which still maps to the loopback one. Enter
# the solution from https://forums.docker.com/t/access-host-not-vm-from-inside-container/11747
# The idea is to add an alias for the loopback interface, but with a different IP.

DOCKER_AND_HOST_COMMON_ADDRESS=172.16.123.1

ifconfig lo0 alias $DOCKER_AND_HOST_COMMON_ADDRESS
echo $DOCKER_AND_HOST_COMMON_ADDRESS postgres.local.truesparrow >> $1
echo $DOCKER_AND_HOST_COMMON_ADDRESS identity.local.truesparrow >> $1
echo $DOCKER_AND_HOST_COMMON_ADDRESS content.local.truesparrow >> $1
echo $DOCKER_AND_HOST_COMMON_ADDRESS adminfe.local.truesparrow >> $1
echo $DOCKER_AND_HOST_COMMON_ADDRESS sitefe.local.truesparrow >> $1
killall -HUP mDNSResponder
