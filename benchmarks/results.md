# Install Benchmark Results

Run date: 2026-05-18 06:53:10
Host: ADMIN
Node: v22.13.1  |  npm: 10.9.2  |  pnpm: 10.32.1  |  bun: 1.3.14

| Manager | Cold install (s) | Warm install (s) | node_modules size (MB) | Lockfile size (KB) | Lockfile |
|---|---|---|---|---|---|
| npm | 107.9 | 29.55 | 165.75 | 325.73 | `package-lock.json` |
| pnpm | 78.2 | 24.42 | 159.2 | 191.65 | `pnpm-lock.yaml` |
| bun | 122.99 | 60.96 | 167.84 | 161.03 | `bun.lock` |

**Cold** = no cache, no lockfile, no node_modules. **Warm** = lockfile present, node_modules deleted (simulates CI / fresh clone with cached store).
