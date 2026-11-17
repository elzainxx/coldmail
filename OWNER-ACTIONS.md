# Owner actions — everything only you can do

**This is the one list, and it holds only things a person has to do in the real world.** Nothing that code can close is on it: every module's decision ledger (`Docs/open-decisions.md`) is at **zero open**,
and every module's `Docs/future-work.md` holds only deferred *engineering* that needs no decision from you, apart from the choices parked under its own **PARKED** heading (M1 §5, M2 §7b; M3 has none). Each module's `Docs/go-live-checklist.md`
keeps the per-row status and the evidence (✅ done · ⏳ owner · 🔧 build task · ➖ n/a); this file is the order to work through them in.

Written 2026-11-13, updated 2026-11-17 (Phase 2 close-out). Nothing below blocks the code or CI — all five repositories are green on GitHub Actions (see `README.md` for the pinned heads). It all blocks *going live*, or is about your own machine. Ids point at the module's checklist row:
**G\*** = `coldmail-verify` (M1) · **M2-GL-\*** = `coldmail-send-managed` (M2) · **M3 §n** = `coldmail-send-byo` (M3), by its checklist section.

---

## 1. The real-provider smoke test (M2 and M3) — written, never run

One real message to yourself, a second provider, deliberate failure checks, a small real batch. A bad first impression on a real sending
reputation is not a test failure you can re-run, so the prerequisites are strict. Do them in this order:

1. **Back up the master KMS key off-host** — encrypted, two independent locations; record the `CREDENTIAL_KEY_ID` pairing; fill in the
   "where it lives / who can reach it" table. There is no escrow and no recovery share: losing it is the one unrecoverable loss.
   — M2-GL-8 · M3 §8 · `Docs/operator-runbook.md` (disaster recovery, key backup).
2. **Run the recovery drill on staging, to a completed send**, with *your* key (it is proven on the dev stack, not on your key). — same rows.
3. **Sign the accepted-risk record**: the master key has no rotation path (who, when, against which version). — M3 §12.
4. **Supply**: a throwaway or low-stakes sending account at a real provider; two recipient addresses you control at *different* providers;
   the provider's real per-mailbox limits and SPF/DKIM state; `jq`; and someone who knows you are doing it.
5. **Run it**: M2 → M2-GL-11 (`Docs/go-live-checklist.md#real-provider-smoke-test-the-first-live-send`); M3 → M3 §11 (`Docs/go-live-checklist.md#real-provider-smoke-test`).
   Afterwards restore `daily_limit`, confirm no account is left paused or quarantined, diff against the baseline, and record the result.

## 2. The port-25 host for M1 (the verifier node) — G1.1 … G1.17

Nothing SMTP-level can run until a host exists that can open outbound port 25. The market for such hosts is narrow; vet one on a refundable trial.

1. **G1.1** — vet the host against V1–V5: outbound :25 open, settable PTR, clean IP, dedicated IP, egress IP == PTR == audited IP.
   (`Docs/install-and-deploy.md` §3.2a · `Docs/future-work.md` B1–B4)
2. **G1.4** — give the box a **short hostname (no dot)** and a nameservers-only `resolv.conf`. A box that skips this audits red and does no SMTP (ADR-0019).
3. **G1.5** — **install the egress firewall** before the first real probe: `nft -f verifier-node/egress/verifier_egress.nft`, mirrored in the provider's
   egress security group; restrict the instance metadata service (**IMDSv2, hop limit 1**). This is the defence-in-depth layer under the probe-destination
   guard (ADR-0021). (`Docs/install-and-deploy.md` §3.2c)
4. **G1.6** — DNS for the verifier domain: A-record → egress IP, PTR → FQDN, SPF TXT authorising the egress IP.
5. **G1.3, G1.7, G1.8** — egress-25 smoke test from the box, then set `port25_open=true` (a `cp_admin` break-glass write until the operator command, FW-2, is built);
   point the box at real config (`SMTP_PORT=25`, real `DNS`) and `POST /v1/config/reload`; set the brain's node descriptor (`TM_NODE_*`, `TM_SMTP_MODE=enabled`) and
   generate the per-node token in `TM_NODE_TOKENS`. (`Docs/install-and-deploy.md` §3.2d)
