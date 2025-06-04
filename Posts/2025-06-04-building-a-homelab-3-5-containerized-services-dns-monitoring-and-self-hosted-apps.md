---
color: C07309
date: 2025-06-04T16:15:00Z
description: A blog post series about my journey building a homelab
project: true
title: Building a homelab (3/5): Containerized Services: DNS, Monitoring, and Self-Hosted Apps 
category: homelab
slug: building-a-homelab-3-5-containerized-services-dns-monitoring-and-self-hosted-apps
---

> Empower your digital life: In a world of clouds, I choose to build my own — where privacy reigns and my data is truly mine.

In Part 1, I introduced my homelab setup. In Part 2, I covered the GitOps pipeline with Renovate and Komodo. Now let’s look at the actual applications that make this environment useful.

From local DNS blocking to RSS reading and media streaming, everything is self-hosted. And since I’m running on a mix of Pi boards and a Proxmox VM, distribution of services matters just as much as the apps themselves.

## Service Distribution Overview

### Proxmox VM srv-prod-01

<table>
  <thead>
    <tr>
      <th>Service</th>
      <th>Description</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>ArchiveBox</td>
      <td>Bookmark Archival</td>
    </tr>
    <tr>
      <td>Audiobookshelf</td>
      <td>Audiobook Management</td>
    </tr>
    <tr>
      <td>Calibre</td>
      <td>EBook Management</td>
    </tr>
    <tr>
      <td>Dozzle</td>
      <td>Logs Monitoring</td>
    </tr>
    <tr>
      <td>Homeassistant</td>
      <td>Homeautomation, HomeKit Bridge</td>
    </tr>
    <tr>
      <td>Homepage</td>
      <td>Home Dashboard</td>
    </tr>
    <tr>
      <td>Immich</td>
      <td>Photo Library</td>
    </tr>
    <tr>
      <td>Jellyfin</td>
      <td>Media Server</td>
    </tr>
    <tr>
      <td>Komodo</td>
      <td>Docker Management</td>
    </tr>
    <tr>
      <td>Komodo Periphery</td>
      <td>Docker Management Agent</td>
    </tr>
    <tr>
      <td>Komodo ntfy</td>
      <td>Alerter Bridge</td>
    </tr>
    <tr>
      <td>Libation</td>
      <td>Audibook Downloader</td>
    </tr>
    <tr>
      <td>Mealie</td>
      <td>Recipe Management</td>
    </tr>
    <tr>
      <td>MeTube</td>
      <td>Video &amp; Audio Downloader</td>
    </tr>
    <tr>
      <td>Miniflux</td>
      <td>RSS</td>
    </tr>
    <tr>
      <td>ntfy</td>
      <td>Push Service</td>
    </tr>
    <tr>
      <td>Paperless</td>
      <td>Document Management</td>
    </tr>
    <tr>
      <td>Penpot</td>
      <td>Design Tool</td>
    </tr>
    <tr>
      <td>SABnzbd</td>
      <td>Usenet Downloader</td>
    </tr>
    <tr>
      <td>Traefik</td>
      <td>Reverse Proxy, SSL, etc.</td>
    </tr>
    <tr>
      <td>Tubesync</td>
      <td>Video &amp; Audio Downloader</td>
    </tr>
    <tr>
      <td>Uptime Kuma</td>
      <td>Monitoring</td>
    </tr>
    <tr>
      <td>Vaultwarden</td>
      <td>Password Management</td>
    </tr>
  </tbody>
</table>

### RPI DNS01

<table>
  <thead>
    <tr>
      <th>Service</th>
      <th>Description</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Adguard Home</td>
      <td>DNS Server</td>
    </tr>
    <tr>
      <td>Adguard Home Sync</td>
      <td>Adguard Home Config Sync</td>
    </tr>
    <tr>
      <td>Dozzle Agent</td>
      <td>Logs Agent</td>
    </tr>
    <tr>
      <td>Komodo Periphery</td>
      <td>Docker Management Agent</td>
    </tr>
  </tbody>
</table>

### RPI DNS02

<table>
  <thead>
    <tr>
      <th>Service</th>
      <th>Description</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Adguard Home</td>
      <td>DNS Server</td>
    </tr>
    <tr>
      <td>Dozzle Agent</td>
      <td>Logs Agent</td>
    </tr>
    <tr>
      <td>Komodo Periphery</td>
      <td>Docker Management Agent</td>
    </tr>
  </tbody>
</table>


All service configurations are stored in Git, updated automatically by Renovate, and redeployed via Komodo when changes are merged. We will look at the automation bit in part 2 and the deployed services in part 3 of this blog post series.

This setup balances critical services (DNS) across two Pis for resilience, while keeping heavier services (media, apps) centralized on the Ubuntu VM.

## Local DNS with Adguard Home

AdGuard Home is my go-to solution for local DNS with ad and tracker blocking. I run two independent instances — one on each Pi — to ensure redundancy.

Why two instances?

- Ensures DNS still works if one Pi reboots or fails
- Provides distributed DNS for clients across VLANs
- Enables load distribution and fault tolerance

