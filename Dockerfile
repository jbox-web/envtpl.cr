###########
# CRYSTAL #
###########

FROM alpine:3.23 AS crystal

RUN apk add --update --no-cache \
  make \
  crystal=~1.18 \
  shards \
  gc-dev \
  gc-static \
  libxml2-dev \
  libxml2-static \
  openssl-dev \
  openssl-libs-static \
  pcre2-dev \
  pcre2-static \
  xz-dev \
  xz-static \
  yaml-dev \
  yaml-static \
  zlib-dev \
  zlib-static \
  upx

#########
# BUILD #
#########

FROM crystal AS build-binary-file

# Fetch platforms variables from ARGS
ARG TARGETPLATFORM
ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT

# Export them to build binary files with the right name: envtpl-linux-amd64
ENV \
  TARGETPLATFORM=${TARGETPLATFORM} \
  TARGETOS=${TARGETOS} \
  TARGETARCH=${TARGETARCH} \
  TARGETVARIANT=${TARGETVARIANT}

# Set build environment
WORKDIR /build
COPY shard.yml shard.lock /build/
COPY Makefile.release /build/Makefile
COPY src/ /build/src/
RUN mkdir /build/bin

# Build the binary
RUN make release

# Extract binary from Docker image
FROM scratch AS binary-file
ARG TARGETOS
ARG TARGETARCH
COPY --from=build-binary-file /build/bin/envtpl-${TARGETOS}-${TARGETARCH} /

###########
# RUNTIME #
###########

# Build distroless images \o/
FROM gcr.io/distroless/static-debian12 AS docker-image

# Fetch platforms variables from ARGS
ARG TARGETOS
ARG TARGETARCH

# Grab envtpl binary from **binary-file** step and inject it in the final image
COPY --from=build-binary-file /build/bin/envtpl-${TARGETOS}-${TARGETARCH} /usr/bin/envtpl

# Set runtime environment
USER nonroot
ENV USER=nonroot
ENV HOME=/home/nonroot
WORKDIR /home/nonroot
ENTRYPOINT ["envtpl"]
