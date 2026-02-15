# Migration Patterns

Technology-agnostic guide for detecting and running database migrations in worktree environments.

## Detection Priority

When determining how to run migrations, follow this order:

1. **Project instructions (highest priority)**
   - CLAUDE.md sections about database/migrations/setup
   - README.md "Getting Started" or "Setup" section
   - docs/ directory setup guides
   - If found: use the exact commands specified

2. **Package.json scripts**
   ```bash
   grep -E '"(migrate|db:|seed)' package.json 2>/dev/null
   ```
   Common patterns: `db:migrate`, `db:seed`, `migrate:run`, `prisma:migrate`

3. **Auto-detection from project files**
   See detection table below

4. **Ask user**
   If no clear migration tool detected, ask:
   > I couldn't detect a migration tool. What commands should I run to set up the database?
   > - Migration command: ___
   > - Seed command (optional): ___

## Detection Table

| Tool | Detection files | Migrate command | Seed command |
|------|----------------|-----------------|--------------|
| **Prisma** | `prisma/schema.prisma` | `npx prisma migrate deploy` | `npx prisma db seed` |
| **TypeORM** | `ormconfig.*`, `data-source.*` | `npx typeorm migration:run -d <datasource>` | Custom (check scripts) |
| **Drizzle** | `drizzle.config.*` | `npx drizzle-kit migrate` | Custom |
| **Knex** | `knexfile.*` | `npx knex migrate:latest` | `npx knex seed:run` |
| **Sequelize** | `.sequelizerc`, `config/database.*` | `npx sequelize-cli db:migrate` | `npx sequelize-cli db:seed:all` |
| **MikroORM** | `mikro-orm.config.*` | `npx mikro-orm migration:up` | Custom |
| **Django** | `manage.py` | `python manage.py migrate` | `python manage.py loaddata <fixture>` |
| **Rails** | `Gemfile` + `db/migrate/` | `rails db:migrate` | `rails db:seed` |
| **Alembic** | `alembic.ini`, `alembic/` | `alembic upgrade head` | Custom |
| **Flyway** | `flyway.conf`, `sql/` | `flyway migrate` | N/A |
| **Liquibase** | `changelog.*` | `liquibase update` | N/A |
| **goose** | `db/migrations/` + Go project | `goose up` | Custom |
| **Raw SQL** | `migrations/*.sql` without ORM | Detect runner from docs | N/A |

## Execution Context

### Inside Docker (most common)

When the application runs inside Docker, execute migrations in the container:

```bash
# Generic pattern
docker compose -p <project> exec <service> <migrate-command>

# Examples
docker compose -p <project>-wt1 exec api npx prisma migrate deploy
docker compose -p <project>-wt1 exec api npx prisma db seed
docker compose -p <project>-wt1 exec web python manage.py migrate
```

**Wait for the database to be ready** before running migrations:
```bash
# The compose healthcheck should handle this, but verify
docker compose -p <project> exec db pg_isready -U postgres 2>/dev/null
```

### On Host (less common)

When the database runs in Docker but the app runs on the host:

```bash
cd .worktrees/<slug>
# Ensure DATABASE_URL points to the worktree's DB port
npx prisma migrate deploy
```

The `.env` in the worktree already has the correct port. Migration tools that read `.env` will pick it up automatically.

## Database Creation

Some setups auto-create the database (e.g., Postgres `POSTGRES_DB` env var creates it on first run). Others need manual creation.

### Auto-Created (typical Docker Postgres)

```yaml
# docker-compose.yml
services:
  db:
    environment:
      POSTGRES_DB: ${DATABASE_NAME}  # Created automatically
```

The worktree `.env` sets `DATABASE_NAME=myapp_wt1`, so Postgres creates it on startup.

### Manual Creation

If the database must be created manually:

```bash
docker compose -p <project> exec db createdb -U postgres <dbname>
```

## Post-Migration Verification

After running migrations, verify:

```bash
# Check migration status (tool-specific)
docker compose -p <project> exec api npx prisma migrate status
docker compose -p <project> exec api npx knex migrate:status
docker compose -p <project> exec web python manage.py showmigrations
```

## Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| Connection refused | DB not ready yet | Wait for healthcheck, retry |
| Database does not exist | `DATABASE_NAME` not set or Postgres didn't auto-create | Create DB manually or check env |
| Permission denied | Wrong user or missing grants | Check `DATABASE_USER` in worktree `.env` |
| Migration already applied | Shared DB between worktrees | Ensure each worktree has its own DB name |
| Seed fails with duplicates | Seed run twice | Most seeds are idempotent; if not, check if DB was reused |

## Saving Learnings

If the migration setup for a project required non-obvious steps:

1. **Suggest CLAUDE.md update** with a "Worktree Setup" section:
   ```markdown
   ## Worktree Setup
   After creating a Docker worktree, run:
   1. `docker compose -p <name> exec api npx prisma migrate deploy`
   2. `docker compose -p <name> exec api npx prisma db seed`
   ```

2. **Or note in the skill's self-improvement** for pattern recognition in future projects.
