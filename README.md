# SciBack — DSpace 7.6.6 + ALICIA/RENATI

Instalación modular de DSpace 7.6.6 para repositorios institucionales peruanos,
con gestión de temas personalizados.

## Estructura

```
├── deploy.sh                       # Orquestador: ejecuta las 14 etapas de instalación
├── limpiar.sh                      # Limpieza total para reinstalación
├── theme-manager.sh                # Orquestador: personalización visual (13 etapas)
├── .env.deploy              # Config de deploy (NO en Git)
├── .env.theme-manager       # Config de temas (NO en Git)
├── .env.deploy.example                    # Plantilla deploy — copiar y editar
├── .env.theme-manager.example  # Plantilla temas — copiar y editar
├── etapas/                         # Etapas de instalación DSpace
│   ├── 01-sistema.sh               # Timezone, paquetes, swap, usuario
│   ├── 02-java.sh                  # OpenJDK 17
│   ├── 03-postgresql.sh            # PostgreSQL 14 + DB
│   ├── 04-solr.sh                  # Apache Solr 8.11.4
│   ├── 05-tomcat.sh                # Apache Tomcat 9
│   ├── 06-dspace-backend.sh        # Clone, compile, install, migrate, admin
│   ├── 07-frontend.sh              # Angular + Node.js + PM2
│   ├── 08-nginx.sh                 # Reverse proxy + SSL + robots.txt
│   ├── 09-handle.sh                # Handle Server (solo descarga)
│   ├── 10-cron.sh                  # OAI-PMH, Solr, filter-media, stats
│   ├── 11-schemas-alicia.sh        # Schemas renati + thesis (REST API)
│   ├── 12-vocabularios.sh          # Vocabularios CONCYTEC
│   ├── 13-formularios.sh           # Formularios de depósito ALICIA
│   └── 14-lab-structure.sh         # Estructura comunidades SciBack Lab
└── theme-manager/                  # Recursos del theme manager
    ├── lib/                        # Librerías compartidas (common, fs, ui)
    └── stages/                     # 13 etapas de personalización
```

## Instalación completa

```bash
# 1. Copiar plantilla y editar con datos reales
cp .env.deploy.example .env.deploy
nano .env.deploy

# 2. Ejecutar deploy (14 etapas, ~46 min)
sudo bash deploy.sh
```

El script muestra progreso en tiempo real: barra visual, tiempo transcurrido,
tiempo restante estimado, y duración de cada etapa al completarse.

## Limpieza (reinstalación desde cero)

```bash
sudo bash limpiar.sh     # Borra TODO: PostgreSQL, Solr, Tomcat, DSpace, etc.
sudo bash deploy.sh      # Reinstalar
```

## Ejecutar etapas individuales

```bash
sudo bash etapas/06-dspace-backend.sh   # solo backend
sudo bash etapas/12-vocabularios.sh     # solo vocabularios
sudo bash etapas/13-formularios.sh      # solo formularios
```

## Theme Manager

Personalización visual del frontend DSpace (colores, logo, banner, menús).

```bash
# Editar configuración de tema
nano .env.theme-manager

# Ejecutar todas las etapas
bash theme-manager.sh

# Ejecutar una etapa individual
bash theme-manager.sh --stage 05-apply-colors

# Listar etapas disponibles
bash theme-manager.sh --list-stages
```

## Archivos .env

| Archivo | Propósito | ¿En Git? |
|---|---|---|
| `.env.deploy.example` | Plantilla de deploy | ✅ Sí |
| `.env.theme-manager.example` | Plantilla de temas | ✅ Sí |
| `.env.deploy` | Config activa con credenciales | ❌ No |
| `.env.theme-manager` | Config activa de temas | ❌ No |

## Notas DSpace 7.6.6

- Tomcat 10 es INCOMPATIBLE — solo Tomcat 9
- `<dc-qualifier>` vacío rompe Tomcat — omitir si no hay qualifier
- `<vocabulary>` usa `onebox`, no `dropdown`
- `value-pairs-name` va como atributo de `<input-type>`, no como etiqueta separada
- `ui.host` en config.yml debe ser `0.0.0.0` en AWS EC2

## Compatibilidad

Ubuntu 22.04 LTS | Java 17 | PostgreSQL 14 | Solr 8.11.4 | Tomcat 9 | Node.js 18
