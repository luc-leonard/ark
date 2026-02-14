# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Projet

Ark est un système de contrôle de version optimisé pour les fichiers binaires volumineux avec verrouillage exclusif, destiné aux studios créatifs (vidéo, 3D, VFX). Monorepo avec un serveur Elixir/Phoenix et un CLI Rust.

## Commandes — Server (depuis `server/`)

```bash
# Setup initial
mix setup                     # deps.get + ecto.create + ecto.migrate + seeds

# Développement
mix phx.server                # Lancer le serveur (localhost:4000)
mix ecto.migrate              # Appliquer les migrations
mix ecto.gen.migration nom    # Générer une migration (toujours via cette commande)

# Tests
mix test                      # Tous les tests (crée/migre la DB automatiquement)
mix test test/ark/lock_manager_test.exs           # Un fichier spécifique
mix test test/ark/lock_manager_test.exs:42         # Un test spécifique (ligne)
mix test --failed             # Relancer uniquement les tests échoués
mix coveralls                 # Tests avec couverture de code

# Qualité (CI reproduit ces étapes)
mix precommit                 # Exécuter AVANT chaque commit : compile --warnings-as-errors, format, credo --strict, sobelow, tests
mix compile --warnings-as-errors
mix format --check-formatted
mix credo --strict
mix sobelow --config
mix deps.audit
```

## Commandes — CLI (depuis `cli/`)

```bash
cargo build --release
cargo test
cargo fmt --check
cargo clippy -- -D warnings
```

## Commandes — Docker

```bash
docker-compose up             # Lance PostgreSQL 16 + serveur Phoenix
```

## Architecture serveur

**Stack :** Phoenix 1.8 (API JSON uniquement, pas de HTML/LiveView pour l'instant), Ecto, PostgreSQL 16, Bandit.

**Supervision tree :** `Ark.Application` démarre Telemetry → Repo → DNSCluster → PubSub → `Ark.LockManager` (GenServer) → Endpoint.

**Modèle de données (tous les PK sont des UUID binary_id) :**
- `User` → has_many `ApiKey`, has_many `Repository` (owner)
- `Repository` → has_many `Revision`, has_many `Lock`
- `Revision` → has_many `FileEntry`, belongs_to `User` (author)
- `Lock` → belongs_to `Repository` + `User`, unique sur (repository_id, path)

**Routes API :** tout sous `/api/v1` (scope `ArkWeb`, donc les controllers sont `ArkWeb.XxxController` sans alias supplémentaire). Health check sur `GET /health`.

**LockManager :** GenServer qui sérialise les opérations de lock via `GenServer.call/2` pour éviter les race conditions. Persiste en DB via Ecto. Accepte un `server` en premier argument optionnel pour la testabilité (nommage dynamique).

**Storage :** `Ark.Storage` est un stub prévu pour le blob store content-addressable (SHA-256).

## Conventions

- Utiliser `:req` (Req) pour les requêtes HTTP — jamais httpoison/tesla/httpc
- `mix precommit` obligatoire avant chaque commit
- Ne jamais imbriquer plusieurs modules dans le même fichier
- Ne jamais utiliser la syntaxe map access (`changeset[:field]`) sur des structs — utiliser `struct.field` ou `Ecto.Changeset.get_field/2`
- Les champs assignés programmatiquement (ex: `user_id`) ne doivent pas être dans les `cast` — les setter explicitement à la construction du struct
- Timestamps Ecto en `:utc_datetime`
- En test : utiliser `start_supervised!/1` pour les GenServers, `Process.monitor/1` au lieu de `Process.sleep/1`
- Le `scope` du router Phoenix fournit l'alias — ne pas en créer manuellement pour les routes

## Roadmap

Phase 1 (fondations, en cours) → Phase 2 (push/sync/status MVP) → Phase 3 (locking persisté, log, checkout) → Phase 4 (LiveView UI, init/workspace) → Phase 5 (chunked upload, delta sync). Voir `docs/ROADMAP.md`.
