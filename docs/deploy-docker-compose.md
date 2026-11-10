# Production deployment with docker-compose

[← Back to README](../README.md)

This is the full version of the [Self-host in 5 minutes](../README.md#-self-host-in-5-minutes) path in the README: the same docker-compose stack, plus the reverse proxy, updates, source builds, email deliverability and backups.

## Quick start

The stack is defined in the provided `docker-compose.prod.yaml`.

A prebuilt multi-arch image (`linux/amd64` and `linux/arm64`) is published to `ghcr.io/giovantenne/lastsignal`. The `latest` tag always points at the most recent release (also available as `X.Y.Z` and `X.Y`), while `edge` tracks every push to `master`. `docker-compose.prod.yaml` references `latest`, so the command below pulls the prebuilt image; add `--build` to build locally from source instead (see [Building from source](#building-from-source--other-architectures)).

```bash
# Copy and configure environment
cp .env.production.example .env.production
# Edit .env.production with your values (you can ignore KAMAL_* variables)
# Generate the two secrets without a Rails install:
#   openssl rand -hex 32   # RAILS_MASTER_KEY
#   openssl rand -hex 64   # SECRET_KEY_BASE

# Start the stack
docker compose -f docker-compose.prod.yaml --env-file .env.production up -d

# Wait until it is up (the container prepares the databases on first start)
curl -fsS --retry 30 --retry-delay 2 --retry-all-errors http://YOUR_SERVER/up

# View logs
docker compose -f docker-compose.prod.yaml logs -f
```

Health check: `http://YOUR_SERVER/up` (or `https://YOUR_DOMAIN/up` once the reverse proxy is in place).

## Reverse Proxy (SSL/TLS)

For production, place a reverse proxy (nginx, Caddy, Traefik) in front of the app to handle HTTPS. Example with Caddy:

```
yourdomain.com {
    reverse_proxy localhost:80
}
```

Caddy automatically provisions Let's Encrypt certificates.

## Updating

With the prebuilt image, pull the new tag and recreate the container:

```bash
docker compose -f docker-compose.prod.yaml pull
docker compose -f docker-compose.prod.yaml up -d
```

If you build from source instead:

```bash
git pull
docker compose -f docker-compose.prod.yaml --env-file .env.production up -d --build
```

The container entrypoint (`bin/docker-entrypoint`) runs `bin/rails db:prepare` every time the app server starts. It creates or migrates all three SQLite databases (primary, `cache` and `queue`), so a release's migrations are applied automatically on restart and no manual command is needed after an update. Do not run `db:prepare` by hand right after the first `up -d`: it races the entrypoint on a fresh volume.

## Building from source / other architectures

The published image is built for `linux/amd64` and `linux/arm64`, so x86-64 servers, Raspberry Pi 4/5 with a 64-bit OS and Apple Silicon hosts all pull a native image with plain `up -d`. On other architectures, or if you want to run a patched checkout, build the image locally from the repo's `Dockerfile` by adding `--build`:

```bash
docker compose -f docker-compose.prod.yaml --env-file .env.production up -d --build
```

`docker-compose.prod.yaml` declares both `image:` and `build: .`, so plain `up -d` pulls the prebuilt image (building from source only if the pull fails), while `up -d --build` always builds from the current checkout. Everything else in this guide is the same for both.

To run a tag other than `latest`, set `LASTSIGNAL_IMAGE_TAG` in `.env.production` or in the shell; for example `LASTSIGNAL_IMAGE_TAG=edge` runs the current `master` build:

```bash
LASTSIGNAL_IMAGE_TAG=edge docker compose -f docker-compose.prod.yaml --env-file .env.production up -d
```

## Email Deliverability Checklist

Email delivery is mission-critical for LastSignal. If your SMTP setup is misconfigured, messages may never arrive.

Most transactional email providers (such as Postmark, SendGrid, or similar services) guide you through this process and provide the required DNS records and configuration details.

- **SPF**: authorize your SMTP provider to send on your domain
- **DKIM**: enable DKIM signing and add the DNS record
- **DMARC**: start with `p=none`, then tighten to `quarantine` or `reject`
- **From address**: use a domain you control (matches `SMTP_FROM_EMAIL`)

## Storage Backups

The default deployment stores the SQLite database and Active Storage files in the Docker volume `lastsignal_storage`. Back it up regularly.

Backup:

```bash
docker run --rm -v lastsignal_storage:/data -v "$PWD":/backup alpine \
  sh -c "cd /data && tar -czf /backup/lastsignal_storage.tgz ."
```

Restore:

```bash
docker run --rm -v lastsignal_storage:/data -v "$PWD":/backup alpine \
  sh -c "cd /data && tar -xzf /backup/lastsignal_storage.tgz"
```
