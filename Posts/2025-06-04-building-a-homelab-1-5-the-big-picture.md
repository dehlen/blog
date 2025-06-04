---
color: C07309
date: 2025-06-04T14:15:00Z
description: A blog post series about my journey building a homelab
project: true
title: Building a homelab (1/5): The big picture 
category: homelab
slug: building-a-homelab-1-5-the-big-picture
---

> Home is where your lab is.

I’ve always been fascinated by infrastructure — how services run behind the scenes, how networks talk to each other, and how automation can bring order to chaos. That’s what led me to build and maintain a fully self-hosted homelab, not just for tinkering, but for actual day-to-day use.

This blog series walks you through every part of my homelab — from the nuts and bolts of the network stack to the GitOps pipeline that drives automated updates and deployment.

## ❓ Why I Built This

Like many who run homelabs, my goals were:

- Learning by doing (networking, infrastructure-as-code, automation)
- Host my own services (newsreader, media, monitoring, DNS, etc.)
- Improve privacy and control over my own data
- Build a resilient, automated, low-touch system

Over time, it’s grown into a robust, self-sufficient ecosystem that closely mimics professional infrastructure, just at a smaller scale.

## 💻 Hardware Overview

<table>
  <thead>
    <tr>
      <th>Device</th>
      <th>Role</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Draytek Vigor 167</td>
      <td>DSL Modem</td>
    </tr>
    <tr>
      <td>UniFi Express 7</td>
      <td>Router</td>
    </tr>
    <tr>
      <td>UniFi Pro Max 16 Switch</td>
      <td>Switch</td>
    </tr>
    <tr>
      <td>U7 Pro Wall, U7 Lite (2x)</td>
      <td>Access Points</td>
    </tr>
    <tr>
      <td>FritzBox 7490</td>
      <td>DECT Telephone Base Station</td>
    </tr>
    <tr>
      <td>RPI 3 Model B</td>
      <td>DNS 01</td>
    </tr>
    <tr>
      <td>RPI 3 Model B+</td>
      <td>DNS 02 Failover</td>
    </tr>
    <tr>
      <td>GMKTEC Nucbox M5 Plus Mini PC</td>
      <td>Proxmox Host</td>
    </tr>
    <tr>
      <td>Main NAS</td>
      <td>Synology DS923+</td>
    </tr>
    <tr>
      <td>Backup NAS</td>
      <td>Synology DS918</td>
    </tr>
  </tbody>
</table>

## 🛜 Networking Layout

- VLANs segment my devices by function (e.g., IOT, guests, infrastructure, work)
- Multiple SSIDs are broadcasted for each VLAN through UniFi APs
- All cabling in the house runs to the central UniFi switch
- Internet comes in via PPPoE through a DSL modem

This physical setup gives me both strong performance and clean network segmentation.
Also once fiber optics will finally be available in our home I'll be able to just switch out the DSL Modem and the network should function exactly the same. We will have a closer look at the networking infrastructure in part 4 of this series.

## 📱 Core Services

Most of my services run in Docker and are deployed via Komodo:

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

## 🔐 Secure Remote Access

For secure external access, I run a WireGuard VPN through a VPS with a static IPv4 address. This lets me:
- Connect back home from anywhere    
- Route selected traffic over WireGuard
- Secure inbound services without exposing ports directly

I will detail the setup in part 4 when we have a look at the overall networking infrastructure.

We will also look at other deployed mechanism to harden the overall security of my homelab in the final part of this series, f.e. securing SSH access to my machines. 