6. **G1.9, G1.10** — first audit green and the node promotes to `active`; warm-up cap starts at `TM_WARMUP_DAILY_CAP=50` and steps up on clean prior-day audits (elapsed real days).
7. **G1.11** — live-HTTP verification matrix on the first Linux host, **and decide where TLS terminates** (the app, or a proxy). No recommendation is recorded; do not infer one.
8. **G1.12** — go-live acceptance proofs on the real IP: break the PTR → quarantine → recover; an honest corporate address → `valid`; Gmail/O365/Yahoo → `provider_no_smtp`;
   warm-up degrade; port scan; four-way IP identity.
9. **G1.13, G1.14, G1.15** — DR-4 backup/PITR restore-into-isolation drill (for the verification log, restore is the only recovery path); **pepper backup and recovery drill**
   (redundant, geo-separate, access-audited — losing the pepper de-joins all history); control-plane host hardening (core-dump suppression, access control, PN-12 threat model).
10. **G1.16, G1.17** — observe a real greylist reject-then-accept round trip (un-mockable, GAP-35); two-box reputation isolation (needs two real IPs).

## 3. The paid vendor (ZeroBounce) and its DPA (M1) — G2.1 … G2.9

External fallback sends addresses to a third party; **enabling it before the DPA is signed is unlawful sub-processing.** Order matters. **The vendor is ZeroBounce (ruled) and its client is built and shipped DISABLED** (Phase 2 close-out A6: `coldmail-verify/Docs/vendor-zerobounce.md`). Nothing is sent to ZeroBounce until you have done every step below, in this order:

1. **Create the ZeroBounce account** (G2.1 — the commercial decision is made: ZeroBounce).
2. **Sign the DPA** and complete the §7.4 due-diligence checklist: retention, deletion, TLS, key custody (G2.2).
3. **Verify the status mapping against ZeroBounce's live API documentation.** The mapping table in `coldmail-verify/Docs/vendor-zerobounce.md` was built from ZeroBounce's official SDKs (their documentation site refused automated access); it carries a visible NOTE and lists what is UNVERIFIED (rate-limit behaviour, error bodies, whether an `unknown` answer is billed, price per call). Read that list against the live docs and tell me of any difference **before** you switch the vendor on.
4. **Put the API key in the environment variable the dial names**: `TM_EXTERNAL_ZEROBOUNCE_KEY_ENV` names the variable (default `ZEROBOUNCE_API_KEY`). The key itself lives only in that variable on the control-plane host; it is never in a repository, a workflow or a config file. (`TM_VENDOR_KEYS` is no longer read.)
5. **Set the daily spend cap** `TM_EXTERNAL_DAILY_SPEND_CAP` (credits per UTC day; the default 0 sends nothing) and, once you have seen the residue-tail volume, the other budget ceilings (`TM_EXTERNAL_DAILY_CAP`, `_MONTHLY_CAP`, `_PER_JOB_CAP`, `_RATE_CEILING`) — policy "start low, raise from data" is ruled, only the numbers wait (G2.4).
6. **Set the platform price of the vendor unit**: `platform.unit_costs` seeds `m1_vendor` at 2 as a placeholder; it must stay above 1 and cover what ZeroBounce charges you per call (an admin setting).
7. **G2.6** — the platform's disclosure wording for vendor egress, with an opt-out (ruled: disclose and offer the opt-out). **G2.7** — verify at integration that the platform opt-out flag ↔ a policy without the `external` block, 1:1.
8. **Then switch the vendor on** (G2.5): `TM_EXTERNAL_DPA_CONFIRMED=true` and `TM_FALLBACK_MODE=enabled` on the control plane (the kill-switch rung and the daily spend cap stay as the brakes).
9. **G2.8, G2.9** — standing vendor controls (cumulative-egressed metric; a periodic vendor-deletion request, PN-7); measure the vendor's real accuracy on the residue (never claimed until measured).

