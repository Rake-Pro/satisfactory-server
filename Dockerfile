FROM cm2network/steamcmd:root

RUN apt-get update && apt-get install -y --no-install-recommends \
    procps \
    gosu \
    curl \
    ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ficsit-cli: headless Satisfactory mod manager (installs/updates mods from
# ficsit.app, pulls SML automatically). Used by init.sh when MODS is set.
ARG FICSIT_VERSION=0.7.0
ARG FICSIT_SHA256=fac0f82cb9af3503cb358fe927bd762d9d471f9dece797e0fa4b43030153f3c8
RUN curl -fsSL -o /usr/local/bin/ficsit \
      "https://github.com/satisfactorymodding/ficsit-cli/releases/download/v${FICSIT_VERSION}/ficsit_linux_amd64" \
 && echo "${FICSIT_SHA256}  /usr/local/bin/ficsit" | sha256sum -c - \
 && chmod +x /usr/local/bin/ficsit

LABEL maintainer="greg@rake.pro" \
      name="rake-pro/satisfactory-server" \
      github="" \
      dockerhub=""

ENV HOME=/home/steam \
    INSTALL_DIR=/satisfactory \
    SAVED_DIR=/satisfactory/saved \
    STEAMAPPID=1690800 \
    SKIPUPDATE=false \
    STEAMBETA=false \
    STEAMBETAID="" \
    MAXPLAYERS=4 \
    SERVER_PORT=7777 \
    RELIABLE_PORT=8888 \
    MODS="" \
    PUID=1000 \
    PGID=1000

COPY ./scripts /home/steam/server/

RUN find /home/steam/server -type f \( -name "*.sh" -o -name "*.scmd" \) -exec sed -i 's/\r$//' {} \; \
 && chmod +x /home/steam/server/*.sh \
 && mkdir -p /satisfactory /satisfactory/saved

WORKDIR /home/steam/server

# Process name confirmed on first boot; FactoryServer covers the launch script
# and the FactoryServer-Linux-Shipping binary.
HEALTHCHECK --start-period=5m \
            CMD pgrep -f FactoryServer > /dev/null || exit 1

ENTRYPOINT ["/home/steam/server/init.sh"]
