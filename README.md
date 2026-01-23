# LastSignal

A self-hostable "dead man's switch" application. Users create encrypted messages for recipients, and if they stop responding to periodic check-ins, the system automatically delivers those messages.


## Tech Stack

- Ruby on Rails 8
- SQLite
- Solid Queue + Solid Cache
- Tailwind CSS
- libsodium (client-side crypto)

## Requirements

- Ruby 3.4+
- SQLite 3 (sqlite3 gem >= 2.1)
- Node.js (for Tailwind)

## Development Environment

### 1. Clone and install dependencies

```bash
cd lastsignal
bundle install
```

### 2. Configure environment

```bash
cp .env.example .env
# Edit .env with your values
```

### 3. Run the setup script (recommended)

```bash
bin/setup
```

The setup script installs dependencies, prepares the SQLite databases, and clears logs/tempfiles.

### Start the development stack

Start everything with a single command using foreman:

```bash
bin/dev
```

This will automatically:
- Start Rails server on port 3000
- Start Tailwind CSS watcher
- Start Solid Queue worker

Then open http://localhost:3000

#### Manual startup (alternative)

If you prefer to start services separately:

```bash
# Terminal 1: Start Rails
bin/rails server

# Terminal 2: Start Solid Queue
bin/rails solid_queue:start

# Terminal 3: Rails console
bin/console
```

## Test Environment

Run all tests with:

```bash
bin/test
```


### Test options

```bash
bin/test                                # Run all tests
bin/test spec/models/                   # Run model tests only
bin/test spec/models/user_spec.rb       # Run specific file
bin/test spec/models/user_spec.rb:19    # Run specific test
bin/test --format documentation         # Detailed output
```

## Production Deployment

### Deploy with Kamal (recommended)

Kamal is the supported path for production deployments. The steps below assume a single server and a container registry.

#### Files you will edit

- `.env.production` (deployment + runtime env vars)

`config/deploy.yml` is now generic and reads from `.env.production`, so you typically do not edit it.

#### 1) Prepare the server

- Provision a Linux host (Ubuntu 22.04+ recommended).
- Install Docker and open ports 80/443.
- Point DNS to the server IP (A/AAAA records).

#### 2) Set up a container registry

You need a registry that supports pull access from the server.

Common options:
- GitHub Container Registry: `ghcr.io/ORG/lastsignal_app`
- Docker Hub: `docker.io/ORG/lastsignal_app`
- GitLab Registry: `registry.gitlab.com/ORG/lastsignal_app`

Create a registry token with read/write access. You will place it in `.env.production`.

#### 3) Configure `.env.production`

Copy `.env.production.example` to `.env.production` and fill in:

- `KAMAL_*` (image, registry, server, domain)
- `APP_BASE_URL` and `APP_HOST`
- `SMTP_*` (see email deliverability below)
- `ALLOWED_EMAILS` (optional allowlist for private instances)
- `EMAIL_WEBHOOK_SECRET` (optional)

Generate a master key if you don’t have one:

```bash
bin/rails credentials:edit
```

#### 4) Deploy

```bash
bin/kamal setup
bin/kamal deploy
```


#### 5) Prepare the production database

```bash
bin/kamal app exec --interactive --reuse "bin/rails db:prepare"
bin/kamal app exec --interactive --reuse "bin/rails db:prepare DATABASE=cache"
bin/kamal app exec --interactive --reuse "bin/rails db:prepare DATABASE=queue"
```

#### 6) Verify and monitor

```bash
bin/kamal logs
```

Visit `/up` for the health check.

#### 7) Backup the storage volume

The default deployment stores the SQLite database and Active Storage files in the Docker volume
`lastsignal_app_storage`. Make sure you back up this volume regularly (or mount a host path that is
already part of your backup strategy).

Example backup command (creates a tarball in the current directory):

```bash
docker run --rm -v lastsignal_app_storage:/data -v "$PWD":/backup alpine \
  sh -c "cd /data && tar -czf /backup/lastsignal_app_storage.tgz ."
```

Example restore command (from a tarball in the current directory):

```bash
docker run --rm -v lastsignal_app_storage:/data -v "$PWD":/backup alpine \
  sh -c "cd /data && tar -xzf /backup/lastsignal_app_storage.tgz"
```

If you prefer host-based backups, mount a host path instead of a named volume by updating
`volumes` in `config/deploy.yml` (example):

```yaml
volumes:
  - "/var/lib/lastsignal/storage:/rails/storage"
```

### Email deliverability checklist

To avoid spam filtering, configure DNS for your SMTP domain:

- **SPF**: authorize your SMTP provider to send on your domain
- **DKIM**: enable DKIM signing in the provider and add the DNS record
- **DMARC**: set at least `p=none` to monitor, then tighten to `quarantine` or `reject`
- **From address**: use a domain you control (matches `SMTP_FROM_EMAIL`)

Most providers (Postmark, SES, Mailgun) give exact DNS records to copy.

### Defaults

Timing, rate-limit, and crypto defaults live in `config/initializers/app_defaults.rb`. Update that file to change:

- Check-in interval, grace, cooldown defaults and bounds
- Magic link TTL and invite token TTL
- Trusted contact ping/pause defaults and bounds
- Rate limiting thresholds
- Argon2id KDF parameters
- CSP report-only toggle


## License

MIT