The vendor adapter (G2.3) is **built** (no longer a build task); what remains here is only the owner steps above.

## 4. The go-live checklist items that remain, per module

Work these in each checklist's own "order of operations". Listed once here so nothing is only in a module doc.

### M1 `coldmail-verify` — besides sections 2 and 3
- **G0.3** — apply migrations 0001…0018 to the production database and confirm `verification_raw` partition headroom.
- **G0.4** — re-run `govulncheck ./...` in `control-plane/` immediately before the pilot (clean 2026-11-07; the advisory database moves).
- **G3.1, G3.2** — the sender emits the locked `send_outcome` shape on an authenticated feed; provision the mTLS trust anchor and the control plane's client credential (arrive with the sender).
- **G3.5** — the platform's disclosure wording "your sends train our accuracy" (disclose-don't-hide is ruled). **G3.6** — real accuracy numbers, and promotion/weaning actually firing (needs real outcomes over time).

### M2 `coldmail-send-managed`  (in the checklist's recommended order)
- **M2-GL-2** — diff the real `public.users` / `public.job_items` against the assumed shape (ADR-0007); if they differ, raise a new Open Decision — do not adapt silently.
- **M2-GL-3** — platform-side confirmation that its own migrator/app code does not use advisory-lock keys `9_000_000_000–9_999_999_999`, and which admin role runs the migration (credential from the platform secret store).
- **M2-GL-4** — verify the production KMS key policy: `Decrypt` for the Control's runtime role **only**; record who verified, against which policy, when.
- **M2-GL-9** — on pilot day re-run `govulncheck ./...` in `services/control`, `tools/send-managed-migrate`, `tools/provision-worker`, `tests/harness`; re-resolve the pinned image digests at the same time.
- **M2-GL-10** — monitoring: uptime monitor on `/readyz`; a scheduled `GET /v1/admin/health` poll (this is what makes the webhook fire); `alert_webhook_url` set and a test alert *received*; logs shipped with retention.
- **M2-GL-5** — provision real workers (`provision-worker new` → `seed` → deploy with the plaintext token); know the decommission procedure (isolate the host first, revoke second).
- **M2-GL-1** — create the real shared pool and accounts; `PUT /v1/admin/config/default_shared_pool_id`; one real `quote → run → report` to `sent`.
- **M2-GL-7** — pre-warm the real SMTP accounts (conservative `daily_limit`, raised over days/weeks); confirm no account's `smtp_host` is private-range.
- **M2-GL-12** — **required:** promote `retention_mode` to `enforce` after confirming `debug_log_retention_days` against your privacy commitments. Left at `shadow`, `send_logs` grows without bound.
- **M2-GL-6** — after an observation window, review the shadow rows and promote `autoquarantine_mode` / `autopause_mode` to `enforce` (or tune first). Deliberately not day one.
- **M2-GL-PF / M2-GL-SP** — the final pre-flight on the day (harness green against the images you deploy; SIGTERM grace ≥ `shutdown_drain_timeout_sec`; `/readyz` `db:true, singleton_lock:true`; health not `exhausted`) and the deployment half of `Docs/security-posture.md` §5.

