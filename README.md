# Ark

Version control system optimized for large binary files with exclusive locking, targeting creative studios (video, 3D, VFX).

## Architecture

- **server/** — Elixir/Phoenix API server with PostgreSQL
- **cli/** — Rust CLI client

## Prerequisites

- Elixir 1.18+, Erlang/OTP 27+
- Rust 1.93+
- PostgreSQL 16+
- Docker & Docker Compose (optional)

## Quick start

### Server

```bash
cd server
mix deps.get
mix ecto.setup
mix phx.server
```

### CLI

```bash
cd cli
cargo build --release
./target/release/ark-cli --help
```

### Docker

```bash
docker-compose up
```

## License

MIT
