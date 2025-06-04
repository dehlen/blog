---
color: C07309
date: 2025-06-04T14:15:00Z
description: A blog post series about my journey building a homelab
project: true
title: Building a homelab (2/5): Renovate and Komodo for Auto Deployments (GitOps) 
category: homelab
slug: building-a-homelab-2-5-gitops-renovate-and-komodo-for-auto-deployments
---

# Building a Homelab (2/5): Renovate and Komodo for Auto Deployments (GitOps)  

> If it is not in git it doesn't exist.

Keeping containers updated in a homelab can quickly become a chore — especially when you’re managing multiple services, distributed across devices, and sensitive to downtime. That’s why I adopted a GitOps workflow using [Renovate](https://github.com/renovatebot/renovate) for updates and [Komodo](https://komo.do) to orchestrate my Docker Compose deployments.

This post will walk you through how I’ve set that up: from repo layout to cron jobs to automatic deployments across my Pi nodes and main VM.

## 🛠️ Repo Structure

I manage everything via a single GitHub repository that acts as the source of truth for my homelab. Here’s a simplified structure:

```
.
├── README.md
├── containers
│   ├── dns01
│   ├── dns02
│   └── srv-prod-01
├── docs
│   ├── attachments
│   ├── docker
│   ├── machines
│   ├── misc
│   ├── network
│   ├── services
│   └── tasks
├── dotfiles
│   ├── bash_aliases
│   └── gitconfig
├── komodo.toml
├── renovate.json
├── scripts
│   └── update-komodo.sh
└── tasks
    ├── deprecated
    ├── docker-cleanup
    ├── dsm-config-backup
    ├── github-backup
    ├── ip-backup
    ├── monitor-remote-backup
    ├── renovate
    ├── rss-backup
    └── vps
```

Each stack has its own compose.yaml and optionally an .env file. This allows me to keep configurations isolated per node and have Komodo pick them up automatically.
The whole Komodo configuration is also stored in this repository (komodo.toml). This allows me to even create new docker-compose projects just by pushing to the git repository.

## 🔄 Automated Updates with Renovate

[Renovate](https://github.com/renovatebot/renovate) is a powerful dependency updater that I run on a schedule via cron. It scans all Docker Compose files and automatically:

- Detects outdated images
- Creates pull requests with version bumps
- Groups updates if desired (e.g., all linuxserver.io containers)

To set this up I added a renovate.json in the root of my repository:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "config:recommended",
    "docker:pinDigests",
    "docker:enableMajor"
  ],
  "labels": [
    "renovate"
  ],
  "dependencyDashboard": true,
  "ignoreTests": true,
  "enabledManagers": [
    "docker-compose",
    "pip_requirements",
    "custom.regex"
  ],
  "customManagers": [
    {
      "customType": "regex",
      "managerFilePatterns": [
        "/^tasks/renovate/entrypoint\\.sh$/"
      ],
      "matchStrings": [
	"RENOVATE_VERSION=\"(?<currentValue>.*?)(?:@(?<currentDigest>sha256:[a-f0-9]+))?\""
      ],
      "depNameTemplate": "renovate/renovate",
      "autoReplaceStringTemplate": "RENOVATE_VERSION=\"{{{newValue}}}@{{{newDigest}}}\"",
      "datasourceTemplate": "docker"
    }
  ],
  "docker-compose": {
    "managerFilePatterns": [
      "/(^|/)(?:docker-)?compose[^/]*\\.ya?ml(?:.j2)?$/"
    ]
  },
  "packageRules": [
    {
      "matchDatasources": ["docker"],
      "matchUpdateTypes": ["digest"],
      "enabled": false
    }
  ]
}
```

I then added a new cronjob on my main server to trigger the renovatebot every 30 minutes:

```
*/30 * * * * root /opt/repos/homelab/tasks/renovate/entrypoint.sh >> /mnt/data/Logs/tasks/renovate.log 2>&1
```

The entrypoint.sh script triggers the renovatebot via docker:
```sh
RENOVATE_VERSION="40.40.1@sha256:ef85bf681b6a94e1a2a8afdcdeff8caa2fb92d7926538657671e8118ea03dffd"

docker run --rm \
  --env-file "${ENV_FILE}" \
  -v "${CONFIG_JS_FILE}:/usr/src/app/config.js" \
  "renovate/renovate:${RENOVATE_VERSION}"
