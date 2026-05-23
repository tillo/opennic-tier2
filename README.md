# opennic-tier2

Turnkey container image for an **[OpenNIC](https://www.opennic.org/) Tier 2 DNS server**, running BIND9 on Debian stable with auto-refresh of the OpenNIC TLD zones via `srvzone`.

OpenNIC Tier 2 operators traditionally hand-roll a BIND install plus a cron job to keep the alternative-TLD zones (`.geek`, `.bbs`, `.libre`, …) in sync from the Tier 1 servers. This image bundles the same pattern in a single container.

What it does:
- Installs BIND9 + the `srvzone` updater.
- Schedules the updater hourly (`20 * * * *`) to refresh the OpenNIC TLD list and per-TLD master/slave zone files under `/var/cache/bind/opennic/`.
- Ships a stock `named.conf.options` with `allow-recursion { any; }`, rate-limiting (10 rps responses / 5 rps NXDOMAIN), and no version/hostname leakage.
- Loads firewall rules from `/etc/iptables/rules.v4` via `netfilter-persistent`.

## Run

```bash
docker run -d \
  --name opennic-tier2 \
  --cap-add NET_ADMIN \
  --tmpfs /run --tmpfs /tmp \
  -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
  -p 53:53/udp -p 53:53/tcp \
  ghcr.io/<your-org>/opennic-tier2:latest
```

The container runs systemd as PID 1 (so `named`, `cron`, and `netfilter-persistent` all come up under their unit files). Adjust `iptables.rules` before building if you want tighter rate-limits or source ACLs.

After it's up, [register your server with OpenNIC](https://www.opennic.org/) so other resolvers can use it.

## Build

```bash
docker build -t opennic-tier2 .
```

When building in a CI that has a pull-through cache for Docker Hub (e.g. the GitLab dependency proxy), pass `--build-arg REGISTRY=<cache-prefix>/` to route `debian:stable` through it.
