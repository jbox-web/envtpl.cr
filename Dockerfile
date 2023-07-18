#########
# BUILD #
#########

# Build envtpl with Crystal upstream image
# Use alpine variant to build static binary
FROM crystallang/crystal:1.9.1-alpine AS binary-file

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

# Install build dependencies
RUN apk add --update --no-cache yaml-static upx

# Set build environment
WORKDIR /build
COPY shard.yml shard.lock /build/
COPY Makefile.release /build/Makefile
COPY src/ /build/src/
RUN mkdir /build/bin

# Build the binary
RUN make release


###########
# RUNTIME #
###########

# Build distroless images \o/
FROM gcr.io/distroless/static-debian11 AS docker-image

# Fetch platforms variables from ARGS
ARG TARGETOS
ARG TARGETARCH

# Grab envtpl binary from **binary-file** step and inject it in the final image
COPY --from=binary-file /build/bin/envtpl-${TARGETOS}-${TARGETARCH} /usr/bin/envtpl

# Set runtime environment
USER nonroot
ENV USER nonroot
ENV HOME /home/nonroot
WORKDIR /home/nonroot
ENTRYPOINT ["envtpl"]
