# Claude guidance for this repository

## Project Overview

Two Factor is a WordPress plugin that enables two-factor authentication
using TOTP, FIDO U2F/WebAuthn, email, and backup verification codes.
This is a fork (dknauss/two-factor) of the official WordPress.org
Two Factor plugin.

**Requirements:** WordPress 6.8+, PHP 7.2+

## Commands

```bash
composer install         # Install dev dependencies
composer lint            # PHPCS (WPCS + VIP + PHPCompatibility)
composer lint-compat     # PHP compatibility check (7.2+)
composer lint-phpstan    # PHPStan (with --memory-limit=1G)
composer test            # PHPUnit with coverage text output
```

## Design Intent Review

- Before writing or substantially changing code, briefly restate the problem and name the intended approach in 2–4 sentences.
- Ask whether new code is necessary before implementing. Prefer deletion, simplification, configuration, or reuse when they solve the problem cleanly.
- After implementation, explain whether the intended approach was followed. If the implementation changed, explain why.
- Call out key tradeoffs, likely failure modes, and why this approach is better than the most obvious naive alternative.

## Simplicity First

- Always ask: Is this the simplest solution?
- Prefer fewer moving parts, less abstraction, and less code when they satisfy the requirement.
- If no code is the best code, say so explicitly and prefer that outcome.
- Do not add indirection, generic abstraction, or framework machinery unless it clearly earns its cost.

## Commit Practices

- Use conventional commit format.
- Run tests and static analysis before every commit.

## Architecture

**Entry point:** `two-factor.php` — registers constants, loads providers and core class.

### Core Classes

- **Two_Factor_Core** (`class-two-factor-core.php`) — Main class. Handles provider registration, login interception, user profile 2FA settings, revalidation flow, nonce verification, and session management.
- **Two_Factor_Compat** (`class-two-factor-compat.php`) — Compatibility shims for older WordPress versions.

### Providers (in `providers/`)

Each provider extends `Two_Factor_Provider`:
- **Two_Factor_Totp** — Time-based one-time passwords (TOTP).
- **Two_Factor_FIDO_U2F** — FIDO U2F hardware keys.
- **Two_Factor_Backup_Codes** — One-time backup verification codes.
- **Two_Factor_Email** — Email-based verification codes.
- **Two_Factor_Dummy** — Test/development provider.

## Testing

Integration tests in `tests/` use WordPress test suite (`WP_UnitTestCase`).
Test files follow the `class-two-factor-*.php` naming convention.
Requires one-time WP test suite setup.

<!-- claude-playwright-handoff -->
## Browser and Playwright handoff

If a task in this repository requires browser automation, Playwright testing, screenshots, page interaction, or browser-only inspection:

- Say clearly that a fresh browser-capable Claude session is required.
- Do not imply that Playwright or browser mode can be enabled from inside the current session.
- Tell the user to restart with `/Users/danknauss/bin/claude-playwright` or `/Users/danknauss/bin/claude-browser-handoff`.

Use this only when browser tooling is actually needed, not when it is merely convenient.
