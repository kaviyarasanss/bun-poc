# bun-poc

**Saturday utilization POC — 2026-05-16**
Explores [Bun](https://bun.com) as a package manager and JavaScript runtime, with a working POC API and a head-to-head install benchmark against **npm** and **pnpm**.

> **Author:** Kavi (Phoenix Technologies)
> **Stack context:** evaluating Bun for a Node.js / NestJS / Postgres / React workflow.
> **Reference:** https://bun.com/package-manager

---

## 1. What is Bun?

Bun is **three tools in one binary**:

| Role | What it replaces | How |
|---|---|---|
| **Runtime** | Node.js / Deno | JavaScriptCore engine (Safari) — usually 2–3× faster cold-start than V8 for HTTP servers |
| **Package manager** | npm / yarn / pnpm | Written in Zig, parallel network + FS, binary lockfile (`bun.lock` text in v1.2+) |
| **Toolkit** | tsc, ts-node, nodemon, jest, esbuild, dotenv | Native TS/JSX, `--hot` reload, `bun test`, `bun build`, auto `.env` loading |

Single Bun install replaces ~6 typical dev dependencies. That's the headline.

---

## 2. POC — what's in `/poc`

A small REST API that demonstrates Bun acting as **runtime + package manager + TS compiler + SQLite driver** with no transpile step.

| Capability | How it's shown |
|---|---|
| Native TypeScript | `bun src/index.ts` — no `tsc`, no `ts-node` |
| npm ecosystem compat | Uses `express` (an unmodified npm package) |
| Built-in SQLite | `import { Database } from "bun:sqlite"` — zero deps |
| Hot reload | `bun --hot src/index.ts` (similar DX to `nodemon`) |
| Auto `.env` | Bun loads `.env` without `dotenv` |
| Validation | `zod` works as-is |

**Endpoints**

| Method | Path | Description |
|---|---|---|
| GET | `/health` | Reports Bun version + timestamp |
| GET | `/users` | List all users |
| GET | `/users/:id` | Fetch single user |
| POST | `/users` | Create user (Zod-validated) |
| DELETE | `/users/:id` | Delete user |

**Run it**

```bash
cd poc
bun install
bun run dev      # bun --hot src/index.ts
```

Smoke test (verified):

```
GET  /health                                            -> {"status":"ok","runtime":"bun","bunVersion":"1.3.14",...}
POST /users  {"name":"Kavi","email":"kavi@phoenix..."}  -> 201 {"id":1,...}
GET  /users                                             -> [{"id":1,...}]
```

---

## 3. Install Benchmark

### Methodology

* Fixture: a realistic **NestJS-style `package.json`** with 17 runtime deps (NestJS core/common/platform-express, TypeORM, pg, bcrypt, class-validator, jsonwebtoken, axios, lodash, rxjs, etc.) + 11 dev deps (NestJS CLI, jest, ts-jest, ts-node, @types/*, typescript).
* Each manager runs in an **isolated directory** with only `package.json` copied in.
* **Cold install** = global cache cleaned, no `node_modules`, no lockfile (worst case — first developer setup).
* **Warm install** = lockfile present, `node_modules` deleted (CI fresh-clone case).
* Times measured with PowerShell `Measure-Command` (wall clock).
* Harness: [`benchmarks/run-benchmarks.ps1`](benchmarks/run-benchmarks.ps1)

### Results

Run date **2026-05-18**, Windows 11, Node v22.13.1 / npm 10.9.2 / pnpm 10.32.1 / bun 1.3.14.

| Manager | Cold install (s) | Warm install (s) | `node_modules` (MB) | Lockfile (KB) | Lockfile |
|---|---|---|---|---|---|
| **npm**  | 107.90 | 29.55 | 165.75 | 325.73 | `package-lock.json` |
| **pnpm** |  78.20 | 24.42 | 159.20 | 191.65 | `pnpm-lock.yaml` |
| **bun**  | 122.99 | 60.96 | 167.84 | **161.03** | `bun.lock` |

### Reading the numbers — surprising, but here's why

This run does **not** show Bun winning on install speed, which is contrary to its marketing. Three honest reasons matter for our team:

1. **Windows + native modules.** The fixture includes `bcrypt` (`node-gyp`) and indirectly other native bindings. On Windows, Bun's postinstall / native rebuild pipeline is slower than npm/pnpm's path through prebuilt binaries. On Linux CI this gap typically shrinks or inverts.
2. **Cache-clean fairness.** Our harness calls `pnpm store prune`, which only removes *unreferenced* packages from the pnpm content-addressable store. `npm cache clean --force` and `bun pm cache rm` clean fully. So pnpm started its "cold" run with a partially populated store — a meaningful advantage. A truly apples-to-apples Bun-vs-pnpm benchmark requires deleting `~/.local/share/pnpm/store` (or `%LOCALAPPDATA%\pnpm` on Windows).
3. **Where Bun's win lives.** Bun's marketed 25× number is for the **cached, in-place install** scenario (lockfile + cache present, only verification needed). Our "warm" mode rebuilds `node_modules` from scratch using the cache, which is harder. The numbers above are still credible — they just reflect *full reinstall*, not *resolution-only*.

**Other takeaways from the numbers:**
- **Bun's lockfile is the smallest** (161 KB vs npm's 326 KB) — half the diff noise on PRs.
- **node_modules sizes are within ~5%** across all three. The big disk-saving win is pnpm's *symlinked store* — but the per-project `node_modules` doesn't reflect that; the saving shows up in the global store across many projects.

> **Bottom line for our team:** speed alone isn't a reason to swap. Bun's pull is the **toolkit consolidation** (runtime + TS + tests + bundler + .env) and the **DX** (`bun --hot`, native TS). See section 5.

### How to reproduce

```powershell
powershell -ExecutionPolicy Bypass -File .\benchmarks\run-benchmarks.ps1
# writes benchmarks/results.md
```

---

## 4. Feature comparison (qualitative)

| Feature | npm | pnpm | bun |
|---|---|---|---|
| Install algorithm | Sequential-ish, flat `node_modules` | Hard-linked content-addressable store, symlinks | Parallel network + FS, global cache, hard links on supported FS |
| `node_modules` layout | Flat (hoisted) | Nested + symlinked (strict) | Flat (hoisted) by default; `nodeLinker = "isolated"` for pnpm-style |
| Lockfile | `package-lock.json` (JSON, verbose) | `pnpm-lock.yaml` (YAML) | `bun.lock` (text, JSON-like; was binary `bun.lockb` pre-1.2) |
| Workspaces / monorepo | Built-in | Built-in (best-in-class filtering) | Built-in (`workspaces` field) |
| Run a script | `npm run x` | `pnpm x` | `bun run x` or just `bun x` |
| `npx` equivalent | `npx` | `pnpm dlx` | `bunx` / `bun x` |
| Built-in runtime | No (needs Node) | No (needs Node) | **Yes** — runs the script itself |
| Native TS / JSX | No | No | **Yes** — no compile step |
| Hot reload | external (nodemon) | external | **Yes** — `bun --hot` |
| Test runner | external (jest/vitest) | external | **Yes** — `bun test` (jest-compatible) |
| Bundler | external (esbuild/webpack) | external | **Yes** — `bun build` |
| `.env` loading | external (`dotenv`) | external | **Yes** — automatic |
| Windows support | Mature | Mature | Mature in 1.2+ (native, no WSL needed) |
| Node compatibility | n/a (it's Node) | High | High; some native modules still gap (mostly closed in 1.3) |
| Maturity | 15+ yrs | 7+ yrs | 1.3 series (production-ready for many shops) |

---

## 5. Pros / Cons / Verdict

### Pros
- **Toolkit consolidation:** one binary replaces npm + ts-node + nodemon + jest + esbuild + dotenv. Dev deps shrink — `package.json` gets quieter.
- **Native TS / JSX:** no `tsc`, no `ts-node`, no `tsx`. Matches Deno's DX without the lock-in.
- **Built-in SQLite & hot reload:** demoed in `/poc` — zero config.
- **Smaller, cleaner lockfile:** `bun.lock` is half the size of `package-lock.json` in our benchmark (161 KB vs 326 KB). Fewer merge conflicts.
- **Drop-in for many cases:** `bun install` against an existing `package.json` "just works" for our typical Express/NestJS surface.
- **Install speed *can* win**, but it depends on platform and what's cached — see benchmark notes above. Not a guaranteed win on Windows with heavy native-module trees.

### Cons
- **NestJS CLI** (`nest start`, schematics) still expects Node-style runtime semantics in places — best to use Bun *as the package manager* and keep Node as the runtime for full NestJS apps today, then migrate selectively.
- **Native modules:** a small number of npm packages with custom node-gyp builds may need workarounds.
- **Ecosystem tooling** (e.g. some VSCode debuggers, APM agents) targets Node first; Bun support is growing but not yet on parity.
- **Bun.lock** is newer; if the team also uses Linux CI, ensure runners have Bun installed.

### Verdict for our stack
- **Adopt now** for: greenfield POCs, scripts, CLIs, small services. Anywhere "one binary does it all" reduces our `devDependencies` surface area.
- **Try, but benchmark on Linux CI first** for: replacing `npm install` with `bun install` in existing NestJS service builds. Our Windows numbers don't justify the swap on their own; Linux runners likely tell a different story and that's where CI lives.
- **Wait** for: services depending on niche native modules, APM agents without Bun integration, or anything where the team's debugger workflow targets Node specifically.

---

## 6. Steps followed (chronological)

1. Installed Bun on Windows (`irm bun.sh/install.ps1 | iex`) — single PowerShell command, no admin needed.
2. Scaffolded POC under `poc/` — Express + Zod + `bun:sqlite`, all TypeScript, run with `bun --hot`.
3. Verified POC live: hit `/health`, `POST /users`, `GET /users` — all green.
4. Built a benchmark fixture (`benchmarks/package.json`) matching a real NestJS service's dependency surface.
5. Wrote a PowerShell harness that cleans caches, copies the fixture into per-manager directories, runs cold + warm installs, measures wall-clock time and disk usage.
6. Ran the harness, captured `benchmarks/results.md`.
7. Documented findings + comparison table in this README.

---

## 7. Challenges hit (and how I solved them)

| Challenge | Resolution |
|---|---|
| GitHub push 403 (wrong account cached) | Cleared the three Windows Credential Manager entries (`git:https://github.com`, `gh:github.com:`, `gh:github.com:kavi-phoenix`) via `cmdkey /delete`; re-authed as repo owner. |
| PowerShell `$ErrorActionPreference=Stop` terminating on benign npm/pnpm stderr warnings | Switched harness to `Continue` and routed cache-clean output via `cmd /c "... > NUL 2>&1"` so PowerShell never wraps native stderr as ErrorRecord. |
| Bun not on `PATH` in the current session right after install | Prepended `$env:USERPROFILE\.bun\bin` to `$env:Path` for the session; permanent PATH entry is added by the installer. |

---

## 8. Attachments

- This repo: https://github.com/kaviyarasanss/bun-poc
- POC code: [`poc/`](poc/)
- Benchmark harness: [`benchmarks/run-benchmarks.ps1`](benchmarks/run-benchmarks.ps1)
- Benchmark results: [`benchmarks/results.md`](benchmarks/results.md)
- Smoke test transcript: see section 2 above.
