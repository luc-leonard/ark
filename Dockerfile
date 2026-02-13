# --- Stage 1: Build ---
FROM elixir:1.18-otp-27-slim AS build

RUN apt-get update -y && apt-get install -y build-essential git && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV=prod

# Install dependencies
COPY server/mix.exs server/mix.lock ./
RUN mix deps.get --only prod
RUN mix deps.compile

# Compile application
COPY server/config config
COPY server/lib lib
COPY server/priv priv
RUN mix compile

# Build release
RUN mix release

# --- Stage 2: Runtime ---
FROM debian:bookworm-slim AS runtime

RUN apt-get update -y && \
    apt-get install -y libstdc++6 openssl libncurses6 locales ca-certificates && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR /app

RUN useradd --create-home ark
USER ark

COPY --from=build --chown=ark:ark /app/_build/prod/rel/ark ./

ENV PHX_SERVER=true

EXPOSE 4000

CMD ["bin/ark", "start"]
