#!/usr/bin/env bash
#
# patch_php.sh
# Actualiza PHP (cualquier versión instalada vía apt) y registra un log
# con versión "antes" y "después" de la instalación, incluyendo
# verificación real del binario cargado en memoria tras el reinicio.
#
# Soporta: Debian/Ubuntu con PHP instalado vía apt (paquete oficial o
# repositorio Sury/Ondrej). Detecta automáticamente la versión de PHP
# instalada y el servidor web en uso (Apache o Nginx).
#
# Uso:
#   sudo ./patch_php.sh
#
# Log de salida: /var/log/php_patch_log.txt (configurable abajo)

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Ejecuta este script como root (sudo)." >&2
  exit 1
fi

LOG_FILE="/var/log/php_patch_log.txt"

# --- Detectar versión de PHP instalada ---------------------------------
PHP_BIN=$(command -v php || true)
if [[ -z "$PHP_BIN" ]]; then
  echo "No se encontró el binario 'php' en el PATH. Abortando." >&2
  exit 1
fi

PHP_VERSION=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
PHP_PKG="php${PHP_VERSION}"

echo "Detectado PHP ${PHP_VERSION}"

# --- Chequeo de EOL: 8.1 y versiones anteriores no reciben paquete nuevo --
# A partir de PHP 8.2 las ramas tienen soporte activo y los parches de
# seguridad salen como paquete nuevo (lo que este script actualiza).
# PHP 8.1, 8.0 y 7.4 ya están EOL: el equipo de PHP solo libera backports
# de código fuente para esas ramas, no un paquete que "apt upgrade" pueda
# instalar. Si ese es tu caso, este script no te sirve: hay que aplicar
# el backport manualmente o migrar a una rama soportada (8.2+).
PHP_MAJOR="${PHP_VERSION%%.*}"
PHP_MINOR="${PHP_VERSION##*.}"
if (( PHP_MAJOR < 8 || (PHP_MAJOR == 8 && PHP_MINOR < 2) )); then
  cat >&2 <<EOF

[ADVERTENCIA] PHP ${PHP_VERSION} está fuera de soporte oficial (EOL).
No existe paquete nuevo para esta rama, así que 'apt install --only-upgrade'
no va a traer el parche de seguridad.

Opciones:
  1) Aplicar manualmente el backport de código fuente que publique el
     equipo de seguridad de PHP para esta vulnerabilidad específica.
  2) Migrar a una rama con soporte activo (PHP 8.2 o superior).

Este script no continúa para evitar dar una falsa sensación de que
quedaste parcheado. Abortando.
EOF
  exit 1
fi

# --- Detectar si existe el servicio FPM correspondiente -----------------
FPM_SERVICE=""
if systemctl cat "php${PHP_VERSION}-fpm.service" &>/dev/null; then
  FPM_SERVICE="php${PHP_VERSION}-fpm"
fi

# --- Detectar servidor web activo ---------------------------------------
WEB_SERVICE=""
if systemctl is-active --quiet apache2 2>/dev/null; then
  WEB_SERVICE="apache2"
elif systemctl is-active --quiet nginx 2>/dev/null; then
  WEB_SERVICE="nginx"
fi

# --- Función auxiliar: snapshot de versiones -----------------------------
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

# --- Antes ----------------------------------------------------------------
snapshot "ANTES"

# --- Actualizar -------------------------------------------------------------
export DEBIAN_FRONTEND=noninteractive
apt update
apt install --only-upgrade "${PHP_PKG}*" "libapache2-mod-${PHP_PKG}" -y \
  -o Dpkg::Options::="--force-confold"

# --- Reiniciar servicios ----------------------------------------------------
if [[ -n "$FPM_SERVICE" ]]; then
  systemctl restart "$FPM_SERVICE"
  echo "Reiniciado: $FPM_SERVICE"
fi

if [[ -n "$WEB_SERVICE" ]]; then
  systemctl restart "$WEB_SERVICE"
  echo "Reiniciado: $WEB_SERVICE"
fi

if [[ -z "$FPM_SERVICE" && -z "$WEB_SERVICE" ]]; then
  echo "AVISO: no se detectó php-fpm ni apache2/nginx activos. Reinicia manualmente el servicio que sirve PHP." >&2
fi

# --- Después ------------------------------------------------------------
snapshot "DESPUES"

echo ""
echo "Log completo en: $LOG_FILE"
echo "---"
tail -n 40 "$LOG_FILE"

if [[ -n "$FPM_SERVICE" ]]; then
  PID=$(systemctl show "$FPM_SERVICE" -p MainPID --value)
  echo "Binario en ejecución: $(readlink /proc/$PID/exe)" | tee -a "$LOG_FILE"
fi
