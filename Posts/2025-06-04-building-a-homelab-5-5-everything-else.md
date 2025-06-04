---
color: C07309
date: 2025-06-04T18:15:00Z
description: A blog post series about my journey building a homelab
project: true
title: Building a homelab (5/5): Everything else
category: homelab
slug: building-a-homelab-5-5-everything-else
---

> Why did the homelabber bring a book to the server room? Because with so much to learn, they needed a backup plan for their brain!

In the last 4 blog posts we learned a lot about building a homelab and what even is possible. However there are still a lot of topics to dive into. In this last post I want to have a quick look at a few of them.

## Task scheduling with cron

On my homeserver I not only run a handful of services I also need to schedule tasks throughout the day. These involve the renovate bot discussed in part 2 but also backup tasks etc. When implementing this I took a deep dive into cron which I want to share with you here. 

`cron` is a time-based job scheduler in Unix-like systems, including Ubuntu. It allows users and administrators to schedule scripts or commands to run at specific times or intervals automatically. It is widely used for repetitive tasks like backups, system maintenance, or monitoring.

Ubuntu uses `cron` via the `cron` package, which installs the daemon and required configuration directories.

### Adding a New Cron Job (Using `/etc/cron.d/`)

To add a system-level cron job, create a file in `/etc/cron.d/`:

#### Example: `/etc/cron.d/myjob`

```cron
# Run a script every day at 2:30 AM
30 2 * * * root /usr/local/bin/myscript.sh
```

- The file must be owned by `root` and should have permissions `644`.
- Always specify the **user** to run the command (e.g., `root`, `ubuntu`, etc.).

Set permissions with:

```bash
sudo chmod 644 /etc/cron.d/myjob
sudo chown root:root /etc/cron.d/myjob
```

### Cron Timing Syntax

<table>
  <thead>
    <tr>
      <th>Field</th>
      <th>Allowed Values</th>
      <th>Description</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Minute</td>
      <td>0–59</td>
      <td>Minute of the hour</td>
    </tr>
    <tr>
      <td>Hour</td>
      <td>0–23</td>
      <td>Hour of the day</td>
    </tr>
    <tr>
      <td>Day of Month</td>
      <td>1–31</td>
      <td>Day of the month</td>
    </tr>
    <tr>
      <td>Month</td>
      <td>1–12 or Jan–Dec</td>
      <td>Month of the year</td>
    </tr>
    <tr>
      <td>Day of Week</td>
      <td>0–7 or Sun–Sat</td>
      <td>Day of the week (0 or 7 is Sunday)</td>
    </tr>
  </tbody>
</table>

#### Special Symbols

<table>
  <thead>
    <tr>
      <th>Symbol</th>
      <th>Meaning</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>`*`</td>
      <td>Every possible value</td>
    </tr>
    <tr>
      <td>`,`</td>
      <td>Value list separator</td>
    </tr>
    <tr>
      <td>`-`</td>
      <td>Range of values</td>
    </tr>
    <tr>
      <td>`/`</td>
      <td>Step values (e.g., `*/5`)</td>
    </tr>
  </tbody>
</table>

### Checking if a Cron Job Runs

1. **Check Logs**

```bash
grep CRON /var/log/syslog
```

Or for recent entries:

```bash
journalctl -u cron.service
```

2. **Add Logging in Your Script**

Add output redirection in your cron job:

```cron
30 2 * * * root /usr/local/bin/myscript.sh >> /var/log/myscript.log 2>&1
```

### Restarting Cron to Enable New Jobs

After adding or modifying files in `/etc/cron.d/`, restart the cron service:

```bash
sudo systemctl restart cron
```

To check cron status:

```bash
systemctl status cron
```

Ensure that the new job file is valid and has the proper permissions. Invalid files or missing users will cause the job to be ignored.


## Rotating log files with logrotate

`logrotate` is a utility used on Ubuntu (and other Linux distributions) to manage the automatic rotation, compression, removal, and mailing of log files. It helps prevent logs from consuming too much disk space and keeps log directories organized.

On Ubuntu, `logrotate` is typically run daily via a cron job managed by `systemd` timer units.

Ubuntu uses `systemd` to manage scheduled tasks. You can check the timer for logrotate using:

```bash
systemctl status logrotate.timer
```

### Defining a Custom Rule

To rotate logs for a custom application, create a file in `/etc/logrotate.d/`:

#### Example: `/etc/logrotate.d/myapp`

```conf
/var/log/myapp/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 myuser mygroup
    sharedscripts
    postrotate
        systemctl reload myapp.service > /dev/null 2>/dev/null || true
    endscript
}
```

#### Explanation of Options

