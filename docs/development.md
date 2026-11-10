# Development

[← Back to README](../README.md)

This runs a local dev stack and opens emails in your browser using [letter_opener](https://github.com/ryanb/letter_opener).

## Requirements

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

## Run the stack

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

## Docker (Quick trial with Mailhog)

If you want to try the app without installing Ruby locally, use the dev compose stack with [Mailhog](https://github.com/mailhog/MailHog):

```bash
docker compose -f docker-compose.dev.yaml up --build
```

Then open:

- App: http://localhost:3000
- Mailhog inbox: http://localhost:8025

## E2EE demo flow (Dev / Docker)

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
bin/rails demo:checkins:deliver EMAIL=you@example.com
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

## Tests

```bash
# Full suite
bin/test

# Targeted specs
bin/test spec/models/user_spec.rb
bin/test spec/jobs/process_checkins_job_spec.rb
bin/test spec/requests/auth_spec.rb
```
