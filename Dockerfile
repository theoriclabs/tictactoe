# Build the server with Lean, then run it on a slim image.
#
# Debian bookworm, not a newer release: leancrypto links the system's static libcrypto, and one
# built for glibc 2.38 or later calls `__isoc23_*` functions that Lean's bundled glibc lacks.
FROM debian:bookworm-slim AS build

RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential ca-certificates curl git libssl-dev \
    && rm -rf /var/lib/apt/lists/*

ENV ELAN_HOME=/usr/local/elan
ENV PATH="${ELAN_HOME}/bin:${PATH}"
COPY lean-toolchain /src/lean-toolchain
RUN curl -fsSL https://elan.lean-lang.org/elan-init.sh | sh -s -- -y --default-toolchain none \
    && elan toolchain install "$(cat /src/lean-toolchain)" \
    && elan default "$(cat /src/lean-toolchain)"

WORKDIR /src
COPY . .
RUN lake build tictactoe

FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates libgmp10 libstdc++6 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /src/.lake/build/bin/tictactoe /usr/local/bin/tictactoe

# Listen on every interface, and keep the games on the volume mounted at /data.
ENV LEANAPP_HOST=0.0.0.0
ENV LEANAPP_DATABASE=/data/tictactoe.sqlite
WORKDIR /data
EXPOSE 8080
CMD ["sh", "-c", "LEANAPP_PORT=${PORT:-8080} exec tictactoe"]
