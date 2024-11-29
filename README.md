# dnsproxy Installer

A Linux shell script installing or uninstalling the AdguardTeam's [dnsproxy](https://github.com/AdguardTeam/dnsproxy) binary. Cleanly creates/removes all the needed stuff (working user, group, systemd service, etc.).

All the default settings can be found at the beginning of the file, default upstream is set to quad9-dnscrypt-ip4-nofilter-ecs-pri.

## Usage

Run the script from the directory where you have the `dnsproxy` binary located.

Install: `dnsproxy_install.sh install`

Uninstall: `dnsproxy_install.sh uninstall`

Purge: `dnsproxy_install.sh -p uninstall`

## List of public DNSCrypt/DoH servers

https://github.com/DNSCrypt/dnscrypt-resolvers

## UDP buffer size

If you're getting a warning concerning the UDP buffer size being too small add the following lines to `/etc/sysctl.conf` and reboot:

```
net.core.rmem_max=7500000
net.core.wmem_max=7500000
```

