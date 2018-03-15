#!/bin/bash
# Usage sudo ./setup-hosts.sh /etc/hosts

echo 127.0.0.1 identity.local.truesparrow >> $1
echo 127.0.0.1 content.local.truesparrow >> $1
echo 127.0.0.1 adminfe.local.truesparrow >> $1
echo 127.0.0.1 sitefe.local.truesparrow >> $1
