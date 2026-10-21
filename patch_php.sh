#!/usr/bin/env bash
#
# patch_php.sh
# Actualiza PHP (cualquier versión instalada vía apt) y registra un log
# con la versión "antes" y "después" de la actualización, reiniciando
# PHP-FPM y el servidor web para que el binario nuevo quede en uso.
#
# Soporta: Debian/Ubuntu con PHP instalado vía apt (paquete de la distro o
# repositorio Sury/Ondrej). Detecta automáticamente la versión de PHP
# instalada y el servidor web en uso (Apache o Nginx).
#
# Uso:
#   sudo ./patch_php.sh
#
# Log de salida: /var/log/php_patch_log.txt (configurable abajo)

set -euo pipefail

LOG_FILE="/var/log/php_patch_log.txt"

# --- Requiere root -----------------------------------------------------
if [[ "${EUID}" -ne 0 ]]; then
  echo "Este script necesita permisos de root. Ejecutalo con: sudo $0" >&2
  exit 1
fi

# --- Detectar versión de PHP instalada ---------------------------------
PHP_BIN=$(command -v php || true)
if [[ -z "$PHP_BIN" ]]; then
  echo "No se encontró el binario 'php' en el PATH. Abortando." >&2
  exit 1
fi

PHP_VERSION=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
PHP_PKG="php${PHP_VERSION}"
echo "Detectado PHP ${PHP_VERSION}"

# --- Chequeo de EOL: 8.1 y anteriores no tienen fix oficial de PHP ------
# El proyecto PHP publica correcciones solo para las ramas con soporte
# (8.2 o superior al momento de escribir esto). Para 8.1 y anteriores
# no existe una versión corregida oficial, así que 'apt install
# --only-upgrade' no puede traer ese parche desde el proyecto PHP.
PHP_MAJOR="${PHP_VERSION%%.*}"
PHP_MINOR="${PHP_VERSION##*.}"
if (( PHP_MAJOR < 8 || (PHP_MAJOR == 8 && PHP_MINOR < 2) )); then
  cat >&2 <<EOF
[ADVERTENCIA] PHP ${PHP_VERSION} está fuera de soporte oficial (EOL).
El proyecto PHP no publica una versión corregida para esta rama, así que
este script no puede garantizar que quedes parcheado.

Opciones:
  1) Migrar a una rama con soporte (PHP 8.2 o superior).
  2) Consultar si el mantenedor de tu distribución (Debian/Ubuntu) ofrece
     un paquete con el fix portado para tu versión.

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
apt update
DEBIAN_FRONTEND=noninteractive apt install --only-upgrade "${PHP_PKG}*" -y

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
  echo "AVISO: no se detectó php-fpm ni apache2/nginx activos. Reiniciá manualmente el servicio que sirve PHP." >&2
fi

# --- Después ------------------------------------------------------------
snapshot "DESPUES"

echo ""
echo "Log completo en: $LOG_FILE"
echo "---"
tail -n 40 "$LOG_FILE"