### M3 `coldmail-send-byo`  (A–F as in its checklist)
- **§2** — diff the real `public.users` / `public.job_items` schema (ADR-0007). **§3** — platform confirms it uses neither advisory-lock band `8_000_000_000–8_999_999_999` (M3) nor `9_000_000_000–9_999_999_999` (M2) on the shared Postgres, and which role runs `MIGRATE_DATABASE_URL`.
- **§13 (required)** — decide the `send_logs` retention window you can defend to a user (`debug_log_retention_days`) before real content accumulates.
- **§9** — re-run `govulncheck ./...` in `services/control`, `tools/send-byo-migrate`, `tools/provision-worker`, `tests/harness` immediately before the pilot.
- **§4** — KMS/IAM sign-off (`Decrypt` for the Control's runtime role only). **§10** — monitoring on `/readyz`, a health poller for the webhook, a received test alert, logs with retention; re-run the `outage-drill` workflow on the deployed shape.
- **§1** — walk the real self-serve path as a throwaway user (`POST /v1/send-byo/accounts` → From gate → routable; `accounts.healthy >= 1`; one `quote → run → report` to `sent`). **§5** — provision production workers out of band. **§7** — confirm each sending account is pre-warmed.
- **Pre-flight on the day** — your production unit's SIGTERM grace clears `shutdown_drain_timeout_sec`; `/readyz` and `/v1/admin/health` as above; full harness against the images you deploy; read `Docs/future-work.md` and accept the V1 limits (chiefly **no bounce or complaint ingestion**).
- **§14 (required, after an observation window)** — promote `retention_mode` and `account_purge_mode` to `enforce`, one at a time, each after reading its shadow count; `account_purge_mode=enforce` is irreversible per row. Until both are promoted, `send_logs` grows without bound and a deleted user's SMTP credential outlives its promised window.
- **§6** — decide when to promote `autoquarantine_mode`, `autopause_mode`, `campaign_expiry_mode` from `shadow` (open-ended posture decisions). Campaign expiry does not enforce until you do, and the original evidence for its window (Stage 10.4/10.6) is in none of the four repositories, so the value cannot be re-derived from them.

### The platform (`coldmail-platform`)
- Nothing to run. When the real platform exists, the two integration confirmations above (M2-GL-2/3, M3 §2/3) and M1's G2.7 are the platform-side facts the contract needs.
- **Supabase setup (ruled; now a required install step).** Run `coldmail-platform/db/install/preprovision.sql` once, as `postgres`, before the module migrations; it is step 2 of `coldmail-platform/Docs/install.md`, and the platform's `harness` and `db-tests` workflows run it exactly that way on the digest-pinned `supabase/postgres` image. Modules 2 and 3 are unchanged. When the project is created, the migrator needs the **direct** (session-mode) connection string, not the pooler.
- **In Supabase, remove `public` (and `platform`) from the exposed API schemas** (Settings → API → *Exposed schemas*). The platform's tables are reached only by its Go service over the database connection, never through the Data API; the platform revokes `anon`, `authenticated` and `service_role` on its two `public` tables and enables **no** row-level security (ruled). A runner cannot check this setting: it is yours.
- **First admin.** After the first Supabase login exists, run `platform-migrate create-first-admin --auth-user-id <id> --display-name "<name>"` (`coldmail-platform/Docs/install.md` step 4). Admin management is Phase 7.
- **Vendor-fallback price.** `platform.unit_costs` seeds `m1_vendor` at 2 as a placeholder; it is an admin setting (must stay above 1). Choose the real number before launch.
- **The repositories are public now (you ruled it on 2026-11-17 when GitHub Actions refused every job: the private repositories had used up the free minutes).** The pre-publication audit is `coldmail-platform/Docs/public-release-audit.md`: no real secret, key or token is in any commit of any repository. What you should acknowledge (it cannot be removed without rewriting history, which was not done): (a) your personal Gmail address is the author of your commits in all five repositories, and your name; consider GitHub → Settings → Emails → "Keep my email addresses private" and "Block command line pushes that expose my email" for future commits; (b) your Windows user name and the layout of your workstation's disks appeared in a few documents (this file, `Docs/history/`): they are removed from the current files by a forward commit (git history keeps them), and the gate `check-personal-details` (platform `gates` and `platform-check`, parent `modules-lock`) now fails on any new Windows home path, drive-letter path or public IP address; (c) one public IP address your machine had on 2026-07-17 appeared in two `Docs/history/` files of `coldmail-verify`; (d) the licence wording, resolved on 2026-11-17: every repository carries the same one-paragraph `LICENSE` ("Copyright (c) 2026 Zain. All rights reserved. The source is visible for transparency only. No license is granted to use, copy, modify, distribute or run this software, in whole or in part."), the same words open every `NOTICE`, and the gate `check-license` keeps the five copies identical (the old "PROPRIETARY AND CONFIDENTIAL" wording is gone). **Cleanup that is yours (nothing was deleted):** the three Actions secrets `DEPLOY_KEY_COLDMAIL_VERIFY`, `_SEND_MANAGED`, `_SEND_BYO` on `coldmail-platform` and the three read-only deploy keys "coldmail-platform CI (read-only)" on the module repositories are no longer needed (the platform's workflows clone the public modules anonymously when the key is absent); the repository description of `coldmail-platform` still says "docs only".
- **Phase 2 decisions: all ruled and built** (`coldmail-platform/Docs/phase-2-closeout-spec.md` has each with its evidence). What is still yours from them: (a) the **ZeroBounce steps in section 3** above; (b) **an unparseable address is charged**: since module 1 now logs and serves a malformed bulk row as `invalid/invalid_syntax`, the charge table charges it like any settled answer (`m1_own`); the platform could instead pre-validate addresses before submit (Phase 4), tell me if you prefer that; (c) the five module-1 `unknown` reasons are now charged only when module 1 proves the recipient's server caused them (`failure_origin = remote`); the full origin table, including the cases module 1 could not classify honestly and left `undetermined` (free), is `coldmail-verify/Docs/failure-origin.md`: read the cases listed in its section 4 and say if any should lean the other way; (d) the one gitleaks exception for a placeholder SMTP-sink password stays (no history rewrite); the literal is gone from the tree and the harness mints the sink password per run.
- **Deploy keys (nothing to do — so you know where they are):** three read-only deploy keys titled "coldmail-platform CI (read-only)", one under Settings → Deploy keys on each of `coldmail-verify` (id 169900977), `coldmail-send-managed` (169900980) and `coldmail-send-byo` (169900981); their private halves are the Actions secrets `DEPLOY_KEY_COLDMAIL_VERIFY`, `DEPLOY_KEY_COLDMAIL_SEND_MANAGED`, `DEPLOY_KEY_COLDMAIL_SEND_BYO` on `coldmail-platform` and exist nowhere else; delete a key and `platform-check` goes red until a new pair is installed.

