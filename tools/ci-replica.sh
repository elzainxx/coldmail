#!/usr/bin/env bash
# ci-replica.sh <repo-dir-name> <workflow-file> <job-id> [--rebuild]
# Rehearse a GitHub Actions job locally on the Docker VM's own Linux filesystem (NOT a Windows bind mount),
# as uid 1001, with the docker socket mounted. See tools/runner/Dockerfile for why. REHEARSAL ONLY: green here
# means "worth pushing", not "green" — GitHub Actions on a real runner is the source of truth.
#   e.g.  tools/ci-replica.sh coldmail-send-byo .github/workflows/real-infra.yml behavioral
set -u
T="$(cd "$(dirname "$0")" && pwd)"; ROOTDIR="$(cd "$T/.." && pwd)"
REPO="${1:?repo dir name}"; WF="${2:?workflow file}"; JOB="${3:?job id}"
IMG=cm-runner:local
if [ "${4:-}" = "--rebuild" ] || ! docker image inspect $IMG >/dev/null 2>&1; then
  MSYS_NO_PATHCONV=1 docker build -t $IMG "$(cygpath -w "$T/runner")" || exit 2
fi
LINUXFS=/var/lib/cm-linux   # a path on the docker-desktop VM's real ext4 disk (NOT /tmp: that is a noexec tmpfs, NOT a Windows host path)
# create it world-writable-with-sticky-bit as root once (the runner user is uid 1001)
MSYS_NO_PATHCONV=1 docker run --rm -v $LINUXFS:/x alpine:3@sha256:f59abe656b692d901e184be3445e084786602108599d2a51d229c0f5a48c71bf sh -c 'chmod 1777 /x' >/dev/null
MSYS_NO_PATHCONV=1 docker run --rm --network host --user 1001:1001 --group-add 0 \
  --memory 5g --memory-swap 5g -e GOMEMLIMIT=3GiB -e GOMAXPROCS=3 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $LINUXFS:$LINUXFS \
  -v "$(cygpath -w "$ROOTDIR/$REPO"):/src:ro" \
  -v "$(cygpath -w "$T/runner"):/runner:ro" \
  -e COMPOSE_PARALLEL_LIMIT="${COMPOSE_PARALLEL_LIMIT:-1}" \
  $IMG bash /runner/run-workflow.sh "$REPO" "$WF" "$JOB"
