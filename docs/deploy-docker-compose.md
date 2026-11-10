# Production deployment with docker-compose

[← Back to README](../README.md)

This is the full version of the [Self-host in 5 minutes](../README.md#-self-host-in-5-minutes) path in the README: the same docker-compose stack, plus the reverse proxy, updates, source builds, email deliverability and backups.

## Quick start

If you prefer not to use Kamal, you can deploy with docker-compose using the provided `docker-compose.prod.yaml`.

A prebuilt `linux/amd64` image is published to `ghcr.io/giovantenne/lastsignal`. The `latest` tag always points at the most recent release (also available as `X.Y.Z` and `X.Y`), while `edge` tracks every push to `master`. `docker-compose.prod.yaml` references `latest`, so the command below pulls the prebuilt image; add `--build` to build locally from source instead (see [Building from source](#building-from-source--other-architectures)).

```bash
# Copy and configure environment
cp .env.production.example .env.production
# Edit .env.production with your values (you can ignore KAMAL_* variables)
# Generate the two secrets without a Rails install:
#   openssl rand -hex 32   # RAILS_MASTER_KEY
#   openssl rand -hex 64   # SECRET_KEY_BASE

# Start the stack
docker compose -f docker-compose.prod.yaml --env-file .env.production up -d

# Prepare databases (first run only)
docker compose -f docker-compose.prod.yaml exec app bin/rails db:prepare
docker compose -f docker-compose.prod.yaml exec app bin/rails db:prepare DATABASE=cache
docker compose -f docker-compose.prod.yaml exec app bin/rails db:prepare DATABASE=queue

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

The container entrypoint (`bin/docker-entrypoint`) runs `bin/rails db:prepare` for the **primary** database every time the app server starts, so migrations to the main database are applied automatically on restart. The `cache` and `queue` databases are separate SQLite files with their own migration paths and are **not** covered by the entrypoint. If a release ships migrations for them, run the two commands again after the update (running all three is harmless; `db:prepare` is idempotent):

```bash
docker compose -f docker-compose.prod.yaml exec app bin/rails db:prepare DATABASE=cache
docker compose -f docker-compose.prod.yaml exec app bin/rails db:prepare DATABASE=queue
```

## Building from source / other architectures

The published image is `linux/amd64` only. On other architectures (for example an arm64 host such as a Raspberry Pi or an Apple Silicon machine), or if you want to run a patched checkout, build the image locally from the repo's `Dockerfile` by adding `--build`:

```bash
docker compose -f docker-compose.prod.yaml --env-file .env.production up -d --build
```

`docker-compose.prod.yaml` declares both `image:` and `build: .`, so plain `up -d` pulls the prebuilt image (building from source only if the pull fails), while `up -d --build` always builds from the current checkout. Everything else in this guide is the same for both.

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
