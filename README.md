# coldmail

The parent repository for the coldmail platform. It contains **no product code of its own**: it pins four
independent repositories, as git submodules, at the commits recorded in
[`coldmail-platform/verification-runs.md`](https://github.com/elzainxx/coldmail-platform/blob/main/verification-runs.md).
Its only other content is `tools/ci-replica.sh`, a local rehearsal aid described below.

| path | repository | what it is |
|---|---|---|
| `coldmail-verify` | [`elzainxx/coldmail-verify`](https://github.com/elzainxx/coldmail-verify) | **Module 1** — email verification. A Go control plane that holds all state and decisions, and a Ruby verifier node (a pinned, unmodified `truemail` engine) that does the SMTP probing. |
| `coldmail-send-managed` | [`elzainxx/coldmail-send-managed`](https://github.com/elzainxx/coldmail-send-managed) | **Module 2** — sending on operator-managed SMTP infrastructure. A Go control plane plus Node.js workers. |
| `coldmail-send-byo` | [`elzainxx/coldmail-send-byo`](https://github.com/elzainxx/coldmail-send-byo) | **Module 3** — sending on a user's own SMTP accounts (From-gate, campaigns, quarantine, notifications). Forked from module 2. |
| `coldmail-platform` | [`elzainxx/coldmail-platform`](https://github.com/elzainxx/coldmail-platform) | **Documentation only** — the canonical module contract, the cross-module audit, the list of what was deferred and why, and the record of what was actually verified. |

All five repositories are private.

## What "green" means here

**Green means a GitHub Actions run, on a real runner, of the pinned commit.** A run on a developer's machine does not
count: until 2026-11-08 "green" here had only ever meant a Docker Desktop run on Windows, and the first real-runner runs
of those same commits were red in all three code repositories (false-green class 20 in
[`coldmail-platform/deferrals-and-false-greens.md`](https://github.com/elzainxx/coldmail-platform/blob/main/deferrals-and-false-greens.md)).

State of the pins as of **2026-11-08** (the maintained record, with every run URL, is `coldmail-platform/verification-runs.md`
— if this table and that file ever disagree, that file wins):

| module | GitHub Actions |
|---|---|
| `coldmail-verify` | **green** — `82644ae`, 9 of 9 jobs |
| `coldmail-send-managed` | **green** — `51e081d`, harness 62/0 |
| `coldmail-send-byo` | **green** — `9aad2db`, harness 100/0 (its earlier red, `TestEvaluate_T5…`, was a real defect in the From-gate's DNS handling under a resolver search domain: ruled as `M3-CI-OD-1` and fixed, not loosened) |

All three heads are green GitHub Actions runs, so no pin is a disclosed exception. **Still open** (each recorded, none hidden):
module 1 reports a domain with an A record and no MX as `invalid / no_mx` (needs a ruling); Ruby 3.2 is past end-of-life (the
3.3/3.4 move is a separate decision); one unexplained, non-recurring red in module 3's `Phase 3 dispatch` package (not chased; if
it recurs, check the `go_suite` SIGPIPE race first). Both senders also have an on-demand `outage-drill` workflow (the whole
harness in the default non-RAM mode, then a real `docker stop postgres`): 22/22 each on a runner.

## Cloning

```bash
git clone --recurse-submodules https://github.com/elzainxx/coldmail.git
```

If you cloned without `--recurse-submodules`, fetch the four modules afterwards:

```bash
git submodule update --init --recursive
```

Each submodule is checked out at the exact commit this repository pins (a detached HEAD). That is
deliberate: a commit here means "these four commits, together, are the set that was verified."

## Why submodules and not one big repository

The modules are deliberately independent: separate histories, separate rule files (`CLAUDE.md` /
`PROJECT_RULES.md`), separate CI gates, and no shared code path. A merged history would also rewrite
every commit hash, and the platform documents cite commits by hash (the hashes in
`coldmail-platform/verification-runs.md` and `deferrals-and-false-greens.md` are re-checked by the
platform verification runner that `verification-runs.md` describes). Submodules keep every hash intact and every module independently deployable.

**Do not rename the submodule directories.** The sender modules' Docker Compose project names are
derived from the directory name (`coldmail-send-managed`, `coldmail-send-byo`), and their test
harnesses refer to containers by those names (for example `coldmail-send-byo-worker-1`).

## Running a module's tests

Each module is run from its own directory, and Go is built and tested in Docker.

| module | commands |
|---|---|
| `coldmail-verify` | see `coldmail-verify/Docs/ONBOARDING.md` §5 — a throwaway Postgres, `go test ./...` in a `golang` container, then the scripts in `scripts/check-*.sh` |
| `coldmail-send-managed` | `bash scripts/dev.sh certs && bash scripts/dev.sh reset && bash scripts/dev.sh test`, then each `tests/harness/checks/*.sh`, then `bash scripts/dev.sh down` |
| `coldmail-send-byo` | the same sequence as module 2 |

Notes that apply to the two sender modules:

- `scripts/dev.sh` uses a durable Postgres by default. Set `DEV_RAM_PG=1` for the RAM-backed, `fsync=off`
  Postgres that CI uses — but never on a stack you intend to `docker stop`, because that loses the
  database (module 3, issue #131).
- Module 2's `dev.sh` has the same opt-in now (ported 2026-11-08) and it is verified on a runner: the whole harness in the default
  (non-RAM) mode passes, and so does a real `docker stop postgres` drill (`gh workflow run outage-drill.yml -R
  elzainxx/coldmail-send-managed`; the same workflow exists in module 3). See `coldmail-send-managed/Docs/future-work.md`.
- No compose file, Dockerfile or workflow uses `:latest`: Mailpit, CoreDNS and the DNS black-hole fixture are pinned by digest, and
  an `image_pins` gate keeps it so. The verifier-node image installs a committed `Gemfile.lock` frozen.
- `scripts/dev.sh certs` hands each dev key to the uid of the container that reads it (`tools/own-secrets.sh`), keeping mode
  600. Never "fix" a permission error there with `chmod`; a CI step fails if the keys are loosened.
- If `go` is run on a host where antivirus quarantines freshly built binaries, run it in a container.

## Rehearsing CI on Linux (rehearsal only)

`tools/ci-replica.sh` runs a repo's GitHub Actions job locally on Docker Desktop's own Linux filesystem, as an unprivileged
uid, with `bash -e` step semantics — so permission enforcement and shell behaviour match a runner far better than a
bind-mounted Windows run does:

```bash
tools/ci-replica.sh coldmail-send-byo .github/workflows/real-infra.yml behavioral
tools/ci-replica.sh coldmail-verify   .github/workflows/ci.yml door5-gem-unmodified
```

It is **not** a substitute for CI. It does not run `uses:` steps or `services:` containers, and it found five of the eight
masked failures behind class 20 and then **passed both sender modules that failed on the real runner**. Use it to iterate in
minutes; cite only the GitHub Actions run. It needs about 5 GB of the Docker VM, so run one job at a time. Note that host
tools under Git Bash (`sed`, `awk`, `grep` on a file) strip `\r`; inspect line endings with `tr -cd '\r' < file | wc -c`
or `cat -A` inside a Linux container.

## Updating the pins

After committing in a module, record the new commit here:

```bash
git -C coldmail-send-byo pull          # or: cd into the module, commit, push
git add coldmail-send-byo
git commit -m "Pin coldmail-send-byo at <sha> (<why>)"
```

Only pin commits whose **GitHub Actions run** is green. If a pin ever has to be a red one because the red is a recorded open
decision, say so in the pin's commit message and in the table above (the previous pin of `coldmail-send-byo` was exactly that, for
`M3-CI-OD-1`, until it was fixed). The record of what was run, at which commit, lives in `coldmail-platform/verification-runs.md`.

## Where to start reading

1. `coldmail-platform/README.md` — what the platform repo holds and in what order to read it.
2. `coldmail-platform/canonical-module-contract.md` — the shape a module is supposed to have.
3. `coldmail-platform/deferrals-and-false-greens.md` — what is deliberately not done, and every way a
   green signal in this body of work turned out not to be evidence.
4. Each module's `Docs/go-live-checklist.md` (or `go-live-runbook.md` for module 1) — what remains
   before a real-provider pilot.
