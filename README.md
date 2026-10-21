# patch_php.sh

Script para aplicar actualizaciones de seguridad de PHP en servidores
Debian/Ubuntu (VPS propios, no hosting compartido/cPanel gestionado por
terceros), con registro automático de la versión antes y después de
la actualización.

Nació a partir del parche de emergencia de PHP del 21 de octubre de
2026 (CVE-2026-109618 y CVE-2026-109619), pero sirve para cualquier
actualización de seguridad de PHP futura.

## Qué hace

1. Detecta automáticamente la versión de PHP instalada (`php -v`).
2. Detecta si usas PHP-FPM, y si tu servidor web es Apache o Nginx.
3. Registra un snapshot "ANTES" (versión de PHP, PHP-FPM y paquetes dpkg)
   en un log con timestamp UTC.
4. Ejecuta `apt install --only-upgrade` solo sobre los paquetes de PHP.
5. Reinicia PHP-FPM y el servidor web detectado (esto es crítico: sin
   reiniciar, el binario viejo sigue corriendo en memoria aunque el
   paquete ya esté actualizado).
6. Registra un snapshot "DESPUÉS" para confirmar que el cambio aplicó
   de verdad.

## Uso

```bash
chmod +x patch_php.sh
sudo ./patch_php.sh
```

El log queda en `/var/log/php_patch_log.txt` (podés cambiar la ruta
editando la variable `LOG_FILE` al inicio del script).

## Requisitos / supuestos

- Debian o Ubuntu con PHP instalado vía `apt` (paquete oficial de la
  distro o repositorio de terceros como Sury/Ondrej).
- Permisos de `root` o `sudo`.
- El nombre del paquete de PHP sigue el patrón estándar `phpX.Y`
  (como lo nombran Debian/Ubuntu y el repo de Sury).

## Qué NO hace

- No resuelve el caso de hosting compartido / cPanel administrado por
  un tercero — ahí depende del proveedor, no de este script.
- **No funciona en PHP 8.1 o anterior (EOL).** El script detecta esto
  al inicio y aborta con una advertencia explícita, en vez de fallar
  en silencio o dar una falsa sensación de que quedaste parcheado.
  A partir de PHP 8.2 las ramas tienen soporte activo y reciben
  paquete nuevo por `apt`; 8.1, 8.0 y 7.4 solo reciben backports de
  código fuente del equipo de seguridad de PHP, que hay que aplicar
  a mano, o directamente migrar a una rama soportada (8.2+).
- No reemplaza tener un backup antes de actualizar. Hacé tu backup
  primero, siempre.
- No es un escáner de vulnerabilidades ni valida si tu sistema está
  comprometido — solo automatiza el parcheo y su verificación.

## Por qué existe

Durante incidentes de seguridad críticos (como el de octubre 2026),
la diferencia entre quedar expuesto o no se mide en minutos. Este
script elimina la fricción de "actualizar a mano, revisar versión,
reiniciar, revisar de nuevo" y deja evidencia clara (el log) de que
el parche se aplicó y se verificó, útil tanto para vos como para
mostrarle a un cliente o equipo que el trabajo se hizo.

## Licencia

MIT — usalo, modificalo y compartilo libremente.
