ARG postgresql_major=15
ARG postgresql_minor=6
ARG pgjwt_release=9742dab1b2f297ad3811120db7b21451bca2d3c9
ARG pg_graphql_release=1.5.1
ARG libsodium_release=1.0.18
ARG pgsodium_release=3.1.6
ARG pg_plan_filter_release=5081a7b5cb890876e67d8e7486b6a64c38c9a492
ARG pg_net_release=0.7.1
ARG pg_jsonschema_release=0.1.4
ARG vault_release=0.2.8
ARG groonga_release=12.0.8
ARG pgroonga_release=2.4.0
ARG supautils_release=2.1.0
ARG pg_hashids_release=cd0e1b31d52b394a0df64079406a14a4f7387cd6
ARG pg_tle_release=1.3.2
ARG plv8_release=3.1.5
ARG pg_stat_monitor_release=1.1.1
ARG pg_repack_release=1.4.8
ARG wrappers_release=0.2.0
ARG hypopg_release=1.3.1

# First step is to build the the extension
FROM debian:bullseye-slim as builder
ARG postgresql_major
ARG postgresql_minor
RUN set -xe ;\
    apt update && apt install wget lsb-release gnupg2 -y ;\
    sh -c 'echo "deb https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' ;\
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - ;\
    apt-get update ;\
    apt-get install -y postgresql-server-dev-${postgresql_major} build-essential libcurl4-openssl-dev checkinstall cmake ca-certificates;\
    rm -rf /var/lib/apt/lists/* /tmp/*;

# 1. Build pgjwt extension
# ========================
FROM builder as pgjwt-source

# Download and extract
ARG pgjwt_release
ADD "https://github.com/michelp/pgjwt.git#${pgjwt_release}" \
    /tmp/pgjwt-${pgjwt_release}

# Build from source
WORKDIR /tmp/pgjwt-${pgjwt_release}
RUN make -j$(nproc)

# Create debian package
RUN checkinstall -D --install=no --fstrans=no --backup=no --pakdir=/tmp --pkgversion=1 --nodoc

# 2. Build pgsql-http extension
# ==================================
FROM builder as pgsql-http-source
ADD "https://github.com/pramsey/pgsql-http.git" /tmp/pgsql-http
WORKDIR /tmp/pgsql-http
RUN make && checkinstall -D --install=no --fstrans=no --backup=no --pakdir=/tmp --pkgversion=1 --nodoc

# 3. Build pg_plan_filter extension
# ==================================
FROM builder as pg_plan_filter-source
# Download and extract
ARG pg_plan_filter_release
ADD "https://github.com/pgexperts/pg_plan_filter.git#${pg_plan_filter_release}" \
    /tmp/pg_plan_filter-${pg_plan_filter_release}
# Build from source
WORKDIR /tmp/pg_plan_filter-${pg_plan_filter_release}
RUN make -j$(nproc)
# Create debian package
RUN checkinstall -D --install=no --fstrans=no --backup=no --pakdir=/tmp --pkgversion=1 --nodoc

# 4. Build pg_net extension
# ==================================
FROM builder as pg_net-source
# Download and extract
ARG pg_net_release
ARG pg_net_release_checksum
ADD --checksum=${pg_net_release_checksum} \
    "https://github.com/supabase/pg_net/archive/refs/tags/v${pg_net_release}.tar.gz" \
    /tmp/pg_net.tar.gz
RUN tar -xvf /tmp/pg_net.tar.gz -C /tmp && \
    rm -rf /tmp/pg_net.tar.gz
# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-gnutls-dev \
    && rm -rf /var/lib/apt/lists/*
# Build from source
WORKDIR /tmp/pg_net-${pg_net_release}
RUN make -j$(nproc)
# Create debian package
RUN checkinstall -D --install=no --fstrans=no --backup=no --pakdir=/tmp --requires=libcurl3-gnutls --nodoc

# 5. Build pg_jsonschema extension
# ==================================
FROM builder as pg_jsonschema-source
# Download package archive
ARG postgresql_major
ARG pg_jsonschema_release
ADD "https://github.com/supabase/pg_jsonschema/releases/download/v${pg_jsonschema_release}/pg_jsonschema-v${pg_jsonschema_release}-pg${postgresql_major}-amd64-linux-gnu.deb" \
    /tmp/pg_jsonschema.deb

# 6. Build vault extension
# ==================================
FROM builder as vault-source
# Download and extract
ARG vault_release
ARG vault_release_checksum
ADD --checksum=${vault_release_checksum} \
    "https://github.com/supabase/vault/archive/refs/tags/v${vault_release}.tar.gz" \
    /tmp/vault.tar.gz
RUN tar -xvf /tmp/vault.tar.gz -C /tmp && \
    rm -rf /tmp/vault.tar.gz
# Build from source
WORKDIR /tmp/vault-${vault_release}
RUN make -j$(nproc)
# Create debian package
RUN checkinstall -D --install=no --fstrans=no --backup=no --pakdir=/tmp --nodoc

# 7. Build libsodium
# ==================================
FROM builder as libsodium
# Download and extract
ARG libsodium_release
ARG libsodium_release_checksum
ADD --checksum=${libsodium_release_checksum} \
    "https://download.libsodium.org/libsodium/releases/libsodium-${libsodium_release}.tar.gz" \
    /tmp/libsodium.tar.gz
RUN tar -xvf /tmp/libsodium.tar.gz -C /tmp && \
    rm -rf /tmp/libsodium.tar.gz
# Build from source
WORKDIR /tmp/libsodium-${libsodium_release}
RUN ./configure
RUN  make -j$(nproc)
RUN make install

# 8. Build pgsodium extension
# ==================================
FROM libsodium as pgsodium-source
ARG pgsodium_release
ADD "https://github.com/michelp/pgsodium/archive/refs/tags/v${pgsodium_release}.tar.gz" /tmp/pgsodium.tar.gz
RUN tar -xvf /tmp/pgsodium.tar.gz -C /tmp && \
    rm -rf /tmp/pgsodium.tar.gz
WORKDIR /tmp/pgsodium-${pgsodium_release}
# Create debian package
RUN checkinstall -D --install=no --fstrans=no --backup=no --pakdir=/tmp --requires=libsodium23 --nodoc

# 9. Build pg_graphql extension
# ==================================
FROM builder as pg_graphql-source
ARG postgresql_major
# Download package archive
ARG pg_graphql_release
ADD "https://github.com/supabase/pg_graphql/releases/download/v${pg_graphql_release}/pg_graphql-v${pg_graphql_release}-pg${postgresql_major}-amd64-linux-gnu.deb" \
    /tmp/pg_graphql.deb

# 10. Build pgroonga extension
# ==================================
FROM builder as groonga
# Download and extract
ARG groonga_release
ARG groonga_release_checksum
ADD --checksum=${groonga_release_checksum} \
    "https://packages.groonga.org/source/groonga/groonga-${groonga_release}.tar.gz" \
    /tmp/groonga.tar.gz
RUN tar -xvf /tmp/groonga.tar.gz -C /tmp && \
    rm -rf /tmp/groonga.tar.gz
# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    zlib1g-dev \
    liblz4-dev \
    libzstd-dev \
    libmsgpack-dev \
    libzmq3-dev \
    libevent-dev \
    libmecab-dev \
    rapidjson-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*
# Build from source
WORKDIR /tmp/groonga-${groonga_release}
RUN ./configure
RUN make -j$(nproc)
# Create debian package
RUN checkinstall -D --install=yes --fstrans=no --backup=no --pakdir=/tmp --requires=zlib1g,liblz4-1,libzstd1,libmsgpackc2,libzmq5,libevent-2.1-7,libmecab2 --nodoc

FROM groonga as pgroonga-source
# Download and extract
ARG pgroonga_release
ARG pgroonga_release_checksum
ADD --checksum=${pgroonga_release_checksum} \
    "https://packages.groonga.org/source/pgroonga/pgroonga-${pgroonga_release}.tar.gz" \
    /tmp/pgroonga.tar.gz
RUN tar -xvf /tmp/pgroonga.tar.gz -C /tmp && \
    rm -rf /tmp/pgroonga.tar.gz
# Build from source
WORKDIR /tmp/pgroonga-${pgroonga_release}
RUN make -j$(nproc)
# Create debian package
RUN checkinstall -D --install=no --fstrans=no --backup=no --pakdir=/tmp --requires=mecab-naist-jdic --nodoc

# 11. Build supautils extension
# ==================================
FROM builder as supautils
# Download package archive
ARG postgresql_major
ARG supautils_release
ADD "https://github.com/supabase/supautils/releases/download/v${supautils_release}/supautils-v${supautils_release}-pg${postgresql_major}-amd64-linux-gnu.deb" \
    /tmp/supautils.deb

# 12. Build pg_hashids extension
# ==================================
FROM builder as pg_hashids-source
# Download and extract
ARG pg_hashids_release
ADD "https://github.com/iCyberon/pg_hashids.git#${pg_hashids_release}" \
    /tmp/pg_hashids-${pg_hashids_release}
# Build from source
WORKDIR /tmp/pg_hashids-${pg_hashids_release}
RUN make -j$(nproc)
# Create debian package
RUN checkinstall -D --install=no --fstrans=no --backup=no --pakdir=/tmp --pkgversion=1 --nodoc

# 12. Build pg_tle extension
# ==================================
FROM builder as pg_tle-source
ARG pg_tle_release
ARG pg_tle_release_checksum
ADD --checksum=${pg_tle_release_checksum} \
    "https://github.com/aws/pg_tle/archive/refs/tags/v${pg_tle_release}.tar.gz" \
    /tmp/pg_tle.tar.gz
RUN tar -xvf /tmp/pg_tle.tar.gz -C /tmp && \
    rm -rf /tmp/pg_tle.tar.gz
RUN apt-get update && apt-get install -y --no-install-recommends \
    flex \
    libkrb5-dev \
    && rm -rf /var/lib/apt/lists/*
# Build from source
WORKDIR /tmp/pg_tle-${pg_tle_release}
RUN make -j$(nproc)
# Create debian package
RUN checkinstall -D --install=no --fstrans=no --backup=no --pakdir=/tmp --nodoc

# 13. Build plv8 extension
# ==================================
FROM builder as plv8-source
# Download and extract
ARG plv8_release
ARG plv8_release_checksum
ADD --checksum=${plv8_release_checksum} \
    "https://github.com/supabase/plv8/archive/refs/tags/v${plv8_release}.tar.gz" \
    /tmp/plv8.tar.gz
RUN tar -xvf /tmp/plv8.tar.gz -C /tmp && \
    rm -rf /tmp/plv8.tar.gz
# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    pkg-config \
    ninja-build \
    git \
    libtinfo5 \
    clang \ 
    binutils \
    && rm -rf /var/lib/apt/lists/*
# Build from source
WORKDIR /tmp/plv8-${plv8_release}
ENV DOCKER=1
RUN make
# Create debian package
RUN checkinstall -D --install=no --fstrans=no --backup=no --pakdir=/tmp --nodoc

# 14. Build pg_stat_monitor extension
# ==================================
FROM builder as pg_stat_monitor-source
# Download and extract
ARG pg_stat_monitor_release
ARG pg_stat_monitor_release_checksum
ADD --checksum=${pg_stat_monitor_release_checksum} \
    "https://github.com/percona/pg_stat_monitor/archive/refs/tags/${pg_stat_monitor_release}.tar.gz" \
    /tmp/pg_stat_monitor.tar.gz
RUN tar -xvf /tmp/pg_stat_monitor.tar.gz -C /tmp && \
    rm -rf /tmp/pg_stat_monitor.tar.gz
# Build from source
WORKDIR /tmp/pg_stat_monitor-${pg_stat_monitor_release}
ENV USE_PGXS=1
RUN make -j$(nproc)
# Create debian package
RUN checkinstall -D --install=no --fstrans=no --backup=no --pakdir=/tmp --nodoc

# 15. Build pg_repack extension
# ==================================
 FROM builder as pg_repack-source
 ARG pg_repack_release
 ARG pg_repack_release_checksum
 ADD --checksum=${pg_repack_release_checksum} \
     "https://github.com/reorg/pg_repack/archive/refs/tags/ver_${pg_repack_release}.tar.gz" \
     /tmp/pg_repack.tar.gz
 RUN tar -xvf /tmp/pg_repack.tar.gz -C /tmp && \
     rm -rf /tmp/pg_repack.tar.gz
 # Install build dependencies
 RUN apt-get update && apt-get install -y --no-install-recommends \
     liblz4-dev \
     libz-dev \
     libzstd-dev \
     libreadline-dev \
     && rm -rf /var/lib/apt/lists/*
 # Build from source
 WORKDIR /tmp/pg_repack-ver_${pg_repack_release}
 ENV USE_PGXS=1
 RUN make -j$(nproc)
 # Create debian package
 RUN checkinstall -D --install=no --fstrans=no --backup=no --pakdir=/tmp --pkgversion=${pg_repack_release} --nodoc

# 16. Build wrappers extension
# ==================================
FROM builder as wrappers
# Download package archive
ARG postgresql_major
ARG wrappers_release
ADD "https://github.com/supabase/wrappers/releases/download/v${wrappers_release}/wrappers-v${wrappers_release}-pg${postgresql_major}-amd64-linux-gnu.deb" \
    /tmp/wrappers.deb

# 17. Build hypopg extension
# ==================================
FROM builder as hypopg-source
# Download and extract
ARG hypopg_release
ARG hypopg_release_checksum
ADD --checksum=${hypopg_release_checksum} \
    "https://github.com/HypoPG/hypopg/archive/refs/tags/${hypopg_release}.tar.gz" \
    /tmp/hypopg.tar.gz
RUN tar -xvf /tmp/hypopg.tar.gz -C /tmp && \
    rm -rf /tmp/hypopg.tar.gz
# Build from source
WORKDIR /tmp/hypopg-${hypopg_release}
RUN make -j$(nproc)
# Create debian package
RUN checkinstall -D --install=no --fstrans=no --backup=no --pakdir=/tmp --nodoc

ARG hypopg_release=1.3.1
# Consolidate built packages
# ===========================
FROM scratch as extensions
COPY --from=pgjwt-source /tmp/*.deb /tmp/
COPY --from=pgsql-http-source /tmp/*.deb /tmp/
COPY --from=pg_plan_filter-source /tmp/*.deb /tmp/
COPY --from=pg_net-source /tmp/*.deb /tmp/
COPY --from=pg_jsonschema-source /tmp/*.deb /tmp/
COPY --from=vault-source /tmp/*.deb /tmp/
COPY --from=pgsodium-source /tmp/*.deb /tmp/
COPY --from=pg_graphql-source /tmp/*.deb /tmp/
COPY --from=pgroonga-source /tmp/*.deb /tmp/
COPY --from=supautils /tmp/*.deb /tmp/
COPY --from=pg_hashids-source /tmp/*.deb /tmp/
COPY --from=pg_tle-source /tmp/*.deb /tmp/
COPY --from=plv8-source /tmp/*.deb /tmp/
COPY --from=pg_stat_monitor-source /tmp/*.deb /tmp/
COPY --from=pg_repack-source /tmp/*.deb /tmp/
COPY --from=wrappers /tmp/*.deb /tmp/
COPY --from=hypopg-source /tmp/*.deb /tmp/
# Build actual container
# ======================
FROM ghcr.io/cloudnative-pg/postgresql:${postgresql_major}.${postgresql_minor}
ARG postgresql_major
ARG postgresql_minor
USER root

# Copy built packages from extensions layer
COPY --from=extensions /tmp /tmp

# Install built + cron wal2json pgtap extension packages
RUN set -xe; \
    apt-get update; \
    apt-get install -y --no-install-recommends postgresql-${postgresql_major}-cron postgresql-${postgresql_major}-wal2json postgresql-${postgresql_major}-jsquery postgresql-${postgresql_major}-postgis-3 postgresql-${postgresql_major}-pgrouting postgresql-12-pgq3 postgresql-${postgresql_major}-pgtap postgresql-${postgresql_major}-pg-checksums postgresql-${postgresql_major}-pgl-ddl-deploy /tmp/*.deb; \
    rm -fr /tmp/* && rm -rf /var/lib/apt/lists/*;
    
USER 26