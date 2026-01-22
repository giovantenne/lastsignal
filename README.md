# LastSignal

A self-hostable "dead man's switch" application. Users create encrypted messages for recipients, and if they stop responding to periodic check-ins, the system automatically delivers those messages.


## Tech Stack

- Ruby on Rails 8
- PostgreSQL
- Redis + Sidekiq (background jobs)
- Tailwind CSS
- libsodium (client-side crypto)

## Requirements

- Ruby 3.4+
- PostgreSQL 16+
- Redis 7+
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

Start the containers first:

```bash
docker compose up -d db redis
bin/setup
```

The setup script installs dependencies, prepares the development and test databases, and clears logs/tempfiles. It uses default values for `PGHOST`, `PGUSER`, and `PGPASSWORD` if not set.

### Start the development stack

Start everything with a single command using foreman:

```bash
bin/dev
```

This will automatically:
- Start PostgreSQL and Redis containers (if not running)
- Start Rails server on port 3000
- Start Tailwind CSS watcher
- Start Sidekiq worker

Then open http://localhost:3000

#### Manual startup (alternative)

If you prefer to start services separately:

```bash
# Terminal 1: Start containers
docker compose up -d db redis

# Terminal 2: Start Rails
PGHOST=localhost PGUSER=lastsignal PGPASSWORD=lastsignal_dev bin/rails server

# Terminal 3: Start Sidekiq
PGHOST=localhost PGUSER=lastsignal PGPASSWORD=lastsignal_dev bundle exec sidekiq

# Terminal 4: Rails console (with DB env)
bin/console
```

## Test Environment

Run all tests with:

```bash
bin/test
```

This will automatically start the containers if needed.

### Test options

```bash
bin/test                                # Run all tests
bin/test spec/models/                   # Run model tests only
bin/test spec/models/user_spec.rb       # Run specific file
bin/test spec/models/user_spec.rb:19    # Run specific test
bin/test --format documentation         # Detailed output
```

## Production Deployment

### Deploy with Kamal

Kamal is the recommended path for production deployments.

1) Install Kamal (once per workstation):
```bash
gem install kamal
```

2) Configure `config/deploy.yml`:
- Set `image` to your registry image name (e.g. `ghcr.io/you/lastsignal_app`).
- Update `servers.web` with your host(s).
- Set `proxy.host` to your public domain.
- Ensure `env.clear` includes `APP_BASE_URL`, `SMTP_*`, and `REDIS_URL` if needed.

3) Create secrets in `.kamal/secrets`:
```bash
KAMAL_REGISTRY_PASSWORD=your-registry-token
RAILS_MASTER_KEY=your-master-key
```

4) Build and deploy:
```bash
bin/kamal setup
bin/kamal deploy
```

5) Prepare the production database:
```bash
bin/kamal app exec --interactive --reuse "bin/rails db:prepare"
```

6) View logs:
```bash
bin/kamal logs
```

### Environment Variables

All configuration lives in `.env.example`. Copy it to `.env` and edit values.

**Core**
- `APP_BASE_URL` - Base URL for link generation
- `APP_HOST` - Hostname for DNS rebinding protection and email links
- `SECRET_KEY_BASE` - Generate with `bin/rails secret`
- `RAILS_MASTER_KEY` - Production master key for credentials

**Services**
- `DATABASE_URL` - PostgreSQL connection string
- `REDIS_URL` - Redis connection string
- `SMTP_*` - SMTP configuration for mail delivery

**Authentication**
- `MAGIC_LINK_TTL_MINUTES` - Magic link expiration window
- `ALLOWED_EMAILS` - Optional comma-separated allowlist for private instances

**Check-in Engine**
- `CHECKIN_DEFAULT_*` - Defaults applied to new users
- `CHECKIN_MIN_*` / `CHECKIN_MAX_*` - Bounds for user settings

**Security / Integrations**
- `ARGON2ID_OPS_LIMIT`, `ARGON2ID_MEM_LIMIT` - Client-side KDF parameters
- `EMAIL_WEBHOOK_SECRET` - Optional webhook authentication secret

Refer to `.env.example` for the full list and inline comments.


## License

MIT
