# LastSignal

A self-hostable "dead man's switch" application. Users create encrypted messages for recipients, and if they stop responding to periodic check-ins, the system automatically delivers those messages.

## Features

- **Magic link authentication** - No passwords, just email
- **Client-side encryption** - Messages encrypted in the browser using libsodium (XChaCha20-Poly1305)
- **Recipient key derivation** - Recipients derive keys from a passphrase using Argon2id
- **Configurable check-in intervals** - Set your own schedule for check-ins
- **Grace period & cooldown** - Multiple chances before delivery
- **Trusted Contact** - Optional trusted person can confirm you're alive and delay delivery
- **Panic revoke** - Cancel delivery during cooldown period

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

## Setup

### 1. Clone and install dependencies

```bash
cd lastsignal_app
bundle install
```

### 2. Configure environment

```bash
cp .env.example .env
# Edit .env with your values
```

### 3. Setup database

```bash
docker compose up -d db redis
PGHOST=localhost PGUSER=lastsignal PGPASSWORD=lastsignal_dev bin/rails db:setup
```

## Development

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

### Manual startup (alternative)

If you prefer to start services separately:

```bash
# Terminal 1: Start containers
docker compose up -d db redis

# Terminal 2: Start Rails
PGHOST=localhost PGUSER=lastsignal PGPASSWORD=lastsignal_dev bin/rails server

# Terminal 3: Start Sidekiq
PGHOST=localhost PGUSER=lastsignal PGPASSWORD=lastsignal_dev bundle exec sidekiq
```

## Running Tests

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

### With Docker Compose

```bash
cp .env.example .env
# Configure production values in .env

docker compose up --build
```

### Environment Variables

See `.env.example` for all available configuration options:

- `APP_HOST` - Your domain (e.g., lastsignal.example.com)
- `SECRET_KEY_BASE` - Generate with `bin/rails secret`
- `DATABASE_URL` - PostgreSQL connection string
- `REDIS_URL` - Redis connection string
- `SMTP_*` - Email configuration

## Architecture

### State Machine

Users progress through states based on check-in behavior:

```
active -> grace -> cooldown -> delivered
   ^        |         |
   |        v         v
   +--- (check-in) ---+
              |
              v
         (panic revoke)
```

### Encryption Flow

1. **Recipient accepts invite**: Enters passphrase, Argon2id derives seed, X25519 keypair generated, public key stored
2. **Sender creates message**: Content encrypted with XChaCha20-Poly1305, message key wrapped with recipient's public key
3. **Delivery**: Recipient enters passphrase, regenerates keypair, unseals message key, decrypts content

## License

MIT
