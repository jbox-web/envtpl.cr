# The image crystalreleaser builds the static linux binaries in
# (.crystalreleaser.yml, docker.dockerfile and docker.target): the stable
# Alpine, its own Crystal at the minor version mise pins, and the static
# libraries envtpl links. The project is mounted when the build runs, so the
# image holds the toolchain only.

FROM alpine:3.24 AS crystal

RUN apk add --update --no-cache \
  crystal=~1.20 \
  shards \
  gc-dev \
  gc-static \
  git \
  libxml2-dev \
  libxml2-static \
  openssl-dev \
  openssl-libs-static \
  gmp-dev \
  gmp-static \
  pcre2-dev \
  pcre2-static \
  xz-dev \
  xz-static \
  yaml-dev \
  yaml-static \
  zlib-dev \
  zlib-static
