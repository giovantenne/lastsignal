# <img src="https://lastsignal.app/logo-mark.svg" alt="LastSignal" width="50" height="50" align="absmiddle" /> LastSignal

[![Ruby](https://img.shields.io/badge/Ruby-3.4-red.svg)](https://www.ruby-lang.org/) [![Rails](https://img.shields.io/badge/Rails-8-red.svg)](https://rubyonrails.org/) [![Database](https://img.shields.io/badge/Database-SQLite-blue.svg)](https://www.sqlite.org/) [![Crypto](https://img.shields.io/badge/Crypto-libsodium-black.svg)](https://libsodium.gitbook.io/doc/) [![Deploy](https://img.shields.io/badge/Deploy-Kamal-success.svg)](https://kamal-deploy.org/) [![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

LastSignal is a self-hosted, email-first dead man's switch. You write encrypted messages for the people you care about. If you stop responding to email check-ins, LastSignal delivers those messages automatically.

Website: [lastsignal.app](https://lastsignal.app)

> [!IMPORTANT]
> **LastSignal is open source and self-hosted.**
> The authors do **not** offer any hosted service, SaaS, paid subscription, or commercial instance of LastSignal.
> If you see LastSignal presented elsewhere as a paid hosted product, it is **not** an official LastSignal service.

## 📬 Email-First Flow (Quick Overview)

1) System emails you periodic check-ins.
2) If you miss them, you receive reminder attempts at a fixed interval.
3) The final reminder triggers the trusted contact ping (if configured).
4) If you still don't respond, messages are delivered by email.

For advanced self-hosted setups, you can also generate an optional external keep-alive token and send a
machine-to-machine check-in to `/webhooks/keepalive`. This is an add-on for automations, not a replacement
for the default email-first model.

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

## 🚀 Self-host in 5 minutes

The recommended way to run LastSignal is docker-compose with the prebuilt image `ghcr.io/giovantenne/lastsignal:latest`, which `docker-compose.prod.yaml` already references. You need a Linux host with Docker, a domain pointing at it, and a reliable SMTP provider.

```bash
# 1) Get the files (only docker-compose.prod.yaml and .env.production.example
#    are strictly needed; a full checkout also lets you build from source)
git clone https://github.com/giovantenne/lastsignal.git
cd lastsignal

# 2) Configure (you can ignore the KAMAL_* variables)
cp .env.production.example .env.production
openssl rand -hex 32   # -> RAILS_MASTER_KEY
openssl rand -hex 64   # -> SECRET_KEY_BASE
# Edit .env.production: paste the two secrets, then set APP_BASE_URL, APP_HOST and SMTP_*

# 3) Start the stack (pulls the prebuilt image)
docker compose -f docker-compose.prod.yaml --env-file .env.production up -d

# 4) Prepare the databases (first run only)
docker compose -f docker-compose.prod.yaml exec app bin/rails db:prepare
docker compose -f docker-compose.prod.yaml exec app bin/rails db:prepare DATABASE=cache
docker compose -f docker-compose.prod.yaml exec app bin/rails db:prepare DATABASE=queue

# 5) Check it is up
docker compose -f docker-compose.prod.yaml logs -f
```

Health check: `http://YOUR_SERVER/up` should return `200`.

- The app listens on port 80 without TLS: put a reverse proxy with HTTPS (Caddy, nginx, Traefik) in front of it, see the [compose guide](docs/deploy-docker-compose.md#reverse-proxy-ssltls).
- The prebuilt image is `linux/amd64` only; on other architectures (e.g. arm64) add `--build` to the `up` command to build locally from source instead.
- `latest` is the most recent release (also tagged `X.Y.Z` and `X.Y`); `edge` tracks every push to `master`.
- Updates, backups and the email deliverability checklist are in the [compose guide](docs/deploy-docker-compose.md).

## 🧭 Other ways to run it

- **[Kamal](docs/deploy-kamal.md)**: build and deploy over SSH with Kamal's own TLS proxy, using `config/deploy.yml`.
- **[docker-compose in depth](docs/deploy-docker-compose.md)**: reverse proxy, updating, building from source, email deliverability, storage backups.
- **[Development](docs/development.md)**: local stack with letter_opener, Docker quick trial with Mailhog, the E2EE demo flow and the test suite.

## ⚙️ Defaults

Timing, rate-limit, and crypto defaults live in `config/initializers/app_config.rb`.

## 🤝 Contributing

Contributions welcome! Please open an issue first to discuss changes.

## 📄 License

This project is licensed under the MIT License.

See [LICENSE](LICENSE) for details.

## ⚠️ Disclaimer

LastSignal is provided "as is" without warranty of any kind. The authors provide only the source code and do not host, operate or monitor the server on your behalf. All email delivery is performed by your self-hosted instance and your chosen SMTP provider.

By using this project, you accept full responsibility for configuration, security, backups, content, recipients, compliance obligations, and the consequences of any delivery or non-delivery. The authors disclaim all liability for damages, data loss, missed or premature delivery, misuse, or any other outcome, whether arising from bugs, misconfiguration, third-party outages, or operational errors.

LastSignal is not a substitute for a will, trust, power of attorney, or any other legal instrument. It is not legally binding and should not be relied upon to transfer rights, property, or obligations. If you need legal certainty, consult a qualified attorney and use appropriate legal documents.


## 🧡 Support the Project

If you find **LastSignal** useful, you can support its ongoing maintenance, security reviews, and long-term sustainability through [GitHub Sponsors](https://github.com/sponsors/giovantenne) or with a Bitcoin donation.

See [SUPPORT.md](SUPPORT.md) for donation details. You can also use the **Sponsor** button at the top of the GitHub repository.
