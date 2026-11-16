# coldmail

The parent repository of the coldmail platform. It contains **no product code of its own**: it pins four independent repositories, as git
submodules, at the commits that were verified **together**, and carries the one list of things only the owner can do
([`OWNER-ACTIONS.md`](OWNER-ACTIONS.md)). Its only other content is `tools/` — a local rehearsal aid for CI.

## The four repositories

| path | repository | what it is | has CI |
|---|---|---|---|
| `coldmail-verify` | [`elzainxx/coldmail-verify`](https://github.com/elzainxx/coldmail-verify) | **Module 1 — email verification.** A Go control plane that holds all state and all decisions (port 25 closed), and a Ruby verifier node — the *pinned, unmodified* `truemail` 3.3.1 engine behind a thin forked wrapper — that does the SMTP probing from a vetted port-25 host. | yes |
| `coldmail-send-managed` | [`elzainxx/coldmail-send-managed`](https://github.com/elzainxx/coldmail-send-managed) | **Module 2 — sending on operator-managed SMTP infrastructure.** A Go control plane (the only database client and the only decryptor) and Node.js workers (an mTLS client with no database and no KMS access). | yes |
| `coldmail-send-byo` | [`elzainxx/coldmail-send-byo`](https://github.com/elzainxx/coldmail-send-byo) | **Module 3 — sending on a user's own SMTP accounts.** Forked from module 2 at its tag `module3-fork-point`; adds the From-gate (SPF / DMARC / DKIM alignment), campaigns, quarantine and notifications. | yes |
| `coldmail-platform` | [`elzainxx/coldmail-platform`](https://github.com/elzainxx/coldmail-platform) | **The platform.** Phases 0 (groundwork) and 1 (schema) are done, and Phase 2 (the money core) is in progress with its first part (the Phase 1 rulings, the install procedure, the harness on the real Supabase Postgres image) done: a Go service skeleton, a React + TypeScript + Tailwind placeholder, the `platform` schema (users, jobs, per-module balances, an append-only ledger, unit costs, M3 entitlements, suppressions, the admin audit) and its migrator, module 1 moved into its own `verify` schema, and a real-infrastructure harness that builds the three modules from the commits pinned in its `tools/modules.lock` and runs them as real services beside the platform against its real `public.users` / `public.job_items`. Also the canonical module contract, the cross-module audit, everything that was deferred and why, and the record of what was actually verified. | yes — `go`, `web`, `gates`, `harness`, `db-tests`, `supabase`, `gitleaks`, `platform-check` (and the dispatch-only `fault-proofs`) |

All five repositories (these four and this one) are private.

## How they fit

```
                          ┌──────────────────────── coldmail-platform (docs) ───────────────────────┐
                          │  canonical-module-contract · audit · deferrals · verification record    │
                          └───────────────▲───────────────────────▲───────────────────────▲─────────┘
                                          │ governs the shape     │                       │
   user-supplied address ──►  coldmail-verify (M1)         coldmail-send-managed (M2)  coldmail-send-byo (M3)
                               control plane ──► verifier       control plane ──► workers   control plane ──► workers
                               (decides)        node (probes)   (decides)         (send)     (decides + From-gate)  (send)
                               verdict: valid / invalid /       operator's pool of          the user's own SMTP
                               risky / unknown + reason         SMTP accounts               accounts (M3 forked from M2)
```

The modules are **deliberately independent**: separate histories, separate rule files (`CLAUDE.md` / `PROJECT_RULES.md`), separate CI gates, no shared
code path and no build-time coupling. A finding that spans them has nowhere honest to live inside any one of them, which is why the platform repo exists.
Where a cross-module decision changes a module, the change lands *in that module*, under that module's rules and gates.

**The platform contract** is [`coldmail-platform/canonical-module-contract.md`](coldmail-platform/canonical-module-contract.md): Part 1 is the shape a module is
supposed to have (naming, routes, roles, schema layout, gate set); Part 2 is the register of what the platform assumes of a module; Part 3 is the UI-readiness
assessment. The audit that produced it, and every deliberate deferral, are in the same repository.

## Clone and verify

```bash
git clone --recurse-submodules https://github.com/elzainxx/coldmail.git
# if you cloned without --recurse-submodules:
git submodule update --init --recursive
```

Each submodule is checked out at the exact commit this repository pins (a detached HEAD). That is deliberate: **a commit here means "these four commits,
together, are the set that was verified."** Do **not** rename the submodule directories — the sender modules' Docker Compose project names derive from the
directory name and their test harnesses address containers by those names.

**What "green" means: a GitHub Actions run, on a real runner, of the pinned commit.** A run on a developer's machine does not count; until 2026-11-08 "green"
here had only ever meant a Docker Desktop run on Windows, and the first real-runner runs of the same commits were red in all three code repositories (false-green
class 20 in [`coldmail-platform/deferrals-and-false-greens.md`](coldmail-platform/deferrals-and-false-greens.md)). The record of every run, with its URL, is
[`coldmail-platform/verification-runs.md`](coldmail-platform/verification-runs.md); if a table here and that file ever disagree, that file wins.

## Run a module

Each module is run from its own directory, and **Go is built and tested in Docker** (a host-run Go result is not admissible evidence on the Windows development host).

| module | start here |
|---|---|
| `coldmail-verify` | `Docs/install-and-deploy.md` — a throwaway Postgres, `go test ./...` in a `golang` container, the verifier-node image, then `scripts/check-*.sh` |
| `coldmail-send-managed` | `Docs/install-and-deploy.md` — `bash scripts/dev.sh certs && bash scripts/dev.sh reset && bash scripts/dev.sh test`, then each `tests/harness/checks/*.sh`, then `bash scripts/dev.sh down` |
| `coldmail-send-byo` | the same sequence as module 2 (`Docs/install-and-deploy.md`) |

Rehearsing CI locally (rehearsal only — never cite it as green): `tools/ci-replica.sh <repo> .github/workflows/<workflow>.yml <job>` runs a job on Docker
Desktop's own Linux filesystem as an unprivileged uid with `bash -e` semantics, which matches a runner far better than a Windows bind mount. It does not run
`uses:` steps or `services:` containers, and it needs about 5 GB of the Docker VM, so run one job at a time. The two sender modules also have an on-demand
`outage-drill` workflow (`gh workflow run outage-drill.yml -R elzainxx/<repo>`): the whole harness in the default non-RAM mode, then a real `docker stop postgres`.

## Where everything lives

Every module repository has **the same layout**, so each one is read the same way:

| | |
|---|---|
| `README.md` | what the module is, quick start, map of the docs |
| `Docs/architecture.md` | how it is built and why |
| `Docs/install-and-deploy.md` | developing, testing locally, and deploying |
| `Docs/operator-runbook.md` | running it: monitoring, capacity, recovery |
| `Docs/config-reference.md` | every configuration key (checked against the code by a gate) |
| `Docs/api-contract.md` | the HTTP contract (checked against the code by a gate) |
| `Docs/security-posture.md` | what is protected, how, and what is not |
| `Docs/go-live-checklist.md` | every item with its real status — done (with evidence), owner-only, or not applicable |
| `Docs/future-work.md` | what was deliberately deferred, and what reopens it |
| `Docs/open-decisions.md` | the decision ledger — **zero open** |
| `Docs/adr/` | numbered architecture decision records |
| `Docs/history/` | phase specs, closed plans, superseded docs, provenance — read-only |

Across repositories: **[`OWNER-ACTIONS.md`](OWNER-ACTIONS.md)** (this repo) is the single list of what only the owner can do, in order — nothing open lives anywhere else.
[`coldmail-platform/`](coldmail-platform/README.md) holds the contract, the audit, the deferrals and the verification record.

## Rules that hold across all four repositories

- **Green means the GitHub runner.** Every fix is proved by a control that goes red without it. A local Docker is not required and not trusted: every test, gate and secret scan runs on the runner.
- **Every container image is pinned by digest** (`image@sha256:…`), and a gate in each repository rejects any that is not.
- **Line endings are LF everywhere**, enforced by each repository's `.gitattributes` (a `git clone -c core.autocrlf=…` only configures the top level).
- **No secret is ever committed.** Scan the full history (`gitleaks detect --log-opts="--all"`) before every push; every repository, this one included, also runs `gitleaks.yml` on the runner after every push (a pinned, checksum-verified gitleaks that proves itself on each run before it scans).
- **No key permission is ever loosened to make a test pass** — ownership is fixed instead (`tools/own-secrets.sh` in the sender modules).
- The truemail engine is pinned exactly and never forked (Door 5 in module 1); `assert-gem-unmodified.sh` guards it.
