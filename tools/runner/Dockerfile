# cm-runner — a replica of GitHub's `ubuntu-latest` runner, just enough to execute these repos' workflows.
#
# WHY: every "green" before 2026-11-08 was a Docker Desktop run, where bind mounts are permissive and image
# layers are cached, so two real failures were invisible (chmod 600 keys; a dead Debian 11 base). This image is
# run with the repo on the Docker VM's OWN ext4 filesystem (not a Windows bind mount) and the docker daemon
# socket mounted, so file permissions are enforced exactly as on a Linux runner.
#
# It is a REHEARSAL tool. The source of truth is GitHub Actions on a real runner.
FROM ubuntu:24.04@sha256:fe81560990fae86dc4743202b2cb4d3df98d0bcf949173cecef15ce1127ef852
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl git jq openssl bash coreutils gawk procps \
      postgresql-client xxd sudo findutils diffutils make \
 && rm -rf /var/lib/apt/lists/*
# docker CLI + compose plugin (the runner talks to the host daemon over the mounted socket)
COPY --from=docker:27-cli@sha256:851f91d241214e7c6db86513b270d58776379aacc5eb9c4a87e5b47115e3065c /usr/local/bin/docker /usr/local/bin/docker
COPY --from=docker:27-cli@sha256:851f91d241214e7c6db86513b270d58776379aacc5eb9c4a87e5b47115e3065c /usr/local/libexec/docker/cli-plugins/docker-compose /usr/local/libexec/docker/cli-plugins/docker-compose
# toolchains the workflows expect on the runner
COPY --from=golang:1.26@sha256:cfa27959837144bf4649802ba38e59daffd0dd2a7994aa83daaf113285b0f551 /usr/local/go /usr/local/go
COPY --from=node:20-bookworm-slim@sha256:2cf067cfed83d5ea958367df9f966191a942351a2df77d6f0193e162b5febfc0 /usr/local/bin/node /usr/local/bin/node
COPY --from=mikefarah/yq:v4.54.2@sha256:5d56494617dce8311106e905aac5c080a2087c905a7f7de2984db2e2cc60ab2e /usr/bin/yq /usr/local/bin/yq
ENV PATH=/usr/local/go/bin:/usr/local/bin:$PATH
# the same unprivileged user GitHub's runner uses (uid 1001) — this is what makes ownership bugs reproduce
RUN useradd -m -u 1001 -s /bin/bash runner && echo 'runner ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/runner
USER runner
WORKDIR /home/runner
