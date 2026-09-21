#!/usr/bin/env bash
# Empaqueta el runtime de Nanis Design (fork de Open Design) en un tar.gz autocontenido.
#
#   uso: scripts/nanis/empaquetar-runtime.sh [<dir-salida>]      (por defecto ./release)
#
# ⚠️ EL TARBALL ES DE LA PLATAFORMA DONDE SE EMPAQUETA (2026-09-21).
# `pnpm deploy --prod` copia node_modules con sus binarios nativos compilados AQUÍ. Si esto se
# ejecuta en un Mac, el `better_sqlite3.node` resultante es de macOS y en Linux el daemon muere
# nada más abrir la BD: «invalid ELF header» (ERR_DLOPEN_FAILED). Pasó en la Legion de Daniela.
# Quien instale en Linux tiene que reconstruir ese módulo: el instalador del Studio lo hace solo
# (dania-studio · scripts/diseno/instalar-linux.sh → reparar_nativos). Si algún día se quiere un
# runtime realmente portable, hay que empaquetar en cada plataforma y publicar dos tarballs, o
# incluir los prebuilds de ambas en el paquete.
#
# Requisitos previos: el workspace compilado (`pnpm --filter @open-design/daemon build` y
# `OD_WEB_OUTPUT_MODE=export pnpm --filter @open-design/web build`).
#
# Layout del tarball (el daemon resuelve la raíz como apps/daemon/dist/../../.. y ahí busca
# los catálogos; la web estática vive en apps/web/out):
#   apps/daemon/{bin,dist,package.json,node_modules}   ← `pnpm deploy --prod` (deps de producción
#                                                        + paquetes del workspace copiados)
#   apps/web/out                                       ← Next.js exportado
#   assets craft design-systems design-templates plugins prompt-templates skills data
#   package.json  NANIS-RUNTIME.json (versión, commit, fecha)
set -euo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SALIDA="${1:-$RAIZ/release}"
VERSION_BASE="$(node -e "console.log(require('$RAIZ/package.json').version)")"
COMMIT="$(git -C "$RAIZ" rev-parse --short HEAD)"
ETIQUETA="${NANIS_RUNTIME_TAG:-$(git -C "$RAIZ" describe --tags --match 'nanis-v*' --exact-match 2>/dev/null || echo "nanis-v$VERSION_BASE-dev")}"
NOMBRE="nanis-design-runtime-${ETIQUETA#nanis-v}"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/nanis-runtime.XXXXXX")"
DEST="$TMP/$NOMBRE"

say() { printf '[empaquetar] %s\n' "$*"; }
[ -f "$RAIZ/apps/daemon/dist/cli.js" ] || { say "falta apps/daemon/dist/cli.js: compila el daemon"; exit 1; }
[ -f "$RAIZ/apps/web/out/index.html" ] || { say "falta apps/web/out/index.html: compila la web en modo export"; exit 1; }

mkdir -p "$DEST/apps" "$SALIDA"
say "daemon → pnpm deploy --prod"
(cd "$RAIZ" && pnpm --filter @open-design/daemon deploy --prod --legacy "$DEST/apps/daemon" >/dev/null)
rm -rf "$DEST/apps/daemon/src" "$DEST/apps/daemon/tests" "$DEST/apps/daemon/tsconfig"*.json 2>/dev/null || true
say "web → apps/web/out"
mkdir -p "$DEST/apps/web"
cp -R "$RAIZ/apps/web/out" "$DEST/apps/web/out"
for d in assets craft design-systems design-templates plugins prompt-templates skills data; do
  if [ -d "$RAIZ/$d" ]; then cp -R "$RAIZ/$d" "$DEST/$d"; fi
done
# Limpieza de lo que no es runtime dentro de los catálogos.
find "$DEST" -name '.DS_Store' -delete 2>/dev/null || true
node -e "const p=require('$RAIZ/package.json');console.log(JSON.stringify({name:'nanis-design',version:p.version,private:true,type:'module'},null,2))" > "$DEST/package.json"
cat > "$DEST/NANIS-RUNTIME.json" <<JSON
{"nombre":"$NOMBRE","versionBase":"$VERSION_BASE","etiqueta":"$ETIQUETA","commit":"$COMMIT","fecha":"$(date -u +%Y-%m-%dT%H:%M:%SZ)"}
JSON
say "comprimiendo…"
tar -C "$TMP" -czf "$SALIDA/$NOMBRE.tar.gz" "$NOMBRE"
(cd "$SALIDA" && shasum -a 256 "$NOMBRE.tar.gz" > "$NOMBRE.tar.gz.sha256")
rm -rf "$TMP"
say "✅ $SALIDA/$NOMBRE.tar.gz ($(du -h "$SALIDA/$NOMBRE.tar.gz" | cut -f1))"
