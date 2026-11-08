# cm-runner — a replica of GitHub's `ubuntu-latest` runner, just enough to execute these repos' workflows.
#
# WHY: every "green" before 2026-11-08 was a Docker Desktop run, where bind mounts are permissive and image
# layers are cached, so two real failures were invisible (chmod 600 keys; a dead Debian 11 base). This image is
# run with the repo on the Docker VM's OWN ext4 filesystem (not a Windows bind mount) and the docker daemon
# socket mounted, so file permissions are enforced exactly as on a Linux runner.
#
# It is a REHEARSAL tool. The source of truth is GitHub Actions on a real runner.
FROM ubuntu:24.04
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl git jq openssl bash coreutils gawk procps \
      postgresql-client xxd sudo findutils diffutils make \
 && rm -rf /var/lib/apt/lists/*
# docker CLI + compose plugin (the runner talks to the host daemon over the mounted socket)
COPY --from=docker:27-cli /usr/local/bin/docker /usr/local/bin/docker
COPY --from=docker:27-cli /usr/local/libexec/docker/cli-plugins/docker-compose /usr/local/libexec/docker/cli-plugins/docker-compose
# toolchains the workflows expect on the runner
COPY --from=golang:1.26 /usr/local/go /usr/local/go
COPY --from=node:20-bookworm-slim /usr/local/bin/node /usr/local/bin/node
COPY --from=mikefarah/yq:latest /usr/bin/yq /usr/local/bin/yq
ENV PATH=/usr/local/go/bin:/usr/local/bin:$PATH
# the same unprivileged user GitHub's runner uses (uid 1001) — this is what makes ownership bugs reproduce
RUN useradd -m -u 1001 -s /bin/bash runner && echo 'runner ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/runner
USER runner
WORKDIR /home/runner
