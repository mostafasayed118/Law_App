# Pinned renderer for the golden screenshot pins.
#
# Mirrors the CI toolchain exactly: Ubuntu 24.04 (ubuntu-latest) + Flutter
# 3.47.5 (the version pinned in .github/workflows/ci.yml). Generate or
# refresh the baselines inside this image so the committed PNGs match the
# Linux CI rasterizer:
#
#   docker build -f tool/ci/flutter-golden.Dockerfile -t legalhub-flutter:3.47.5 .
#   docker run --rm -v "$PWD:/app" -w /app legalhub-flutter:3.47.5 \
#     bash -lc "flutter pub get && RUN_GOLDENS=1 \
#       flutter test test/golden --update-goldens"
#
# CI re-runs the same tests with `subosito/flutter-action@v2` pinned to
# 3.47.5 on ubuntu-latest, so the renderer and engine match.
#
# TOOLCHAIN BUMP 2026-11-16: the pin moved 3.44.4 -> 3.47.5 to match the
# committed lockfile, which already required flutter >=3.47.0. The four
# committed PNGs were generated in the 3.44.4 image, so regenerate them with
# the two commands above the next time Docker is available before trusting the
# golden-pins job. Text rasterisation can differ between engine versions, and
# a stale baseline fails closed (a red job), never silently.
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
        https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.5-stable.tar.xz \
        -o /tmp/flutter.tar.xz \
    && tar xf /tmp/flutter.tar.xz -C /opt \
    && rm /tmp/flutter.tar.xz \
    && git config --global --add safe.directory /opt/flutter

ENV PATH="/opt/flutter/bin:${PATH}"

RUN flutter --version && flutter precache --linux

WORKDIR /app