To keep their configs in sync, I run [adguardhome-sync](https://github.com/bakito/adguardhome-sync) on dns01:

```yaml
services:
  adguardhome-sync:
    image: lscr.io/linuxserver/adguardhome-sync:v0.7.6-ls138@sha256:21b0311d8e0aecca093f6aa0c15a91e293de108d86477da768816eb75af130bb
    container_name: adguardhome-sync
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ:-UTC}
    volumes:
      - ${VOLUME_PATH}/config:/config
    ports:
      - 8090:8080
    restart: unless-stopped
```

The mounted config file then adds dns02 as a sync target. This way every change I make on dns01 will automatically be reflected on dns02 as well.

<div class="image">
    <img loading="lazy" width="463.5" src="/img/building-a-homelab/adguard.png" alt="An image showing the adguard web UI.">
</div>

## 📈 Monitoring with Uptime Kuma

[Uptime Kuma](https://github.com/louislam/uptime-kuma) runs in a Docker container on the Ubuntu VM. It monitors:

- My public WireGuard endpoint
- All internal apps via their Traefik routes / docker containers
- DNS uptime on both Pi nodes
- External services like GitHub and my VPS
- Cron Jobs and Backup Tasks
  
It’s lightweight, supports alerting, and even shows response time history.

<div class="image">
    <img loading="lazy" width="463.5" src="/img/building-a-homelab/uptime-kuma.png" alt="An image showing the uptime-kuma web UI.">
</div>

## 📚 Logging with Dozzle

Each of my Raspberry Pis runs a Dozzle agent, which streams container logs to the central Dozzle instance. Log files written to disk are available through a seperate output stream I create. This gives me:

- One place to view logs from every device
- Live log tailing via browser
- Easy debugging if something breaks  

On the central VM, I run the Dozzle web UI and configure it to connect to the remote agents or output streams:

```yaml
dozzle:
    image: amir20/dozzle:v8.12.20@sha256:6e3c64615e15493dbd2a476650d17b1b0038ba7dbd3cfe1a611df64ed57e602a
    container_name: dozzle
    security_opt:
      - no-new-privileges:true
    restart: unless-stopped
    networks:
      - internal
      - proxy
    environment:
      - DOZZLE_LEVEL=${DOZZLE_LEVEL}
      - DOZZLE_ENABLE_ACTIONS=${DOZZLE_ENABLE_ACTIONS}
      - DOZZLE_ENABLE_SHELL=${DOZZLE_ENABLE_SHELL}
      - DOZZLE_NO_ANALYTICS=${DOZZLE_NO_ANALYTICS}
      - DOZZLE_FILTER=${DOZZLE_FILTER}
      - DOZZLE_AUTH_PROVIDER=${DOZZLE_AUTH_PROVIDER}
      - DOZZLE_HOSTNAME=${DOZZLE_HOSTNAME}
      - DOZZLE_REMOTE_AGENT=${DOZZLE_REMOTE_AGENT}
    volumes:
      - ${VOLUME_PATH}/data:/data
      - ${VOLUME_PATH}/certs:/certs
      - /var/run/docker.sock:/var/run/docker.sock
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.dozzle.rule=Host(`mydomain.de`)"
      - "traefik.http.routers.dozzle.entrypoints=https"
      - "traefik.http.routers.dozzle.tls=true"
      - "traefik.http.services.dozzle.loadbalancer.server.port=8080"
      - "traefik.docker.network=proxy"

  # example of an output stream
  dozzle-traefik:
    container_name: dozzle-traefik
    image: alpine@sha256:6662067ba6f090f8a2c8b5b50309692be03bffef2729b453425edd4f26343377
    volumes:
      - ${TRAEFIK_LOG}:/var/log/stream.log
    command:
      - tail
      - -f
      - /var/log/stream.log
    network_mode: none
    restart: unless-stopped
    labels:
      - dev.dozzle.group=traefik
```

<div class="image">
    <img loading="lazy" width="463.5" src="/img/building-a-homelab/dozzle.png" alt="An image showing the dozzle web UI.">
</div>

## 🛜 Traefik: The Ingress Brain

Every internal service is routed through Traefik, my reverse proxy of choice. Key features in my setup:

- Automatic TLS via Let's Encrypt
- Internal-only DNS resolution (e.g., mydomain.de)
- Container labels define routing rules declaratively

In Adguard Home i added `Custom DNS Rewrite` rule. Whenever my DNS server gets a request to resolve the IP address for `*.mydomain.de` it points to my traefik instance which then routes based on the host name to the actual docker containers or machines. Since traefik comes certbot/acme out of the box I can use my own domain to SSL encrypt this connection with a certificate requested from Let's Encrypt. To set things up I mostly followed this tutorial here so I won't go into detail: [Traefik Tutorial](https://technotim.live/posts/traefik-3-docker-certificates/).

## ➡️ Conclusion

Once you feel the excitement and joy of deploying actually useful apps to your homelab there is no step back. Watching a movie on Jellyfin, reading my RSS feeds through Miniflux, storing passwords in my own, private vaultwarden instance just feels very rewarding. On top I can access these services via my own custom domain SSL encrypted, although I do not expose them to the internet. In the next part we have a closer look at my network setup and how I stepped up my game here.