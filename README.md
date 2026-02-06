# <img src="https://lastsignal.app/logo-mark.svg" alt="LastSignal" width="50" height="50" align="absmiddle" /> LastSignal

[![Ruby](https://img.shields.io/badge/Ruby-3.4-red.svg)](https://www.ruby-lang.org/) [![Rails](https://img.shields.io/badge/Rails-8-red.svg)](https://rubyonrails.org/) [![Database](https://img.shields.io/badge/Database-SQLite-blue.svg)](https://www.sqlite.org/) [![Crypto](https://img.shields.io/badge/Crypto-libsodium-black.svg)](https://libsodium.gitbook.io/doc/) [![Deploy](https://img.shields.io/badge/Deploy-Kamal-success.svg)](https://kamal-deploy.org/) [![License: BSL 1.1](https://img.shields.io/badge/License-BSL%201.1-blue.svg)](https://mariadb.com/bsl11/)

LastSignal is a self-hosted, email-first dead man's switch. You write encrypted messages for the people you care about. If you stop responding to email check-ins, LastSignal delivers those messages automatically.

Website: [lastsignal.app](https://lastsignal.app)

## 📬 Email-First Flow (Quick Overview)

1) System emails you periodic check-ins.
2) If you miss them, you receive reminder attempts at a fixed interval.
3) The final reminder triggers the trusted contact ping (if configured).
4) If you still don't respond, messages are delivered by email.

## 🔒 Security Model

- **End-to-end encrypted** - Server never sees plaintext messages
- **Zero-knowledge architecture** - Even the operator can't read your data
- **Modern cryptography** - Argon2id (256MB) + XChaCha20-Poly1305 + X25519
- **Auditable** - Audit the code yourself

**⚠️ Critical: Strong Passphrases Required**

LastSignal uses a **server-generated KDF salt** stored alongside recipient public keys. This is a deliberate architectural trade-off that enables deterministic key regeneration from passphrases, but it introduces a specific threat:
**if an attacker gains access to the database** (via server compromise, data breach, malicious operator, or law enforcement request), they obtain the salt and can attempt **offline brute-force attacks** against recipient passphrases without any rate limiting.

