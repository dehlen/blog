---
color: C07309
date: 2025-06-04T14:15:00Z
description: A blog post series about my journey building a homelab
project: true
title: Building a homelab (4/5): Networking, VLANs and VPN 
category: homelab
slug: building-a-homelab-4-5-networking-vlans-and-vpn
---

# Building a Homelab (4/5): Networking, VLANs and VPN 

> Why did the data cross the road? To get to the VLAN on the other side!.

When we moved into our new home new CAT 7 cables were run throughout the whole house. That was the reason I wanted to get into networking infrastructure and to build my home network more professionally. Of course when you setup all this networking infrastructure you want to utilize it as well and so this blog post and my excitement for homelabs was born. When I shopped the new network gear I tried to plan ahead which is why the new devices are all Wifi 7 capable and I am able to utilize 10 GB SFP+ ports on my switch for some devices (f.e. for my NAS). To get things started here is a diagram of the deployed networking infrastructure: 

<div class="image">
    <img loading="lazy" width="463.5" src="/img/building-a-homelab/network.png" alt="An image showing a diagram of my network infrastructure.">
</div>

## VLANs

To segregate my network I make use of VLANs. This is important to me first and foremost to improve the security of my network. F.e. IoT devices do not get access to any other devices in my home. If not necessary they won't get internet access either!

I also deploy a VLAN especially for the devices of my kids. This way I can add specific content filters for their devices which I do not want to deploy on a device to device basis or on the main network. I am able to securely host servers in a DMZ or provide guests with a guest network. At the moment my current setup looks like this:

- VLAN1: Default
- VLAN10: Trusted
- VLAN20: IOT
- VLAN30: Kids
- VLAN90: Guest
- VLAN254: Management

I also disabled the auto-scale network option in the VLAN settings. With that I can set static IPs in the range 192.168.VLANID.1 - 192.168.VLANID.100. Everything above 100 is an IP address provided via DHCP. Whenever I see an IP address in my network I can quickly glance at it and directly extract the information whether it is a static or dynamic IP address and which VLAN it is in.

To secure the VLANs I deploy the new zone-based firewall from Unifi in my network. By default Unifi routes between VLANs. I opted for blocking access between VLANs by default and only allowing the absolute minimum needed. For example my trusted devices can access IoT devices to control the lighting but the lights itself do not have access to any other devices deployed in my infrastructure.

## 🌐 VPN

In a previous part I told you that I run my services in my LAN only. However sometimes you are on the go and still want access to your passwords/media library/etc... .
The problem with most internet service providers in Germany nowadays is that you won't get a static IPv4 address any longer. This isn't technically an issue but it leads to a bit more work for us to successfully connect through a VPN connection into our local network. It boils down to two options:

1. Use a DynDNS service to automatically send your dynamic IPv4 address to this service which then can resolve your current public IPv4 address for a given hostname
2. If you do not get an IPv4 address at all (Carrier Grade NAT) the first solution might not work for you when trying to utilize your VPN connection over IPv6 only. You can use a VPS with a static IPv4 addres however and tunnel all traffic to your home infrastructure through a site-to-site VPN tunnel.

At the moment I could use option 1, however I already know that the ISP bringing fiber optics to our home will only provide CGNat. To be future proof I opted for option 2 and rented a cheap VPS for 0,50€ / month. 

Here are the steps I took to create this tunnel:

1. Install wireguard on VPS
2. Open the wireguard tunnel port in the firewall
3. Create a port forwarding in `/etc/sysctl.conf` to forward all IPv4 traffic
4. Create secure wireguard key pairs
5. Create a wireguard config to connect this wireguard server to a wireguard client in your home network. It is recommended to list every possible peer seperate to be able to better control who has access to this VPN connection
6. Start the wireguard server

I then created a wireguard client on my Unifi Router and connected it to the deployed wireguard server. I also added a static route and the needed firewall rules on my router to be able to access the needed devices in my infrastructure from the private VPN network.

The last step is to add a wireguard client to your private devices and add a config to it. If everything is setup correctly your device (f.e. Smartphone) will connect to the public IPv4 address of your VPS. Every request is then forwarded through the existing VPN tunnel connection to your router where the VPN client is active.

## 📞 Addendum: Telephony

When I migrated from my former setup to the new Unifi devices one problem was left to be solved: telephony. The old router could be used as a telephone base station speaking the DECT protocol. Fortunately my old router has the option to function as an IP-Client and to use an existing internet connection. I set it up like that and disabled any WLAN networks. If you have the same situation in your network currently I strongly suggest to look for an option like that as this setup seems to work perfectly fine.

## ➡️ Up Next

In the last part I want to draw a conclusion and talk about all the topics I did not mention yet: 
- Task scheduling with cron
- Rotating log files with logrotate
- Proxmox Hypervisor
- Backups
- Hardening SSH access
- Filesystems