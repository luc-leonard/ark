# Ark — Roadmap

## Phase 1 — Fondations

> Pas de valeur utilisateur directe, mais tout en dépend.

- [ ] **Modèle de données Ecto**
  - Schemas : `User`, `Repository`, `Revision`, `FileEntry`, `Lock`
  - Migrations
  - Colonne vertébrale du projet, tout le reste s'appuie dessus

- [ ] **Storage — blob store content-addressable**
  - Écrire un fichier sur disque, clé = SHA-256 du contenu
  - Lire un blob par son hash
  - Dedup native (deux fichiers identiques = un seul blob)

- [ ] **Auth basique**
  - API keys par utilisateur
  - Juste assez pour savoir *qui* fait *quoi*
  - Les locks et les revisions en ont besoin

## Phase 2 — Workflow core (MVP)

> À la fin de cette phase, Ark est un VCS fonctionnel minimal.

- [ ] **Push (CLI → serveur)**
  - Le CLI calcule le hash, envoie le blob, le serveur l'enregistre
  - Crée une `Revision` en base

- [ ] **Sync (serveur → CLI)**
  - Télécharger les blobs manquants, reconstruire le workspace

- [ ] **Status**
  - Comparer l'état local vs la dernière revision connue
  - Fichiers modifiés, ajoutés, supprimés

## Phase 3 — Le différenciateur

> Ce qui justifie d'exister face à Git LFS.

- [ ] **Locking persisté**
  - Migrer le GenServer en mémoire → Ecto (DB)
  - Vérification au push : refuser si le fichier est locké par quelqu'un d'autre
  - `ark lock` / `ark unlock` fonctionnels bout en bout

- [ ] **Log + Checkout**
  - Historique des revisions
  - Checkout d'une revision antérieure

## Phase 4 — L'expérience

> Rendre le produit vendable.

- [ ] **Web UI (LiveView)**
  - Dashboard : fichiers, locks actifs, activité récente
  - Temps réel via PubSub (locks, uploads)

- [ ] **Init + workspace config**
  - `ark init` crée un `.ark/` local avec la config serveur
  - Gestion multi-repo

## Phase 5 — Production-readiness

> Gérer la réalité des studios (fichiers massifs, réseaux instables).

- [ ] **Chunked upload / résumable**
  - Pour les fichiers de plusieurs Go (assets Unreal, scènes Maya)

- [ ] **Delta sync**
  - Ne transférer que les différences quand c'est possible
