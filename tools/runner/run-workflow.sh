#!/usr/bin/env bash
# run-workflow.sh <repo-name> <workflow-file-relative-to-repo> <job-id> — runs INSIDE the cm-runner container.
# Executes the job's `run:` steps in order with GitHub's step semantics:
#   * each step is `bash -e {0}`  (NOT pipefail — that is what the runner uses by default)
#   * after a failure, later steps are skipped unless `if: always()`; `if: failure()` steps run only after a failure
#   * `uses:` steps are skipped (checkout = the clone below; setup-go/setup-node = toolchains in the image)
#   * job-level and step-level `env:` and `working-directory:` are honoured
# The repo is cloned (committed state of /src) into the VM's ext4, as user runner (uid 1001).
set -u
REPO="$1"; WF="$2"; JOB="$3"
ROOT="${CM_LINUXFS:-/var/lib/cm-linux}"; W="$ROOT/work"
mkdir -p "$W"; rm -rf "$W/$REPO"
git config --global --add safe.directory '*'
git clone -q /src "$W/$REPO" || { echo "clone failed"; exit 2; }
# overlay the WORKING TREE (tracked + untracked-not-ignored) so uncommitted edits are rehearsed before they are committed
( cd /src && git ls-files -co --exclude-standard -z | tar --null -T - -cf - ) | tar -xf - -C "$W/$REPO"
cd "$W/$REPO" || exit 2
echo "[replica] $REPO @ $(git rev-parse --short HEAD) as uid $(id -u) in $PWD ($(stat -f -c %T . 2>/dev/null || echo ?) filesystem)"
export CI=true GITHUB_ACTIONS=true GITHUB_WORKSPACE="$PWD" RUNNER_OS=Linux GITHUB_REF_NAME=main
eval "$(yq -o=json ".jobs.\"$JOB\".env // {}" "$WF" | jq -r 'to_entries[] | "export \(.key)=\(.value|tostring|@sh)"')"
steps="$(yq -o=json ".jobs.\"$JOB\".steps" "$WF")"
n="$(echo "$steps" | jq 'length')"
failed=0; declare -a RES
for i in $(seq 0 $((n-1))); do
  step="$(echo "$steps" | jq -c ".[$i]")"
  name="$(echo "$step" | jq -r '.name // .uses // "step"')"
  run="$(echo "$step" | jq -r '.run // empty')"
  cond="$(echo "$step" | jq -r '.["if"] // empty')"
  if [ -z "$run" ]; then RES+=("skip(uses)  $name"); continue; fi
  case "$cond" in
    "always()") ;;
    "failure()") if [ $failed = 0 ]; then RES+=("skip        $name"); continue; fi;;
    *) if [ $failed = 1 ]; then RES+=("skip(after failure) $name"); continue; fi;;
  esac
  wd="$(echo "$step" | jq -r '.["working-directory"] // empty')"
  stepenv="$(echo "$step" | jq -r '(.env // {}) | to_entries[] | "export \(.key)=\(.value|tostring|@sh)"')"
  echo; echo "::step:: $name"
  ( cd "${wd:-.}" && eval "$stepenv" && bash -e -c "$run" ); rc=$?
  if [ $rc -eq 0 ]; then RES+=("ok          $name"); else RES+=("FAILED rc=$rc $name"); failed=1; fi
done
echo; echo "================ [replica] $REPO / $JOB — step results ================"
printf '%s\n' "${RES[@]}"
echo "[replica] job result: $([ $failed = 0 ] && echo SUCCESS || echo FAILURE)"
[ $failed = 0 ]
