# Production deployment with Kamal

[← Back to README](../README.md)

[Kamal](https://kamal-deploy.org) builds the image from your checkout, pushes it to your container registry, deploys it over SSH and puts its own proxy with automatic TLS in front of the app. Clone the repository first; the commands below run from the repo root.

You only need Docker, SSH access, and a reliable SMTP provider.

Kamal docs: https://kamal-deploy.org

## 1) Prepare the server

- Provision a Linux host (Ubuntu 22.04+ recommended)
- Install Docker and open ports 80/443
- Point DNS to the server IP (A/AAAA records)

## 2) Configure environment

Copy the template and fill in the required values:

```bash
cp .env.production.example .env.production
```

You must set:

- `KAMAL_*` (image, registry, server, domain)
- `APP_BASE_URL` and `APP_HOST`
- `SMTP_*` (your provider credentials)
- `ALLOWED_EMAILS` (optional allowlist for private instances)

Generate `RAILS_MASTER_KEY` and `SECRET_KEY_BASE` with `openssl` (no Rails install needed; the repo ships no `config/credentials.yml.enc`, so any random value works):

```bash
openssl rand -hex 32   # RAILS_MASTER_KEY
openssl rand -hex 64   # SECRET_KEY_BASE
```

## 3) Deploy

```bash
bin/kamal setup
bin/kamal deploy
```

## 4) Prepare the databases

```bash
bin/kamal app exec --interactive --reuse "bin/rails db:prepare"
bin/kamal app exec --interactive --reuse "bin/rails db:prepare DATABASE=cache"
bin/kamal app exec --interactive --reuse "bin/rails db:prepare DATABASE=queue"
```

## 5) Verify

```bash
bin/kamal logs
```

Health check: `https://YOUR_DOMAIN/up`

## Email deliverability and backups

These apply to Kamal deployments exactly as they do to docker-compose ones. Kamal mounts the same `lastsignal_storage` Docker volume (see `config/deploy.yml`), so the backup commands work unchanged:

- [Email Deliverability Checklist](deploy-docker-compose.md#email-deliverability-checklist)
- [Storage Backups](deploy-docker-compose.md#storage-backups)
