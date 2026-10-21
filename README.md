# patch_php.sh

Script para aplicar actualizaciones de seguridad de PHP en servidores
Debian/Ubuntu (VPS propios, no hosting compartido/cPanel gestionado por
terceros), con registro automático de la versión antes y después de
la actualización.

Nació a partir del parche de emergencia de PHP del 21 de octubre de
2026 (CVE-2026-109618 y CVE-2026-109619), pero sirve para cualquier
actualización de seguridad de PHP futura.

## Contexto

El 21 de octubre de 2026 el equipo de seguridad de PHP publicó las
versiones **8.5.12, 8.4.27, 8.3.36 y 8.2.35**, que corrigen dos
vulnerabilidades críticas (CVE-2026-109618 y CVE-2026-109619, CVSS v4.0
9.2) que pueden permitir ejecución remota de código sin autenticación.

Fuente oficial: [php.net](https://www.php.net/)

## Ejemplo real

Salida del log en un servidor Ubuntu 22.04, antes y después de correr
el script (PHP 8.4.24 → 8.4.27, CLI y FPM):

![Log antes/después del parcheo](patch_php.jpeg)

## Qué hace

1. Detecta automáticamente la versión de PHP instalada (`php -v`).
2. Detecta si usás PHP-FPM, y si tu servidor web es Apache o Nginx.
3. Registra un snapshot "ANTES" (versión de PHP, PHP-FPM y paquetes dpkg)
   en un log con timestamp UTC.
4. Ejecuta `apt install --only-upgrade` solo sobre los paquetes de PHP.
5. Reinicia PHP-FPM y el servidor web detectado (esto es crítico: sin
   reiniciar, el binario viejo puede seguir corriendo en memoria aunque
   el paquete ya esté actualizado).
6. Registra un snapshot "DESPUÉS" para confirmar que el cambio aplicó
   de verdad.

## Uso

```bash
chmod +x patch_php.sh
sudo ./patch_php.sh
```

El log queda en `/var/log/php_patch_log.txt` (podés cambiar la ruta
editando la variable `LOG_FILE` al inicio del script).

Al terminar, compará la versión del snapshot "ANTES" con la del
"DESPUÉS" y con la versión corregida publicada en php.net para tu rama.

## Requisitos / supuestos

- Debian o Ubuntu con PHP instalado vía `apt` (paquete de la distro o
  repositorio de terceros como Sury/Ondřej).
- Permisos de `root` o `sudo`.
- El nombre del paquete de PHP sigue el patrón estándar `phpX.Y`
  (como lo nombran Debian/Ubuntu y el repo de Sury).
- Que tu repositorio ya haya publicado el paquete corregido. Si todavía
  no lo hizo, `apt` no va a encontrar nada nuevo y la versión no
  cambia: por eso el log "DESPUÉS" es importante.

## Qué NO hace

- No resuelve el caso de hosting compartido / cPanel administrado por
  un tercero: ahí depende del proveedor, no de este script.
- **No actúa sobre PHP 8.1 o anterior (EOL).** El script detecta esto
  al inicio y aborta con una advertencia explícita, en vez de fallar
  en silencio o dar una falsa sensación de que quedaste parcheado.
  El proyecto PHP no publica correcciones para 8.1 y ramas anteriores;
  la opción es migrar a una rama soportada (8.2 o superior) o consultar
  si el mantenedor de tu distribución ofrece un paquete con el fix
  portado.
- No reemplaza tener un backup antes de actualizar. **Hacé tu backup
  primero, siempre**, y si podés probá antes en un entorno de staging.
- No es un escáner de vulnerabilidades ni valida si tu sistema está
  comprometido: solo automatiza el parcheo y su verificación.

## Por qué existe

Durante incidentes de seguridad críticos (como el de octubre de 2026),
la diferencia entre quedar expuesto o no se mide en minutos. Este
script elimina la fricción de "actualizar a mano, revisar versión,
reiniciar, revisar de nuevo" y deja evidencia clara (el log) de que
el parche se aplicó y se verificó, útil tanto para vos como para
mostrarle a un cliente o equipo que el trabajo se hizo.

## Contacto

¿Necesitás parchear o revisar tus servidores PHP/Linux?
Ofrezco parcheo con informe antes/después, auditoría básica y
configuración de servidores (VPS).

- Email: izdirtxhx@proton.me
- X: @IzDirtHxH

## Licencia

MIT: usalo, modificalo y compartilo libremente. Ver el archivo
[LICENSE](LICENSE).
