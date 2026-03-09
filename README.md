# SciBack — DSpace 7.6.6 + ALICIA/RENATI

Instalación modular de DSpace 7.6.6 para repositorios institucionales peruanos.

## Uso

```bash
cp .env.example .env.dspace.deploy
nano .env.dspace.deploy   # editar con datos reales
sudo bash install.sh
```

## Estructura

```
├── install.sh                  # Disparador: ejecuta las 13 etapas
├── .env.dspace.deploy          # Configuración (editar antes de ejecutar)
└── etapas/
    ├── 01-sistema.sh           # Timezone, paquetes, swap, usuario
    ├── 02-java.sh              # OpenJDK 17
    ├── 03-postgresql.sh        # PostgreSQL 14 + DB
    ├── 04-solr.sh              # Apache Solr 8.11.4
    ├── 05-tomcat.sh            # Apache Tomcat 9
    ├── 06-dspace-backend.sh    # Clone, compile, install, migrate, admin
    ├── 07-frontend.sh          # Angular + Node.js + PM2
    ├── 08-nginx.sh             # Reverse proxy + SSL + robots.txt
    ├── 09-handle.sh            # Handle Server (solo descarga)
    ├── 10-cron.sh              # OAI-PMH, Solr, filter-media, stats
    ├── 11-schemas-alicia.sh    # Schemas renati + thesis (REST API)
    ├── 12-vocabularios.sh      # Vocabularios CONCYTEC
    └── 13-formularios.sh       # Formularios de depósito ALICIA
```

## Ejecutar etapas individuales

```bash
sudo bash etapas/12-vocabularios.sh    # solo vocabularios
sudo bash etapas/13-formularios.sh     # solo formularios
```

## Notas DSpace 7.6.6

- Tomcat 10 es INCOMPATIBLE — solo Tomcat 9
- `<dc-qualifier>` vacío rompe Tomcat — omitir si no hay qualifier
- `<vocabulary>` usa `onebox`, no `dropdown`
- `value-pairs-name` va como atributo de `<input-type>`, no como etiqueta separada
- `ui.host` en config.yml debe ser `0.0.0.0` en AWS EC2

## Compatibilidad

Ubuntu 22.04 LTS | Java 17 | PostgreSQL 14 | Solr 8.11.4 | Tomcat 9 | Node.js 20
