# Based on https://github.com/stampes/CISimple
FROM docker.io/dyalog/dyalog

USER root
RUN apt-get update && apt-get install -y --no-install-recommends binutils \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /cold
COPY --chown=dyalog:dyalog ws/ ws/
COPY --chown=dyalog:dyalog lnk/ lnk/
COPY --chown=dyalog:dyalog tests/ tests/
COPY --chown=dyalog:dyalog ci/tests.aplf ci/tests.aplf

ENV LOAD=/cold/ci/tests.aplf
USER dyalog
