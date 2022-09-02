VERSION 0.6

all-binaries:
  BUILD \
    --platform=linux/amd64 \
    +build-binary

all-docker-images:
  BUILD \
    --platform=linux/amd64 \
    +build-docker

build-binary:
  FROM DOCKERFILE --target binary-file .
  SAVE ARTIFACT /build/bin/envtpl-* AS LOCAL packages/

build-docker:
  FROM DOCKERFILE --target docker-image .
  SAVE IMAGE envtpl-dev-multi:latest
