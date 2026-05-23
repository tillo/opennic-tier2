# Public default pulls debian:stable straight from Docker Hub. In a CI
# environment with a registry pull-through cache (e.g. GitLab dependency
# proxy), set --build-arg REGISTRY=<cache-prefix>/ to route the base image
# through it.
ARG REGISTRY=
FROM ${REGISTRY}debian:stable

ENV PACKAGES="\
  wget \
  bind9 \
  bind9-dnsutils \
  ca-certificates \
  cron \
  procps \
  systemd \
  iptraf-ng \
  less \
  iptables \
  iptables-persistent \
"\
  DEBIAN_FRONTEND=noninteractive

# ARG changes daily (passed from CI as $(date +%Y%m%d)) so this RUN's
# cache key invalidates once per day, picking up newly-published security
# patches via `apt upgrade` against current debian repos.
ARG CACHEBUST_DAY=unset
RUN echo "cache day: ${CACHEBUST_DAY}" && \
    apt update -y && apt -y upgrade && \
    apt install -y --no-install-recommends $PACKAGES && apt clean all

COPY iptables.rules /etc/iptables/rules.v4

RUN systemctl enable cron named netfilter-persistent

RUN bash -c "systemctl mask getty@tty{1,2,3,4,5,6}"

WORKDIR /etc/bind

COPY srvzone srvzone.conf ./
RUN ./srvzone -d

RUN mkdir -p /var/cache/bind/opennic/slave /var/cache/bind/opennic/master && chown -R bind:bind /var/cache/bind/opennic
RUN ./srvzone || true

RUN echo 'include "/etc/bind/named.conf.opennic";' >> named.conf
RUN echo 'options { directory "/var/cache/bind"; allow-recursion { any; }; version none; hostname none; rate-limit { responses-per-second 10; errors-per-second 5; nxdomains-per-second 5; all-per-second 20; slip 2; }; };' > named.conf.options
RUN truncate -s 0 named.conf.root-hints

RUN echo '20 * * * * root /etc/bind/srvzone' >> /etc/crontab

ENTRYPOINT ["/usr/lib/systemd/systemd"]
