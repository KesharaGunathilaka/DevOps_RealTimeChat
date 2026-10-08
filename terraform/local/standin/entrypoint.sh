#!/bin/sh
set -e
# Install the deploy key Terraform generated, like EC2 does with a key pair.
if [ -n "$SSH_PUBLIC_KEY" ]; then
  install -d -m 700 -o ubuntu -g ubuntu /home/ubuntu/.ssh
  printf '%s\n' "$SSH_PUBLIC_KEY" > /home/ubuntu/.ssh/authorized_keys
  chown ubuntu:ubuntu /home/ubuntu/.ssh/authorized_keys
  chmod 600 /home/ubuntu/.ssh/authorized_keys
fi
exec /sbin/init
