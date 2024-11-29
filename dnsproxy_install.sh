#!/bin/sh
# copyleft

# default upstream is quad9-dnscrypt-ip4-nofilter-ecs-pri
# see the full list at https://dnscrypt.info/public-servers
# or https://github.com/DNSCrypt/dnscrypt-resolvers

default_bootstrap="8.8.8.8"
cache_ttl=300  # seconds
# default upstream servers see below in the $config variable definition

bin="dnsproxy"
bin_dir="/usr/local/bin"
config_dir="/etc/dnsproxy"
config_file="config.yaml"
service_file="dnsproxy.service"
working_dir="/var/lib/dnsproxy"
user="dnsproxy"
group="dnsproxy"

config="---
bootstrap:
  - '$default_bootstrap:53'
listen-addrs:
  - '0.0.0.0'
listen-ports:
  - 53
upstream:
  # quad9-dnscrypt-ip4-nofilter-ecs-pri
  - 'sdns://AQYAAAAAAAAADTkuOS45LjEyOjg0NDMgZ8hHuMh1jNEgJFVDvnVnRt803x2EwAuMRwNo34Idhj4ZMi5kbnNjcnlwdC1jZXJ0LnF1YWQ5Lm5ldA'
  - 'sdns://AQYAAAAAAAAAEzE0OS4xMTIuMTEyLjEyOjg0NDMgZ8hHuMh1jNEgJFVDvnVnRt803x2EwAuMRwNo34Idhj4ZMi5kbnNjcnlwdC1jZXJ0LnF1YWQ5Lm5ldA'
upstream-mode: 'load_balance'
timeout: '10s'
http3: true
cache: true
cache-min-ttl: $cache_ttl"

service="[Unit]
Description=dnsproxy
After=syslog.target
After=network.target

[Service]
Restart=always
RestartSec=2s
Type=simple
User=dnsproxy
Group=dnsproxy
WorkingDirectory=$working_dir

ExecStart=$bin_dir/$bin --config-path=$config_dir/$config_file

CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target"

opts="?hp"
while getopts $opts o; do
  case "$o" in
    p) purge=1 ;;
    \?) exit ;;
  esac
done
shift $(expr $OPTIND - 1)

if [ $# -lt 1 ]; then
  echo "dnsproxy installer/uninstaller"
  echo "usage: dnsproxy_install.sh [-p] <install|uninstall>"
  echo "-p: purge uninstall (delete the config file/dir)"
  exit
fi

if [ ! -f "$bin" ]; then
  echo "dnsproxy binary \"$bin\" should be located in the same dir as this script"
  exit
fi

if [ $(whoami) != "root" ]; then
  echo "please run with sudo or as root"
  exit
fi

if [ "$1" = "install" ]; then
  # Install
  if ! id -g "$group" > /dev/null 2>&1; then
    echo "creating group \"$group\""
    groupadd "$group"
  else
    echo "group \"group\" already exists"
  fi

  if ! id -u "$user" > /dev/null 2>&1; then
    echo "creating user \"$user\""
    useradd -g "$group" -M -r "$user"
  else
    echo "user \"user\" already exists"
  fi

  if [ ! -d "$config_dir" ]; then
    echo "creating the config dir \"$config_dir\""
    mkdir "$config_dir"
  else
    echo "config dir \"$config_dir\" already exists"
  fi

  if [ ! -f "$config_dir"/"$config_file" ]; then
    echo "writing config file \"$config_dir/$config_file\""
    echo "$config" > "$config_dir"/"$config_file"
  else
    echo "config file \"$config_dir/$config_file\" already exists, not writing"
  fi

  if [ ! -d "$working_dir" ]; then
    echo "creating the working dir \"$working_dir\""
    mkdir "$working_dir"
  else
    echo "working dir \"$working_dir\" already exists"
  fi

  wdl=$(ls -ld "$working_dir")
  if [ $(echo "$wdl" | cut -d' ' -f3) != "$user" ] || \
    [ $(echo "$wdl" | cut -d' ' -f4) != "$group" ]; then
    echo "setting working dir user to \"$user\" and group to \"$group\""
    chown -R "$user":"$group" "$working_dir"
  else
    echo "working dir user is already \"$user\" and group is \"$group\""
  fi

  if [ ! -f "$bin_dir"/"$bin" ]; then
    echo "copying the binary \"$bin\" to \"$bin_dir\""
    cp "$bin" "$bin_dir"/"$bin"
    chmod +x "$bin_dir"/"$bin"
  else
    echo "binary file \"$bin_dir/$bin\" already exists"
  fi

  if [ ! -f /etc/systemd/system/"$service_file" ]; then
    echo "writing the systemd service file \"/etc/systemd/system/$service_file\""
    echo "$service" > /etc/systemd/system/"$service_file"
  else
    echo "systemd service file \"/etc/systemd/system/$service_file\" already exists, not writing"
  fi

  if [ $(systemctl is-active "$service_file") != "active" ]; then
    echo "enabling and starting the systemd service \"$service_file\""
    systemctl enable "$service_file"
    systemctl start "$service_file"
  else
    echo "systemd service \"$service_file\" already active"
  fi

  echo "done"

else
  # Uninstall
  if systemctl list-units | grep "$service_file" > /dev/null; then
    echo "stopping and disabling the systemd service \"$service_file\""
    systemctl stop "$service_file"
    systemctl disable "$service_file"
  else
    echo "no systemd service \"$service_file\" running"
  fi

  if [ -f /etc/systemd/system/"$service_file" ]; then
    echo "removing the systemd service file \"/etc/systemd/system/$service_file\""
    rm -f /etc/systemd/system/"$service_file"
  else
    echo "no systemd service file \"/etc/systemd/system/$service_file\" found"
  fi

  if ps --no-headers -C "$bin" > /dev/null; then
    echo "stopping the process \"$bin\""
    killall -w "$bin"
  else
    echo "no running process \"$bin\" found"
  fi

  if [ -f "$bin_dir"/"$bin" ]; then
    echo "deleting the binary \"$bin_dir/$bin\""
    rm "$bin_dir"/"$bin"
  else
    echo "no binary \"$bin_dir/$bin\" found"
  fi

  if [ -d "$working_dir" ]; then
    echo "deleting the working dir \"$working_dir\""
    rm -Rf "$working_dir"
  else
    echo "no working dir \"$working_dir\" found"
  fi

  if [ -f "$config_dir"/"$config_file" ]; then
    if [ ! $purge ]; then
      echo "config file \"$config_dir/$config_file\" found but not deleted (use -p to enforce)"
    else
      echo "deleting the config file \"$config_dir/$config_file\""
      rm -f "$config_dir"/"$config_file"
    fi
  else
    echo "no config file \"$config_dir/$config_file\" found"
  fi

  if [ -d "$config_dir" ]; then
    if [ ! $purge ]; then
      echo "config dir \"$config_dir\" found but not deleted"
    elif [ -z $(ls -A "$config_dir") ]; then
      echo "config dir \"$config_dir\" is empty, deleting"
      rmdir "$config_dir"
    else
      echo "config dir \"$config_dir\" is not empty, not deleting"
    fi
  else
    echo "no config dir \"$config_dir\" found"
  fi

  if id -u "$user" > /dev/null 2>&1; then
    echo "deleting the user \"$user\""
    userdel "$user"
  else
    echo "no user \"$user\" found"
  fi

  if id -g "$group" > /dev/null 2>&1; then
    echo "deleting the group \"$group\""
    groupdel "$group"
  else
    echo "no group \"$group\" found"
  fi

  echo "done"

fi

