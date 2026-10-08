# Local stand-in for the EC2 instance. Same Ubuntu release as the AMI, booting
# systemd, with sshd and a passwordless-sudo "ubuntu" user: everything the
# Ansible playbook relies on from a fresh EC2 host.
FROM ubuntu:24.04

ENV container=docker DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      systemd systemd-sysv openssh-server sudo python3 ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && systemctl enable ssh \
 && (id ubuntu >/dev/null 2>&1 || useradd -m -s /bin/bash ubuntu) \
 && echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-ubuntu \
 && chmod 440 /etc/sudoers.d/90-ubuntu \
 && sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config \
 && systemctl mask systemd-udevd.service getty.target console-getty.service

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# systemd shuts down cleanly on SIGRTMIN+3, not SIGTERM.
STOPSIGNAL SIGRTMIN+3
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
