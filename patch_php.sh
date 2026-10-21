#!/usr/bin/env bash
#
# patch_php.sh
# Updates PHP (any version installed via apt) and writes a log with the
# "before" and "after" versions of the installation, including a real
# check of the binary loaded in memory after the restart.
#
# Supports: Debian/Ubuntu with PHP installed via apt (official package or
# the Sury/Ondrej repository). Automatically detects the installed PHP
# version and the web server in use (Apache or Nginx).
#
# Usage:
#   sudo ./patch_php.sh
#
# Output log: /var/log/php_patch_log.txt (configurable below)

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Run this script as root (sudo)." >&2
  exit 1
fi

LOG_FILE="/var/log/php_patch_log.txt"

# --- Detect installed PHP version ---------------------------------------
PHP_BIN=$(command -v php || true)
if [[ -z "$PHP_BIN" ]]; then
  echo "The 'php' binary was not found in PATH. Aborting." >&2
  exit 1
fi

PHP_VERSION=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
PHP_PKG="php${PHP_VERSION}"

echo "Detected PHP ${PHP_VERSION}"

# --- EOL check: 8.1 and earlier get no fixed package ----------------------
# From PHP 8.2 onward, the branches still receive security fixes and those
# fixes ship as a new package (which is what this script upgrades).
# PHP 8.1, 8.0 and 7.4 are EOL: the PHP project does not publish fixes for
# these branches, so there is no new package for "apt upgrade" to install.
# If that is your case, this script won't help: your options are to
# migrate to a supported branch (8.2+) or to check whether your
# distribution's maintainer offers a package with the fix backported.
PHP_MAJOR="${PHP_VERSION%%.*}"
PHP_MINOR="${PHP_VERSION##*.}"
if (( PHP_MAJOR < 8 || (PHP_MAJOR == 8 && PHP_MINOR < 2) )); then
  cat >&2 <<EOF

[WARNING] PHP ${PHP_VERSION} is out of official support (EOL).
The PHP project publishes no fixes for this branch, so
'apt install --only-upgrade' will not bring in the security patch.

Options:
  1) Migrate to a supported branch (PHP 8.2 or higher).
  2) Check whether your distribution's maintainer offers a package
     with the fix backported.

This script will not continue, to avoid giving you a false sense of
being patched. Aborting.
EOF
  exit 1
fi

# --- Detect whether the matching FPM service exists -----------------------
FPM_SERVICE=""
if systemctl cat "php${PHP_VERSION}-fpm.service" &>/dev/null; then
  FPM_SERVICE="php${PHP_VERSION}-fpm"
fi

# --- Detect the active web server -----------------------------------------
WEB_SERVICE=""
if systemctl is-active --quiet apache2 2>/dev/null; then
  WEB_SERVICE="apache2"
elif systemctl is-active --quiet nginx 2>/dev/null; then
  WEB_SERVICE="nginx"
fi

# --- Helper function: version snapshot --------------------------------------
snapshot() {
  local label="$1"
  {
    echo "===== ${label}: $(date -u '+%Y-%m-%d %H:%M:%S UTC') ====="
    php -v
    if [[ -n "$FPM_SERVICE" ]] && command -v "php-fpm${PHP_VERSION}" &>/dev/null; then
      "php-fpm${PHP_VERSION}" -v
    fi
    dpkg -l | grep -E "^ii\s+php${PHP_VERSION}" || true
    echo ""
  } >> "$LOG_FILE" 2>&1
}

# --- Before -----------------------------------------------------------------
snapshot "BEFORE"

# --- Upgrade ----------------------------------------------------------------
export DEBIAN_FRONTEND=noninteractive
apt update
apt install --only-upgrade "${PHP_PKG}*" "libapache2-mod-${PHP_PKG}" -y \
  -o Dpkg::Options::="--force-confold"

# --- Restart services ---------------------------------------------------------
if [[ -n "$FPM_SERVICE" ]]; then
  systemctl restart "$FPM_SERVICE"
  echo "Restarted: $FPM_SERVICE"
fi

if [[ -n "$WEB_SERVICE" ]]; then
  systemctl restart "$WEB_SERVICE"
  echo "Restarted: $WEB_SERVICE"
fi

if [[ -z "$FPM_SERVICE" && -z "$WEB_SERVICE" ]]; then
  echo "WARNING: no active php-fpm or apache2/nginx detected. Restart the service that serves PHP manually." >&2
fi

# --- After --------------------------------------------------------------------
snapshot "AFTER"

echo ""
echo "Full log at: $LOG_FILE"
echo "---"
tail -n 40 "$LOG_FILE"

if [[ -n "$FPM_SERVICE" ]]; then
  PID=$(systemctl show "$FPM_SERVICE" -p MainPID --value)
  echo "Running binary: $(readlink /proc/$PID/exe)" | tee -a "$LOG_FILE"
fi
