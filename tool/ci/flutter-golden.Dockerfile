# Pinned renderer for the golden screenshot pins.
#
# Mirrors the CI toolchain exactly: Ubuntu 24.04 (ubuntu-latest) + Flutter
# 3.44.4 (the version pinned in .github/workflows/ci.yml). Generate or
# refresh the baselines inside this image so the committed PNGs match the
# Linux CI rasterizer:
#
#   docker build -f tool/ci/flutter-golden.Dockerfile -t legalhub-flutter:3.44.4 .
#   docker run --rm -v "$PWD:/app" -w /app legalhub-flutter:3.44.4 \
#     bash -lc "flutter pub get && RUN_GOLDENS=1 \
#       flutter test test/golden --update-goldens"
#
# CI re-runs the same tests with `subosito/flutter-action@v2` pinned to
# 3.44.4 on ubuntu-latest, so the renderer and engine match.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        fontconfig \
        git \
        libglu1-mesa \
        unzip \
        xz-utils \
        zip \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fL \
        https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.44.4-stable.tar.xz \
        -o /tmp/flutter.tar.xz \
    && tar xf /tmp/flutter.tar.xz -C /opt \
    && rm /tmp/flutter.tar.xz \
    && git config --global --add safe.directory /opt/flutter

ENV PATH="/opt/flutter/bin:${PATH}"

RUN flutter --version && flutter precache --linux

WORKDIR /app