<table>
  <thead>
    <tr>
      <th>Option</th>
      <th>Description</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>`daily`</td>
      <td>Rotate logs every day</td>
    </tr>
    <tr>
      <td>`missingok`</td>
      <td>Do not show error if log file is missing</td>
    </tr>
    <tr>
      <td>`rotate 14`</td>
      <td>Keep 14 old log files before deleting</td>
    </tr>
    <tr>
      <td>`compress`</td>
      <td>Compress rotated logs (using gzip by default)</td>
    </tr>
    <tr>
      <td>`delaycompress`</td>
      <td>Delay compression until the next rotation (useful with apps that keep logs open)</td>
    </tr>
    <tr>
      <td>`notifempty`</td>
      <td>Do not rotate empty log files</td>
    </tr>
    <tr>
      <td>`create`</td>
      <td>Create a new log file with specified permissions and ownership</td>
    </tr>
    <tr>
      <td>`sharedscripts`</td>
      <td>Run `postrotate` script once, even if multiple logs are matched</td>
    </tr>
    <tr>
      <td>`postrotate`</td>
      <td>Script to run after rotation (e.g., to reload services)</td>
    </tr>
  </tbody>
</table>

### Testing a Logrotate Rule

To simulate and debug log rotation without making changes:

```bash
sudo logrotate -d /etc/logrotate.conf
```

To force log rotation:

```bash
sudo logrotate -f /etc/logrotate.conf
```

To test a specific configuration file:

```bash
sudo logrotate -d /etc/logrotate.d/myapp
```

Check `/var/lib/logrotate/status` to see the last time files were rotated.

## Proxmox Hypervisor

As a blogger showcasing my private homelab, I can confidently say that Proxmox Hypervisor is a game-changer for anyone looking to dive into virtualization. Being open-source, it not only provides a cost-effective solution but also comes with a thriving community that’s always ready to help and share knowledge. The combination of KVM and LXC allows me to run both virtual machines and containers seamlessly, while its user-friendly web interface makes management a breeze. With features like live migration and built-in backup solutions, I can experiment with different setups without worrying about downtime. Proxmox has truly empowered my homelab journey, making it a solid choice for maximizing my hardware and exploring new possibilities!

## Backups

I’ve implemented a robust 3-2-1 backup strategy using two Synology NAS storage solutions alongside a Proxmox Backup Server for all my VMs running in the Proxmox Hypervisor. This approach ensures that I have three copies of my data, stored on two different types of media, with one copy kept offsite for added security. 

The Proxmox Backup Server allows for incredibly fast snapshot backups, enabling me to capture the state of my VMs almost instantly without significant downtime.

To ensure the integrity of my backups, I regularly verify checksums, which helps confirm that my data is stable and recoverable. 

In the event of a failure, restoring from these backups is straightforward and efficient, giving me peace of mind that my homelab is well-protected against data loss. This comprehensive backup strategy not only safeguards my projects but also allows me to experiment and innovate without fear!

## Hardening SSH access

Hardening SSH access to my private machines is essential for enhancing security, and there are a few straightforward steps I take to achieve this. 

First, I change the default SSH port from 22 to something less predictable by creating a separate configuration file in the `/etc/ssh/sshd_config.d/` directory, which allows me to add my custom settings without cluttering the main `sshd_config` file. This modular approach not only keeps my configurations organized but also makes it easier to manage and troubleshoot changes in the future. 

Next, I create a convenient SSH config file at `~/.ssh/config` to streamline my connections, adding entries like `Host myserver` followed by `HostName myserver.example.com` and `Port 2222` (or whatever port I chose). 

Most importantly, I configure SSH to use only public key authentication by setting `PasswordAuthentication no` in my custom config file. This approach significantly reduces the risk of brute-force attacks, as it requires a private key for access, making it a best practice for securing my homelab environment.

## Filesystems

### Btrfs on Synology NAS

In my homelab, I run Btrfs on two Synology NAS machines, taking advantage of its advanced features like snapshotting, built-in RAID, and efficient data compression. Btrfs allows me to create point-in-time snapshots of my data, making it easy to roll back to previous states in case of accidental deletions or corruption. Additionally, its self-healing capabilities ensure data integrity by automatically detecting and repairing errors, providing me with peace of mind.

### ZFS on Proxmox Host

On my Proxmox host, I utilize ZFS on NVMe SSDs, which offers exceptional performance and reliability. ZFS is renowned for its robust data protection features, including checksumming for data integrity and the ability to create snapshots and clones efficiently. The combination of ZFS's advanced RAID options allows me to choose an appropriate RAID type that balances redundancy and performance, ensuring that my virtual machines are both fast and secure.

### Redundancy and Reliability

By leveraging both Btrfs and ZFS, I have created a resilient storage architecture in my homelab. The RAID configurations on both systems provide redundancy, safeguarding my data against hardware failures while allowing me to enjoy the unique strengths of each filesystem. This thoughtful approach to storage not only enhances performance but also ensures that my data remains safe and accessible, no matter the circumstances.