#!/bin/bash
# SessionStart hook for Claude Code on the web.
#
# Installs what `composer lint`, `composer lint-phpstan`, `npm run lint:*` and
# PHPUnit need, without Docker (the web sandbox has no Docker daemon, so the
# wp-env wrappers such as `npm test` cannot run there):
#
# - Composer packages come from git sources. The sandbox proxy blocks GitHub
#   zipball downloads for repositories outside the session, but allows git
#   clones. phpstan/phpstan has no git source in composer.lock, so its dist zip
#   is rebuilt from a clone of the locked commit and placed in Composer's cache.
# - PHPUnit runs against MariaDB and a wordpress-develop checkout, configured
#   like the wp-env tests environment (WP_DEBUG on).
#
# Run tests directly with: vendor/bin/phpunit --filter <name>
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
	exit 0
fi

cd "$CLAUDE_PROJECT_DIR"

export COMPOSER_ALLOW_SUPERUSER=1
export COMPOSER_NO_INTERACTION=1

WP_DEVELOP_DIR="$HOME/.cache/wordpress-develop"
export WP_TESTS_DIR="$WP_DEVELOP_DIR/tests/phpunit"

if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
	{
		echo "export COMPOSER_ALLOW_SUPERUSER=1"
		echo "export WP_TESTS_DIR=\"$WP_TESTS_DIR\""
	} >> "$CLAUDE_ENV_FILE"
fi

# Composer: seed the phpstan/phpstan dist zip, then install from git sources.
seed_dist_from_git() {
	local name="$1" repo="$2"
	local url ref key cache_dir target tmp
	url=$(php -r '$l = json_decode( file_get_contents( "composer.lock" ), true ); foreach ( array_merge( $l["packages"], $l["packages-dev"] ) as $p ) { if ( $p["name"] === $argv[1] ) { echo $p["dist"]["url"]; } }' "$name")
	[ -n "$url" ] || return 0
	ref="${url##*/}"
	key=$(php -r 'echo sha1( $argv[1] );' "$url")
	cache_dir=$(composer config cache-files-dir)
	target="$cache_dir/$name/$key.zip"
	[ -f "$target" ] && return 0
	tmp=$(mktemp -d)
	git init -q "$tmp"
	git -C "$tmp" fetch -q --depth 1 "$repo" "$ref"
	mkdir -p "$(dirname "$target")"
	git -C "$tmp" archive --format=zip --prefix="${name//\//-}-${ref:0:7}/" -o "$target" FETCH_HEAD
	rm -rf "$tmp"
}

seed_dist_from_git phpstan/phpstan https://github.com/phpstan/phpstan
composer install --prefer-source --no-progress

# npm. --no-save keeps package-lock.json untouched (the sandbox npm may be
# older than the one that wrote it). Its preinstall script re-runs
# `composer install`, a no-op by now.
npm install --no-save --no-audit --no-fund

# PHPUnit: MariaDB plus the WordPress test library.
if ! command -v mariadbd >/dev/null 2>&1; then
	apt-get update -qq
	DEBIAN_FRONTEND=noninteractive apt-get install -y -qq mariadb-server >/dev/null
fi
if ! mysqladmin ping --silent 2>/dev/null; then
	service mariadb start >/dev/null
fi
mysql -e "CREATE DATABASE IF NOT EXISTS wordpress_test; CREATE USER IF NOT EXISTS 'wp'@'localhost' IDENTIFIED BY 'wp'; GRANT ALL ON wordpress_test.* TO 'wp'@'localhost';"

# Test against the latest WordPress release, like wp-env's default core. Set
# WP_DEVELOP_REF to a wordpress-develop branch or tag (e.g. trunk) to match a
# different CI matrix leg. The checkout is re-cloned when the ref changes, so
# a new release is picked up by the next session.
WP_DEVELOP_REPO=https://github.com/WordPress/wordpress-develop
WP_DEVELOP_REF_FILE="$WP_DEVELOP_DIR/.wp-develop-ref"
if [ -z "${WP_DEVELOP_REF:-}" ]; then
	WP_DEVELOP_REF=$(git ls-remote --tags --refs "$WP_DEVELOP_REPO" 2>/dev/null | sed 's#.*refs/tags/##' | grep -E '^[0-9]+\.[0-9]+(\.[0-9]+)?$' | sort -V | tail -n 1 || true)
fi
if [ -z "$WP_DEVELOP_REF" ]; then
	# Offline: keep whatever is cached, or fall back to trunk.
	WP_DEVELOP_REF=$(cat "$WP_DEVELOP_REF_FILE" 2>/dev/null || echo trunk)
fi

if [ ! -f "$WP_TESTS_DIR/includes/functions.php" ] || [ "$(cat "$WP_DEVELOP_REF_FILE" 2>/dev/null)" != "$WP_DEVELOP_REF" ]; then
	rm -rf "$WP_DEVELOP_DIR"
	git -c advice.detachedHead=false clone -q --depth 1 --branch "$WP_DEVELOP_REF" --filter=blob:none --sparse "$WP_DEVELOP_REPO" "$WP_DEVELOP_DIR"
	git -C "$WP_DEVELOP_DIR" sparse-checkout set src tests/phpunit/includes tests/phpunit/data
	echo "$WP_DEVELOP_REF" > "$WP_DEVELOP_REF_FILE"
fi

cat > "$WP_DEVELOP_DIR/wp-tests-config.php" <<'PHP'
<?php
define( 'ABSPATH', __DIR__ . '/src/' );
define( 'WP_DEFAULT_THEME', 'default' );
define( 'WP_DEBUG', true );
define( 'DB_NAME', 'wordpress_test' );
define( 'DB_USER', 'wp' );
define( 'DB_PASSWORD', 'wp' );
define( 'DB_HOST', 'localhost' );
define( 'DB_CHARSET', 'utf8' );
define( 'DB_COLLATE', '' );
$table_prefix = 'wptests_';
// Mirror the tests environment in .wp-env.json.
define( 'WP_SITEURL', 'https://example.org' );
define( 'WP_HOME', 'https://example.org' );
define( 'WP_TESTS_DOMAIN', 'example.org' );
define( 'WP_TESTS_EMAIL', 'admin@example.org' );
define( 'WP_TESTS_TITLE', 'Test Blog' );
define( 'WP_PHP_BINARY', 'php' );
define( 'WPLANG', '' );
PHP