```

This ultimately results in Pull Requests like the following:

<div class="image">
    <img loading="lazy" width="463.5" src="/img/building-a-homelab/renovate-pull-request.png" alt="An image showing a pull request a renovate bot added to a GitHub repository.">
</div>

When I merge one of these PRs, it triggers Komodo to redeploy only the affected stack — no need for a full redeploy or even SSHing into anything.

## 🦖 Komodo: Deploying to the Edge

[Komodo](https://komo.do) is the core deployment engine. Think of it like a minimal orchestrator for docker-compose, but smarter and Git-aware.

- The central agent runs on the Ubuntu VM
- The periphery agents run on my Raspberry Pis
- All agents receive their stack definitions from the GitHub repo

When a PR is merged and the repository is synced, Komodo checks which stacks changed and selectively redeploys them on the right nodes.

### How it knows what to redeploy:

- Each stack is tagged with a deployment target (e.g., pi-dns1, core, etc.)
- Komodo watches the main branch and computes diffs
- Changed Compose files → redeploy those stacks only

Komodo is setup via systemd or docker compose. I opted for the docker compose approach.

```yaml
services:
  mongo:
    image: mongo:8.0.9@sha256:3e8fd506d185ea100867c9da5f90414cee744d1545449038c60190f3fd3cc274
    container_name: komodo-mongo-db
    labels:
      komodo.skip: # Prevent Komodo from stopping with StopAllContainers
    command: --quiet --wiredTigerCacheSizeGB 0.25
    restart: unless-stopped
    volumes:
      - ${MONGO_DATA_PATH}:/data/db
      - ${MONGO_CONFIG_PATH}:/data/configdb
    environment:
      MONGO_INITDB_ROOT_USERNAME: ${KOMODO_DB_USERNAME}
      MONGO_INITDB_ROOT_PASSWORD: ${KOMODO_DB_PASSWORD}
    networks:
      - internal
  
  core:
    image: ghcr.io/moghtech/komodo-core:1.18.0@sha256:b65ee6d2af592841e610aee19951995ac89fd2046db451b77ccbf82506f19f41
    container_name: komodo
    restart: unless-stopped
    depends_on:
      - mongo
    env_file: ./.env
    environment:
      KOMODO_DATABASE_ADDRESS: mongo:27017
      KOMODO_DATABASE_USERNAME: ${KOMODO_DB_USERNAME}
      KOMODO_DATABASE_PASSWORD: ${KOMODO_DB_PASSWORD}
    networks:
      - proxy
      - internal
      - periphery
    labels:
      - "komodo.skip=true" # Prevent Komodo from stopping with StopAllContainers
      - "traefik.enable=true"
      - "traefik.http.routers.komodo.rule=Host(`mydomain.de`)"
      - "traefik.http.routers.komodo.entrypoints=https"
      - "traefik.http.routers.komodo.tls=true"
      - "traefik.http.services.komodo.loadbalancer.server.port=9120"
      - "traefik.docker.network=proxy"
    volumes:
      - ${REPO_CACHE_PATH}:/repo-cache

  komodo-ntfy:
    image: foxxmd/komodo-ntfy-alerter:0.0.8@sha256:df8dc93c22c23092c9e19c1b4581c30a04be125f8cfee57cd8537b8abbdb5b16
    container_name: komodo-ntfy
    restart: unless-stopped
    env_file:
      - ./.env
    networks:
      - internal
    ports:
      - "7000:7000"

networks:
  proxy:
    external: true
  periphery:
    external: true
  internal:
```

On all machines runs a periphery agent to connect those servers to the core komodo instance:

```yaml
services:
  periphery:
    image: ghcr.io/moghtech/komodo-periphery:1.18.0@sha256:fb12dd26fcb964ac95c0c669cca6efd4dc8c9e3a147f7873835f23727058292f
    container_name: periphery
    labels:
      komodo.skip: # Prevent Komodo from stopping with StopAllContainers
    restart: unless-stopped
    env_file: ./.env
    networks:
      - periphery
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /proc:/proc
      - ${PERIPHERY_ROOT_DIRECTORY:-/etc/komodo}:${PERIPHERY_ROOT_DIRECTORY:-/etc/komodo}
      - ${PERIPHERY_REPO_DIR:-/etc/komodo/repos}:${PERIPHERY_REPO_DIR:-/etc/komodo/repos}

networks:
  periphery:
    external: true
```

I then configured the Komodo instance through the UI. I added a Resource Sync to automatically sync changes made in the Komodo UI to my GitHub repository. Next I added alerters (via ntfy) to get notifications whenever an interesting update happens through Komodo. I also added my GitHub repository and my docker compose stacks to Komodo. Last but not least I added a procedure to run hourly to check for updates in the GitHub repository and redeploy any changed stacks. Here is the configuration for this specific action:

```toml
[[procedure]]
name = "pull-and-deploy"
description = "Pulls stack-repo, deploys stacks"
config.schedule = "0 0 * * * *"
config.schedule_format = "Cron"

[[procedure.config.stage]]
name = "Pull Repo"
enabled = true
executions = [
  { execution.type = "PullRepo", execution.params.repo = "homelab", enabled = true }
]

[[procedure.config.stage]]
name = "Update Stacks"
enabled = true
executions = [
  { execution.type = "BatchDeployStackIfChanged", execution.params.pattern = "*", enabled = true }
]

[[procedure.config.stage]]
name = "Prune System"
enabled = true
executions = [
  { execution.type = "PruneSystem", execution.params.server = "dns01", enabled = true },
  { execution.type = "PruneSystem", execution.params.server = "dns02", enabled = true },
  { execution.type = "PruneSystem", execution.params.server = "srv-prod-01", enabled = true }
]
```

<div class="image">
    <img loading="lazy" width="463.5" src="/img/building-a-homelab/komodo.png" alt="An image showing the Komodo web UI.">
</div>

## 🔁 The Full Update Lifecycle

1. Renovate runs via cron and checks for new image tags
2. It creates a PR in GitHub with the updated image version
3. I review and merge the PR
4. Komodo pulls the updated config
5. It calculates diffs and triggers a targeted redeploy
6. The updated service is rebuilt and restarted

Zero manual SSH needed. Logs and container status can be checked in Dozzle from any machine (more on that in a later part).

## ✅ Why This Works So Well

- Idempotency: The same inputs always yield the same stack state
- Minimal intervention: I only merge PRs, the rest is automated
- Fast rollback: Revert a commit → auto rollback
- Clear audit trail: Everything is version-controlled in Git

## 🔜 Up Next: Services That Power the Homelab

In the next post, I’ll break down the actual containers I run, how they’re distributed across machines, and how I handle DNS, logging, and synchronization (like AdGuardHome Sync across two Pis).