**[Full Security Documentation →](https://lastsignal.app/security)**

## ⏱️ Default Timing (Days)

All timing settings are configurable per user in Account Settings.

| Setting | Default |
| --- | --- |
| Check-in interval | 30 days |
| Reminder attempts | 3 (includes the first reminder) |
| Attempt interval | 7 days |
| Trusted contact pause | 15 days |

Example timeline:

| Event | Date | State |
| --- | --- | --- |
| Last check-in | Apr 1 | 🟢 Active |
| Reminder #1 | May 1 | 🟢 Active |
| Reminder #2 | May 8 | 🟡 Grace |
| Reminder #3 (final + trusted contact ping) | May 15 | 🟠 Cooldown |
| Delivery (if no response) | May 22 | 🔴 Delivered |

If the trusted contact confirms on May 16:

| Event | Date | State |
| --- | --- | --- |
| Delivery paused until | May 31 | 🟠 Cooldown (paused) |
| New trusted contact ping | May 31 | 🟠 Cooldown |
| Delivery unless the user checks in or the trusted contact confirms again | Jun 7 | 🔴 Delivered |

**Recipient-specific delay**: You can also set a delay (in days) per recipient. This delays when the recipient can decrypt the message after delivery—useful for staggered access or time-sensitive information.

## 🧪 Development

This runs a local dev stack and opens emails in your browser using [letter_opener](https://github.com/ryanb/letter_opener).

### Requirements

- Ruby 3.4+
- SQLite 3 (sqlite3 gem >= 2.1)
- Node.js (for Tailwind)

Example for a fresh Ubuntu install:

```bash
apt-get update && apt-get install -y \
  git \
  ruby \
  bundler \
  libyaml-dev
```

### Run the stack

```bash
git clone https://github.com/giovantenne/lastsignal.git
cd lastsignal
bundle install
cp .env.example .env
bin/setup
bin/dev
```

Then open http://localhost:3000 and request a magic link. 
The email opens in your browser automatically via `letter_opener`.

### Docker (Quick trial with Mailhog)

If you want to try the app without installing Ruby locally, use the dev compose stack with [Mailhog](https://github.com/mailhog/MailHog):

```bash
docker compose -f docker-compose.dev.yaml up --build
```

Then open:

- App: http://localhost:3000
- Mailhog inbox: http://localhost:8025

### E2EE demo flow (Dev / Docker)

This lets you test the full check-in -> delivery flow quickly, without waiting days.

Prereqs:

1) Start the stack.
2) Log in, add a recipient, accept the invite with a passphrase, and create a message for that recipient.
   Check-ins are skipped unless there is at least one message linked to an accepted recipient.
Dev commands:

```bash
bin/rails demo:checkins:status EMAIL=you@example.com
bin/rails demo:checkins:advance EMAIL=you@example.com
bin/rails demo:checkins:advance_days EMAIL=you@example.com DAYS=7
bin/rails demo:checkins:deliver EMAIL=you@example.com`
```

Docker commands:

```bash
docker compose -f docker-compose.dev.yaml exec app bin/rails demo:checkins:status EMAIL=you@example.com
docker compose -f docker-compose.dev.yaml exec app bin/rails demo:checkins:advance EMAIL=you@example.com
docker compose -f docker-compose.dev.yaml exec app bin/rails demo:checkins:advance_days EMAIL=you@example.com DAYS=7
docker compose -f docker-compose.dev.yaml exec app bin/rails demo:checkins:deliver EMAIL=you@example.com
```

Notes:

- Each `advance` sends the next email in the sequence (reminder -> grace -> cooldown -> delivery).
- `advance_days` simulates time passing by N days and runs the check-in job.
- To skip straight to delivery: `bin/rails demo:checkins:deliver EMAIL=you@example.com`
- Emails open in letter_opener (Dev) or Mailhog (Docker).
- Demo helpers only run in development/test.

### Tests

```bash
# Full suite
bin/test

# Targeted specs
bin/test spec/models/user_spec.rb
bin/test spec/jobs/process_checkins_job_spec.rb
bin/test spec/requests/auth_spec.rb
```

## 🚀 Production Deployment (Kamal)

You only need Docker, SSH access, and a reliable SMTP provider.

Kamal docs: https://kamal-deploy.org

### 1) Prepare the server

- Provision a Linux host (Ubuntu 22.04+ recommended)
- Install Docker and open ports 80/443
- Point DNS to the server IP (A/AAAA records)

### 2) Configure environment

Copy the template and fill in the required values:

```bash
cp .env.production.example .env.production
```

You must set:

- `KAMAL_*` (image, registry, server, domain)
- `APP_BASE_URL` and `APP_HOST`
- `SMTP_*` (your provider credentials)
- `ALLOWED_EMAILS` (optional allowlist for private instances)

Generate a master key if you don't have one:

```bash
bin/rails credentials:edit
```

### 3) Deploy

```bash
bin/kamal setup
bin/kamal deploy
```

### 4) Prepare the databases

```bash
bin/kamal app exec --interactive --reuse "bin/rails db:prepare"
bin/kamal app exec --interactive --reuse "bin/rails db:prepare DATABASE=cache"
bin/kamal app exec --interactive --reuse "bin/rails db:prepare DATABASE=queue"
```

### 5) Verify

```bash
bin/kamal logs
```

Health check: `https://YOUR_DOMAIN/up`

## 🐳 Production Deployment (docker-compose)

If you prefer not to use Kamal, you can deploy with docker-compose using the provided `docker-compose.prod.yaml`.

```bash
# Copy and configure environment
cp .env.production.example .env.production
# Edit .env.production with your values (you can ignore KAMAL_* variables)

# Start the stack
docker compose -f docker-compose.prod.yaml --env-file .env.production up -d --build

# Prepare databases (first run only)
docker compose -f docker-compose.prod.yaml exec app bin/rails db:prepare
docker compose -f docker-compose.prod.yaml exec app bin/rails db:prepare DATABASE=cache
docker compose -f docker-compose.prod.yaml exec app bin/rails db:prepare DATABASE=queue

# View logs
docker compose -f docker-compose.prod.yaml logs -f
```

### Reverse Proxy (SSL/TLS)

For production, place a reverse proxy (nginx, Caddy, Traefik) in front of the app to handle HTTPS. Example with Caddy:

```
yourdomain.com {
    reverse_proxy localhost:80
}
```

Caddy automatically provisions Let's Encrypt certificates.

## 📮 Email Deliverability Checklist

Email delivery is mission-critical for LastSignal. If your SMTP setup is misconfigured, messages may never arrive.

Most transactional email providers (such as Postmark, SendGrid, or similar services) guide you through this process and provide the required DNS records and configuration details.

- **SPF**: authorize your SMTP provider to send on your domain
- **DKIM**: enable DKIM signing and add the DNS record
- **DMARC**: start with `p=none`, then tighten to `quarantine` or `reject`
- **From address**: use a domain you control (matches `SMTP_FROM_EMAIL`)

## 💾 Storage Backups

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

## ⚙️ Defaults

Timing, rate-limit, and crypto defaults live in `config/initializers/app_config.rb`.

## 🤝 Contributing

Contributions welcome! Please open an issue first to discuss changes.

## 📄 License

This project is licensed under the Business Source License 1.1 (BSL 1.1). Commercial use and offering this software as a hosted service require prior written permission. On 2031-01-23 the license changes to MIT.

See [LICENSE](LICENSE) for details.

## ⚠️ Disclaimer

LastSignal is provided "as is" without warranty of any kind. The authors provide only the source code and do not host, operate or monitor the server on your behalf. All email delivery is performed by your self-hosted instance and your chosen SMTP provider.

By using this project, you accept full responsibility for configuration, security, backups, content, recipients, compliance obligations, and the consequences of any delivery or non-delivery. The authors disclaim all liability for damages, data loss, missed or premature delivery, misuse, or any other outcome, whether arising from bugs, misconfiguration, third-party outages, or operational errors.

LastSignal is not a substitute for a will, trust, power of attorney, or any other legal instrument. It is not legally binding and should not be relied upon to transfer rights, property, or obligations. If you need legal certainty, consult a qualified attorney and use appropriate legal documents.


## 🧡 Donate

If you find **LastSignal** useful and want to support its development, you can donate via ₿itcoin:

`bc1qt6z0e5ttcjx0cnwjdl8mua2srt0lamah5lnnvm`

Donations help support ongoing maintenance, security reviews, and long-term sustainability of the project. 
Thank you 🙏
