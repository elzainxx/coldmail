# coldmail

The parent repository for the coldmail platform. It contains **no code of its own**: it pins four
independent repositories, as git submodules, at the commits that were verified together.

| path | repository | what it is |
|---|---|---|
| `coldmail-verify` | [`elzainxx/coldmail-verify`](https://github.com/elzainxx/coldmail-verify) | **Module 1** — email verification. A Go control plane that holds all state and decisions, and a Ruby verifier node (a pinned, unmodified `truemail` engine) that does the SMTP probing. |
| `coldmail-send-managed` | [`elzainxx/coldmail-send-managed`](https://github.com/elzainxx/coldmail-send-managed) | **Module 2** — sending on operator-managed SMTP infrastructure. A Go control plane plus Node.js workers. |
| `coldmail-send-byo` | [`elzainxx/coldmail-send-byo`](https://github.com/elzainxx/coldmail-send-byo) | **Module 3** — sending on a user's own SMTP accounts (From-gate, campaigns, quarantine, notifications). Forked from module 2. |
| `coldmail-platform` | [`elzainxx/coldmail-platform`](https://github.com/elzainxx/coldmail-platform) | **Documentation only** — the canonical module contract, the cross-module audit, the list of what was deferred and why, and the record of what was actually verified. |

All five repositories are private.

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
- Module 2's `dev.sh` has **not** had that change; see `coldmail-send-managed/Docs/future-work.md`.
- If `go` is run on a host where antivirus quarantines freshly built binaries, run it in a container.

## Updating the pins

After committing in a module, record the new commit here:

```bash
git -C coldmail-send-byo pull          # or: cd into the module, commit, push
git add coldmail-send-byo
git commit -m "Pin coldmail-send-byo at <sha> (<why>)"
```

Only pin commits whose suite and gates were green. The record of what was run, at which commit,
lives in `coldmail-platform/verification-runs.md`.

## Where to start reading

1. `coldmail-platform/README.md` — what the platform repo holds and in what order to read it.
2. `coldmail-platform/canonical-module-contract.md` — the shape a module is supposed to have.
3. `coldmail-platform/deferrals-and-false-greens.md` — what is deliberately not done, and every way a
   green signal in this body of work turned out not to be evidence.
4. Each module's `Docs/go-live-checklist.md` (or `go-live-runbook.md` for module 1) — what remains
   before a real-provider pilot.