## 5. Archive the old GitHub repository

Archive **github.com/zexSites/codmailling-module-3** (Settings → General → *Archive this repository*). It is the pre-rename home of module 3; the live repository is
`github.com/elzainxx/coldmail-send-byo`. Nothing in this project reads it, and it was deliberately never touched or deleted.

## 6. Your workstation

- **Raise WSL memory.** `%USERPROFILE%\.wslconfig` currently has `memory=8GB`; the heavy gates (Postgres + Go build + Ruby image together) were reaped on this host. Suggested: `memory=10GB`,
  then `wsl --shutdown` and restart Docker Desktop. The CI gates run on GitHub's runners, so this only speeds local rehearsal.
- **BLOCKED: Docker is down on the owner's machine, and is expected to stay down.** Nothing in the repositories needs it any more: every test, gate and secret scan now runs on GitHub Actions
  (the runner is the only admissible test environment, and `gitleaks.yml` scans the full history of all five repositories on every push). It only blocks local rehearsal and the cleanup in the next bullet.
  **Docker has not started since 2026-11-12 19:29** (Docker Desktop: "distro installation failed" = `HCS_E_HYPERV_NOT_INSTALLED`). The Windows hypervisor log says *"Hypervisor launch failed; Either VMX not
  present or not enabled in BIOS"* on every boot since then, and `systeminfo` says *Virtualization Enabled In Firmware: No* — the machine's firmware stopped exposing Intel VT-x (an ASUS board, i5-11400F; it began with a
  7-second reboot after an unclean shutdown, and the BIOS clock was not reset, so it is probably not the CMOS battery). **You told me you could not get into the BIOS.** Until that is fixed no Docker, WSL2 or
  local container work is possible (CI is unaffected). Try: Del or F2 held from power-on (or Windows → Settings → System → Recovery → Advanced startup → UEFI Firmware Settings), then Advanced → CPU Configuration →
  Intel (VMX) Virtualization Technology → Enabled → F10. After the fix `systeminfo | findstr /i Virtualization` must say *Yes*; then restart Docker Desktop. If the board keeps dropping its settings, suspect the PSU or
  RAM (XMP) stability. The pre-push secret scans of this period ran with a checksum-verified native `gitleaks` for that reason (recorded in the platform's `verification-runs.md`); the same scan now also runs on the runner after every push.
- **BLOCKED: Docker down on owner's machine — Docker leftovers from this project, not removed because Docker cannot start** (when Docker is back, say so and I will do it, or run it yourself). Look first with `docker images` and `docker volume ls`;
  these are the ones this project created:
  - images (tags): `cm-audit-m1-node:run`, `tm-r34:ci`, `tmvn-p2-test*`, `tm-diag`, `tm-diag3`, `zricethezav/gitleaks:latest`;
  - twelve dangling images proven to be truemail builds (they contain the truemail gem): `9a2f55b9dcf2 3002b09fdda1 49ccab0caab3 b0fc9a9dcd39 fa28128f200c 67009fe75006 f6260b96bd9e ba4c1d556362 fda1cf630bc8 73e7089e9939 f15ceaf17781 80da478a7c71`;
  - volumes `cm-gocache cm-gomod cm-gopath sendbyo-gocache sendbyo-gomod`, and the seven anonymous Postgres-16 data volumes created 2026-11-07 → 2026-11-09 (check `docker volume inspect` for `CreatedAt`).

  **Keep** `coldmail-gomod`, `coldmail-gocache`, `coldmail-gobin` (`coldmail/tools/` uses them) and everything belonging to your other projects. Nine further dangling images I could not attribute to this project
  (`4e6e670bb069 a13c0b8bb0a9 11a1f0b604b1 26730869004e 0178a641fbb4 900f9c109f7a 5276a2323564 b868afa176bf b004b9c35c68`, one of them 2.6 GB) are yours to judge.
- **Exclude the `coldmail/` folder from Norton real-time scanning.**
- **Check the older `coldmail` tree that sits beside `coldmail-parent` for any unpushed commits or untracked work, then retire it.** `coldmail-parent` is the only working copy. (The Phase 0 build plan and diagram you attached had landed in that older tree and were copied across.)
- **Free space on `C:`** was 3.3 GB on 2026-11-13. Docker's disk lives on `D:` (in the `DockerWSL` folder of your applications directory), but Windows itself, and WSL's default swap and temp files, are on `C:`; keep several GB free.

## 7. A review and some leftovers only you can judge

- **CLAUDE.md status blocks (M2 and M3).** Both modules' `CLAUDE.md` Rule 8 says the file changes only by a deliberate, reviewed PR. In the 2026-11-13 docs unification the *status blocks* were
  rewritten (M3: the 2026-08-01 text said "Phases 2–8 are planned … not yet built", which had been false for months) and a dated note was appended in M2 (57 config keys; new ledger path). The **rules** were not
  touched. Read the two diffs (`git log -p -- CLAUDE.md`) and either accept them or revert.
- **Leftovers I did not delete because I could not tell what they are** (nothing on GitHub was deleted beyond the three merged branches you authorized):
  - `coldmail-send-managed/.claude/settings.local.json` — a local Claude Code settings file; harmless, not tracked.
  - `coldmail-send-managed/Docs/history/mailflow-worker (Sender Inspiration)/` — a reference codebase with its own nested `.git`, gitignored and not part of the repository (a fresh clone will not have it); `Docs/history/README.md` and `phase-build-record.md` cite it. Left in place; delete it if you no longer want the reference.
  - Folders named in the cleanup brief that **do not exist** on this disk: `Codmailling 2`, `Codmailling 3`, `Codmailling 3 - planning (pre-fork)` (so there is no zip of it) and `tmp_od`. `New folder (3)` was found in
    three unrelated places and none was touched — tell me which, if any, is yours.
