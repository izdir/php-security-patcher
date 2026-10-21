# patch_php.sh

A script to apply PHP security updates on Debian/Ubuntu servers (your own
VPS, not shared hosting or third-party-managed cPanel), with automatic
logging of the PHP version before and after the update.

It was born out of the emergency PHP patch of October 21, 2026
(CVE-2026-109618 and CVE-2026-109619), but it works for any future PHP
security update.

## Background

On October 21, 2026, the PHP project released versions
**8.5.12, 8.4.27, 8.3.36 and 8.2.35**, which fix two critical remote code
execution vulnerabilities (CVSS v4.0 9.2):

- **CVE-2026-109618** ([GHSA-w8hw-w9fx-j79w](https://github.com/php/php-src/security/advisories/GHSA-w8hw-w9fx-j79w)):
  memory corruption when `memory_limit` is reached. On Apache with
  mod_php, an unauthenticated request can trigger it before any
  application code runs. RCE was also confirmed on PHP-FPM through
  application code paths.
- **CVE-2026-109619** ([GHSA-6wmf-4rv5-p3rp](https://github.com/php/php-src/security/advisories/GHSA-6wmf-4rv5-p3rp)):
  stale state after a fatal error that allows a use-after-free in a
  later request handled by the same worker.

Official sources:

- [Announcement on php.net](https://www.php.net/archive/2026.php#2026-10-21-5)
- [The PHP Foundation blog post](https://thephp.foundation/blog/2026/10/21/todays-php-security-release-and-how-were-strengthening-php-security/)

## Real-world example

Log output on an Ubuntu 22.04 server, before and after running the
script (PHP 8.4.24 → 8.4.27, CLI and FPM):

![Before/after patch log](patch_php.jpeg)

## What it does

1. Checks that it is running as `root` and aborts if not.
2. Automatically detects the installed PHP version (`php -r`).
3. Detects whether you use PHP-FPM, and whether your web server is
   Apache or Nginx.
4. Writes a "BEFORE" snapshot (PHP version, PHP-FPM version and dpkg
   packages) to a log file with a UTC timestamp.
5. Runs `apt update` and `apt install --only-upgrade` only on the
   `phpX.Y*` packages and `libapache2-mod-phpX.Y` (if you use mod_php),
   in non-interactive mode and keeping your existing configuration files
   (`--force-confold`).
6. Restarts PHP-FPM and the detected web server. This step is critical:
   without a restart, the old binary can keep running in memory even
   though the package has already been upgraded.
7. Writes an "AFTER" snapshot and checks `/proc/<PID>/exe` to confirm that
   the running FPM process is using the new binary (if it shows
   `(deleted)`, the old one is still running).

## Usage

```bash
chmod +x patch_php.sh
sudo ./patch_php.sh
```

The log is saved to `/var/log/php_patch_log.txt` (you can change the
path by editing the `LOG_FILE` variable at the top of the script).

When it finishes, compare the version in the "BEFORE" snapshot with the
"AFTER" one, and with the fixed version published on php.net for your
branch.

## Requirements / assumptions

- Debian or Ubuntu with PHP installed via `apt` (the distro package or a
  third-party repository such as Sury/Ondřej).
- `root` or `sudo` privileges.
- PHP packages follow the standard `phpX.Y` naming pattern (as used by
  Debian/Ubuntu and the Sury repo).
- Your repository must already have published the fixed package. If it
  hasn't yet, `apt` won't find anything new and the version won't
  change, which is why the "AFTER" log matters.
- If a package ships changes to a configuration file, the script keeps
  your current version (`--force-confold`). Check afterwards whether the
  new package offers options you might want.
- The log is append-only: every run adds a new BEFORE/AFTER block.

## What it does NOT do

- It does not cover shared hosting or cPanel managed by a third party:
  there it depends on your provider, not on this script.
- **It does not act on PHP 8.1 or earlier (EOL).** The script detects
  this at startup and aborts with an explicit warning, instead of failing
  silently or giving you a false sense of being patched. The PHP project
  does not publish fixes for 8.1 and earlier branches; your options are
  to migrate to a supported branch (8.2 or higher) or to ask whether
  your distribution's maintainer offers a package with the fix
  backported.
- It does not replace having a backup before updating. **Take your
  backup first, always**, and if you can, test in a staging environment
  beforehand.
- It is not a vulnerability scanner and does not check whether your
  system has been compromised: it only automates patching and its
  verification.

## Why it exists

During critical security incidents (like the one in October 2026), the
difference between being exposed or not is measured in minutes. This
script removes the friction of "update by hand, check the version,
restart, check again" and leaves clear evidence (the log) that the patch
was applied and verified, useful both for yourself and for showing a
client or team that the job was done.

## Contact

Need help patching or reviewing your PHP/Linux servers? I offer patching
with a before/after report, basic audits and server (VPS) setup.

- Email: izdirtxhx@proton.me
- X: @IzDirtHxH

## License

MIT: use it, modify it and share it freely. See the
[LICENSE](LICENSE) file.
