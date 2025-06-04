---
color: C07309
date: 2025-06-04T14:15:00Z
description: A blog post series about my journey building a homelab
project: true
title: Building a homelab (1/5): The big picture 
category: homelab
slug: building-a-homelab-1-5-the-big-picture
---

# Building a Homelab (1/5): The Big Picture 

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
    <tr>
        <td>Device</td>
        <td>Role</td>
    </tr>
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

| Service          | Description                    |
| ---------------- | ------------------------------ |
| ArchiveBox       | Bookmark Archival              |
| Audiobookshelf   | Audiobook Management           |
| Calibre          | EBook Management               |
| Dozzle           | Logs Monitoring                |
| Homeassistant    | Homeautomation, HomeKit Bridge |
| Homepage         | Home Dashboard                 |
| Immich           | Photo Library                  |
| Jellyfin         | Media Server                   |
| Komodo           | Docker Management              |
| Komodo Periphery | Docker Management Agent        |
| Komodo ntfy      | Alerter Bridge                 |
| Libation         | Audibook Downloader            |
| Mealie           | Recipe Management              |
| MeTube           | Video & Audio Downloader       |
| Miniflux         | RSS                            |
| ntfy             | Push Service                   |
| Paperless        | Document Management            |
| Penpot           | Design Tool                    |
| SABnzbd          | Usenet Downloader              |
| Traefik          | Reverse Proxy, SSL, etc.       |
| Tubesync         | Video & Audio Downloader       |
| Uptime Kuma      | Monitoring                     |
| Vaultwarden      | Password Management            |

### RPI DNS01

| Service           | Description              |
| ----------------- | ------------------------ |
| Adguard Home      | DNS Server               |
| Adguard Home Sync | Adguard Home Config Sync |
| Dozzle Agent      | Logs Agent               |
| Komodo Periphery  | Docker Management Agent  |

### RPI DNS02

| Service          | Description             |
| ---------------- | ----------------------- |
| Adguard Home     | DNS Server              |
| Dozzle Agent     | Logs Agent              |
| Komodo Periphery | Docker Management Agent |
All service configurations are stored in Git, updated automatically by Renovate, and redeployed via Komodo when changes are merged. We will look at the automation bit in part 2 and the deployed services in part 3 of this blog post series.

## 🔐 Secure Remote Access

For secure external access, I run a WireGuard VPN through a VPS with a static IPv4 address. This lets me:
- Connect back home from anywhere    
- Route selected traffic over WireGuard
- Secure inbound services without exposing ports directly

I will detail the setup in part 4 when we have a look at the overall networking infrastructure.

We will also look at other deployed mechanism to harden the overall security of my homelab in the final part of this series, f.e. securing SSH access to my machines. 