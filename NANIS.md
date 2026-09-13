# Nanis Design — fork de Open Design para el Nanis Studio

> Rama `nanis` sobre `open-design` 0.12.1 (`c3712b7`). Dueño: Carlos Sánchez. Es el motor de la pestaña
> **Diseño** del Nanis Studio (`~/.dania-platform`, `backend/diseno.js`). Upstream: `nexu-io/open-design`.

## Qué cambia respecto a upstream (commits de la rama `nanis`)
- Marca **Nanis Design** en web, daemon y los 19 idiomas; español (`es-ES`) por defecto.
- Sin el agente de la nube de Open Design (`amr`/Vela): solo CLIs locales (Claude Code primero).
- Telemetría apagada por defecto; sin chips de comunidad (estrella GitHub, Teams, Discord); tagline y
  consejos Nanis; ubicación por defecto «Proyectos de Nanis Design».
- El init del tema lee `?theme=dark|light` del Studio y lo persiste antes de hidratar.
- `OD_EXTRA_FRAME_ANCESTORS`: los previews y assets aceptan al Studio como ancestro del iframe.
- Cherry-pick de upstream `0704e991` (#6614): el fallback de la SPA sirve `index.html` desde la raíz
  estática (los enlaces profundos `/projects/<id>` funcionaban solo por navegación cliente).

## Cómo se construye y publica el runtime
```bash
pnpm install
pnpm --filter @open-design/daemon build
OD_WEB_OUTPUT_MODE=export NODE_ENV=production pnpm --filter @open-design/web build
NANIS_RUNTIME_TAG=nanis-v0.12.1-nanis.N bash scripts/nanis/empaquetar-runtime.sh release/
# → release/nanis-design-runtime-0.12.1-nanis.N.tar.gz (+ .sha256)
```
Publicar como Release `nanis-v0.12.1-nanis.N` en `carlosdania/nanis-design` y apuntar
`scripts/diseno/runtime.version` del Studio (URL + SHA256). El Mac (`scripts/diseno/instalar-mac.sh`) y
los sidecars (`Dockerfile.od`) lo recogen de ahí. Node 24 (el daemon funciona con 26; la web compila
con avisos de motor).

## Reglas
- Los parches van en FUENTE y como commits pequeños con mensaje en español; nunca `sed` sobre el bundle.
- No tocar `apps/web/out` ni `apps/daemon/dist` a mano: se regeneran.
- Para subir de versión upstream: nueva rama desde el tag upstream, `git rebase` de los commits `nanis`.
