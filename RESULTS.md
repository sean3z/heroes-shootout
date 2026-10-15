# Heroes shootout: crocket vs Rocket vs Spring Boot vs Fastify

> Published copy. Raw load-generator output, collapsed profiles and rig scripts referenced under "Files" are not included in this repo; charts, flamegraphs, the load mix and conformance script are.

## Run 2 (this document's primary numbers) — Thu Oct 15, 2026, 9:57–11:49 AM ET

**PR:** [#40](https://github.com/sean3z/crocket/pull/40) `workers-follow-pool` (commits through `9b07ff9`). **Not merged.** CI green: `check` + `libpqxx-8`.

**Rig:** same as run 1 (3 × DigitalOcean c-4 in nyc1, VPC `crocket-bench-nyc1`, Postgres 16 on its own droplet, wrk2 load generator). crocket built from the PR branch with **default** workers (no `CROCKET_WORKERS` override) — with pool size 16 that means **16 workers**. 3 repetitions per load level; tables show median (min–max). Fresh flamegraphs at 4k req/s and at saturation for all four apps. Droplets tore down at end; doctl shows 0 `heroes-bench` resources. About **1.9 h × 3 = 5.7 droplet-hours (~$0.71)**.

### Headline findings

1. **Max throughput (median of 3):** crocket **35.2k** req/s (35.2–35.6), Rocket 17.4k (17.4–17.5), Spring 8.4k (8.4–8.6), Fastify 6.6k (6.1–7.0). No errors on the max runs.
2. **CPU per request at max:** crocket **94 µs**, Fastify 157 µs, Rocket 204 µs, Spring 393 µs. crocket is about **2.2×** Rocket and **4.2×** Spring per core.
3. **PR #40 fixed the default-worker footgun without a light-load cost:** at 4,000 req/s, crocket with the new default (16 workers) uses **122 µs/req**, against **119 µs** on main with the old default of 4. Max throughput with the new defaults is **35k**, against run 1's 11k when defaults left workers at 4.
4. **Tail latency at 4,000 req/s:** crocket p99 **2.55 ms**, Rocket 3.03, Spring 3.11, Fastify 8.21.
5. **Memory:** crocket 13 / 21 MB (idle / peak), Rocket 11 / 22, Fastify 87 / 216, Spring 225 / 471.
6. **Cold start:** Rocket 154 ms, crocket 324 ms, Fastify 560 ms, Spring 4.8 s.

### Where crocket still loses / caveats
- **Cold start** still about 2× Rocket.
- **One flaky mid-ramp sample:** crocket `ramp_0.5` rep 3 returned 128 non-2xx and multi-second latencies while the other two reps at the same rate were clean (p99 3.2–5.0 ms). Medians still include that outlier; treat the 0.5× p99 range as noisy. No matching failures at 0.7× or above on the other reps.
- **Postgres still near the ceiling** for crocket (66% of a c-4 at max). The gap to the others is if anything understated.
- **Three incomplete ramp steps** (rocket 1.15_r1, spring 1.0_r2, fastify 1.0_r2) lost their SSH session mid-step (box egress); those lines were dropped. The other 2 reps for each level remain.
- Flamegraph caveats from run 1 still apply (libc without frame pointers; Spring kernel share estimated from syscall leaves).

### Setup deltas vs run 1
- crocket: PR #40, **no** `CROCKET_WORKERS` override (defaults follow pool → 16).
- crocket-main (light-load only): main `36eaa12` binary, also no override (4 workers).
- Fastify-cluster and crocket-w4 were not re-run.
- 3 reps per level; user/sys CPU split recorded in every mon sample.

## Max throughput (3 × 30 s at an unreachable rate; median, min–max in parentheses)

| App | Max req/s | App CPU cores | CPU µs/req | req/s per core | kernel share of app CPU | Host CPU % | Postgres CPU % | Peak RSS MB | Errors |
|---|---|---|---|---|---|---|---|---|---|
| crocket | 35,221 (35,209–35,610) | 3.33 (3.32–3.34) | 94 (93–95) | 10,593 (10,532–10,736) | 57 (57–58)% | 93 (92–94) | 66 (65–67) | 20.5 | 0 |
| rocket | 17,444 (17,355–17,523) | 3.56 (3.55–3.56) | 204 (203–205) | 4,912 (4,870–4,929) | 40 (40–41)% | 97 (97–97) | 63 (62–64) | 21.1 | 0 |
| spring | 8,413 (8,398–8,627) | 3.33 (3.30–3.36) | 393 (386–399) | 2,542 (2,506–2,589) | 37 (37–38)% | 98 (97–99) | 17 (16–17) | 400.4 | 0 |
| fastify | 6,626 (6,143–7,034) | 1.04 (1.04–1.05) | 157 (148–170) | 6,353 (5,873–6,744) | 21 (19–22)% | 30 (30–30) | 15 (14–16) | 214.0 | 0 |

## Cold start and memory

| App | Cold start to first 200, ms: median (min–max), n=3 | Startup RSS MB | Idle RSS MB | Peak RSS under load MB |
|---|---|---|---|---|
| crocket | 324 (319–343) | 13.0 | 12.9 | 21.3 |
| rocket | 154 (144–163) | 11.2 | 11.2 | 21.6 |
| spring | 4776 (4711–4789) | 225.1 | 217.2 | 471.2 |
| fastify | 560 (555–568) | 87.3 | 86.9 | 215.5 |

## Load ramp: wrk2 constant rate, 3 × 30 s per level (median, min–max)

| App | Level (× own max) | Target req/s | Achieved req/s | p50 ms | p99 ms | p99.9 ms | Errors | App CPU cores | Postgres CPU % |
|---|---|---|---|---|---|---|---|---|---|
| crocket | ramp_0.25 | 8,805 | 8,715 (8,680–8,784) | 1.42 (1.40–1.48) | 2.72 (2.70–2.75) | 3.15 (3.13–3.17) | 0 | 1.01 (1.01–1.02) | 21 (20–21) |
| crocket | ramp_0.5 | 17,610 | 17,565 (16,932–17,565) | 1.57 (1.55–6258.69) | 4997.12 (3.25–11149.31) | 6897.66 (33.89–11444.22) | 128 | 1.88 (1.64–1.91) | 49 (40–51) |
| crocket | ramp_0.7 | 24,654 | 24,590 (24,590–24,591) | 1.70 (1.69–1.76) | 3.84 (3.67–3.92) | 6.16 (4.61–6.41) | 0 | 2.54 (2.54–2.58) | 49 (49–50) |
| crocket | ramp_0.85 | 29,937 | 29,629 (29,627–29,629) | 1.84 (1.82–1.86) | 6.17 (5.32–6.28) | 14.65 (10.07–16.82) | 0 | 3.04 (3.02–3.05) | 56 (55–58) |
| crocket | ramp_1.0 | 35,220 | 34,694 (34,517–34,718) | 233.73 (76.48–292.10) | 1008.13 (576.51–1069.06) | 1087.49 (646.65–1131.52) | 0 | 3.31 (3.28–3.32) | 68 (68–69) |
| crocket | ramp_1.15 | 40,503 | 34,662 (34,547–34,882) | 2801.66 (2789.38–2918.40) | 4460.54 (4411.39–5771.26) | 4689.92 (4542.46–6037.50) | 0 | 3.32 (3.30–3.37) | 68 (67–69) |
| crocket | common | 4,000 | 3,992 (3,992–3,992) | 1.39 (1.37–1.47) | 2.55 (2.54–2.66) | 2.83 (2.83–2.98) | 0 | 0.49 (0.48–0.70) | 9 (8–10) |
| crocket | saturation | 52,830 | 34,207 (28,839–34,600) | 7127.04 (6828.03–9428.99) | 11354.11 (10813.44–14860.29) | 11599.87 (11206.66–15458.30) | 0 | 3.35 (3.25–3.45) | 69 (55–70) |
| rocket | ramp_0.25 | 4,361 | 4,317 (4,283–4,351) | 1.78 (1.66–2.02) | 3.41 (2.95–4.13) | 4.18 (3.32–5.37) | 0 | 0.95 (0.93–0.97) | 17 (16–18) |
| rocket | ramp_0.5 | 8,722 | 8,701 (8,633–8,701) | 1.76 (1.74–1.83) | 3.19 (3.15–3.66) | 4.12 (3.94–4.58) | 0 | 1.88 (1.87–1.88) | 32 (29–34) |
| rocket | ramp_0.7 | 12,210 | 12,180 (12,085–12,180) | 1.81 (1.79–1.97) | 3.62 (3.62–4.28) | 5.17 (4.92–6.08) | 0 | 2.55 (2.55–2.56) | 41 (40–47) |
| rocket | ramp_0.85 | 14,827 | 14,675 (14,673–14,758) | 2.09 (2.05–3.39) | 10.26 (7.72–18.88) | 19.95 (13.58–34.05) | 0 | 3.04 (3.03–3.06) | 54 (53–56) |
| rocket | ramp_1.0 | 17,444 | 17,234 (17,165–17,255) | 18.98 (10.05–110.78) | 70.59 (57.85–228.61) | 88.19 (77.76–279.55) | 0 | 3.54 (3.54–3.54) | 62 (62–63) |
| rocket | ramp_1.15 | 20,060 | 17,396 (17,379–17,414) | 2533.38 (2410.49–2656.26) | 3782.65 (3674.11–3891.20) | 3881.98 (3741.70–4022.27) | 0 | 3.55 (3.54–3.55) | 63 (63–64) |
| rocket | common | 4,000 | 3,992 (3,962–3,992) | 1.73 (1.64–1.75) | 3.03 (3.00–3.38) | 3.69 (3.41–4.29) | 0 | 0.87 (0.85–1.11) | 17 (14–17) |
| rocket | saturation | 26,166 | 17,368 (15,801–17,541) | 7004.16 (6627.33–7626.75) | 10616.83 (10174.46–12222.46) | 10698.75 (10264.58–12378.11) | 0 | 3.53 (3.40–3.56) | 62 (54–63) |
| spring | ramp_0.25 | 2,103 | 2,081 (2,081–2,099) | 1.74 (1.59–1.78) | 4.16 (2.83–4.16) | 5.84 (3.67–6.21) | 0 | 0.92 (0.91–0.93) | 4 (3–4) |
| spring | ramp_0.5 | 4,206 | 4,197 (4,164–4,197) | 1.66 (1.65–1.77) | 3.18 (3.10–4.12) | 4.54 (4.29–6.14) | 0 | 1.69 (1.68–1.71) | 10 (6–10) |
| spring | ramp_0.7 | 5,888 | 5,874 (5,874–5,874) | 1.68 (1.68–1.68) | 3.44 (3.37–3.44) | 5.91 (5.70–6.45) | 0 | 2.33 (2.33–2.35) | 11 (8–16) |
| spring | ramp_0.85 | 7,150 | 7,133 (7,022–7,133) | 1.75 (1.75–3.66) | 5.29 (4.32–10.81) | 14.21 (7.98–18.21) | 0 | 2.75 (2.72–2.75) | 9 (7–17) |
| spring | ramp_1.0 | 8,412 | 7,670 (7,034–8,305) | 339.42 (4.54–674.30) | 2750.98 (238.59–5263.36) | 3326.85 (448.25–6205.44) | 0 | 3.31 (3.23–3.40) | 17 (16–18) |
| spring | ramp_1.15 | 9,673 | 8,053 (7,989–8,065) | 3360.77 (3233.79–3368.96) | 5644.29 (5480.45–5849.09) | 6184.96 (6098.94–6287.36) | 0 | 3.35 (3.34–3.36) | 18 (18–18) |
| spring | common | 4,000 | 3,992 (3,992–3,992) | 1.67 (1.67–1.68) | 3.11 (3.06–3.13) | 4.52 (4.15–4.62) | 0 | 1.80 (1.79–1.82) | 8 (5–10) |
| spring | saturation | 12,618 | 7,868 (7,665–7,949) | 8028.16 (7700.48–8404.99) | 12312.58 (12001.28–12713.98) | 12697.60 (12615.68–13262.85) | 0 | 3.34 (3.32–3.36) | 18 (15–18) |
| fastify | ramp_0.25 | 1,656 | 1,638 (1,638–1,638) | 1.76 (1.72–1.77) | 6.75 (6.52–6.76) | 7.86 (7.60–8.26) | 0 | 0.44 (0.43–0.44) | 3 (3–3) |
| fastify | ramp_0.5 | 3,313 | 3,306 (3,279–3,306) | 1.68 (1.63–2.40) | 3.55 (3.35–7.69) | 9.04 (5.11–12.64) | 0 | 0.88 (0.80–0.88) | 5 (5–7) |
| fastify | ramp_0.7 | 4,638 | 4,591 (4,590–4,628) | 2.95 (2.56–3.60) | 7.96 (7.85–9.99) | 16.89 (9.76–17.65) | 0 | 0.98 (0.93–1.03) | 10 (9–10) |
| fastify | ramp_0.85 | 5,632 | 5,607 (5,575–5,619) | 13.68 (2.77–101.57) | 63.90 (22.93–385.28) | 69.95 (25.10–390.40) | 0 | 1.04 (1.04–1.05) | 12 (12–12) |
| fastify | ramp_1.0 | 6,626 | 6,497 (6,474–6,521) | 52.69 (38.88–66.50) | 400.19 (190.08–610.30) | 407.93 (194.81–621.05) | 0 | 1.05 (1.04–1.05) | 15 (14–15) |
| fastify | ramp_1.15 | 7,619 | 6,208 (5,745–6,254) | 4206.59 (3696.64–4952.06) | 5246.98 (5021.69–7270.40) | 5308.41 (5070.85–7360.51) | 0 | 1.04 (1.04–1.04) | 13 (12–14) |
| fastify | common | 4,000 | 3,992 (3,962–3,992) | 2.36 (1.69–2.66) | 8.21 (3.57–9.21) | 10.52 (5.13–22.30) | 0 | 0.97 (0.90–1.04) | 8 (7–8) |
| fastify | saturation | 9,939 | 6,674 (6,122–6,851) | 6750.21 (6508.54–7999.49) | 10166.27 (9814.01–12099.58) | 10223.61 (9879.55–12230.66) | 0 | 1.04 (1.04–1.05) | 14 (12–15) |

## Common load, 4,000 req/s (3 reps; median, min–max)

| App | p50 ms | p99 ms | p99.9 ms | App CPU cores | CPU µs/req | RSS MB |
|---|---|---|---|---|---|---|
| crocket | 1.39 (1.37–1.47) | 2.55 (2.54–2.66) | 2.83 (2.83–2.98) | 0.49 (0.48–0.70) | 122 (121–175) | 21.2 |
| rocket | 1.73 (1.64–1.75) | 3.03 (3.00–3.38) | 3.69 (3.41–4.29) | 0.87 (0.85–1.11) | 219 (216–279) | 21.5 |
| spring | 1.67 (1.67–1.68) | 3.11 (3.06–3.13) | 4.52 (4.15–4.62) | 1.80 (1.79–1.82) | 450 (448–456) | 441.8 |
| fastify | 2.36 (1.69–2.66) | 8.21 (3.57–9.21) | 10.52 (5.13–22.30) | 0.97 (0.90–1.04) | 243 (228–260) | 214.2 |
| crocket-main (main 36eaa12, default 4 workers) | 1.38 (1.37–1.91) | 2.49 (2.48–5.00) | 2.73 (2.72–6.13) | 0.47 (0.45–0.48) | 119 (115–119) | 16.1 |

## Flamegraph buckets (% of on-CPU samples)

| Profile | handler | serialization | db_driver | framework | logging | metrics | runtime | kernel | other |
|---|---|---|---|---|---|---|---|---|---|
| crocket_common | 0.2 | 1.8 | 13.3 | 16.2 | 1.0 | 0.4 | 0.0 | 57.7 | 9.4 |
| crocket_saturation | 0.3 | 2.2 | 14.5 | 14.4 | 1.0 | 0.3 | 0.0 | 59.6 | 7.7 |
| fastify_common | 3.6 | 1.4 | 18.5 | 22.6 | 5.7 | 1.0 | 18.2 | 28.1 | 0.9 |
| fastify_saturation | 4.9 | 2.1 | 22.9 | 22.9 | 7.3 | 1.4 | 19.6 | 17.9 | 0.9 |
| rocket_common | 0.7 | 1.2 | 13.9 | 17.9 | 5.6 | 0.9 | 9.3 | 41.0 | 9.4 |
| rocket_saturation | 0.8 | 1.3 | 14.7 | 18.3 | 4.9 | 0.9 | 8.0 | 39.7 | 11.2 |
| spring_common | 0.0 | 1.1 | 2.9 | 35.3 | 2.4 | 4.2 | 30.5 | 23.0 | 0.5 |
| spring_saturation | 0.1 | 1.8 | 3.8 | 38.8 | 2.7 | 3.9 | 25.0 | 23.3 | 0.6 |

## Light-load CPU/request at 4,000 req/s: crocket before vs after PR #40

| Build | Workers | CPU µs/req (median of 3) | App CPU cores | Peak RSS MB |
|---|---|---|---|---|
| main 36eaa12 (before) | default = 4 | 119 | 0.47 | 16.1 |
| PR #40 (after) | default = max(4, cores, pool) = 16 | 122 | 0.49 | 21.2 |
| Run 1 context: main + `CROCKET_WORKERS=16` | 16 (override) | 179 (1 rep) | 0.71 | 20.6 |
| Run 1 context: crocket-w4 | 4 (override) | 121 (1 rep) | 0.48 | 16.4 |

Raising the default worker count to the pool size does **not** raise light-load CPU per request (122 vs 119 µs). The earlier 179 µs figure from run 1 was a noisier single sample on the same 16-worker build.

## Files (run 2)
- `raw/phaseA.jsonl`, `raw/phaseB.jsonl`, `raw/coldstart.jsonl`, `raw/idle.jsonl`, `raw/buckets.jsonl`, `raw/profiles/*.collapsed`, `raw/conformance_*.txt`
- `flamegraphs/*.svg` (this run)
- Run 1 data kept under `raw_run1/` and `flamegraphs_run1/`.

---

# Archive: Run 1 (single reps, crocket with CROCKET_WORKERS=16 override)

# Heroes shootout: crocket vs Rocket vs Spring Boot vs Fastify (raw measurement foundation)

Date: Thu Oct 15, 2026. Droplets were up 7:59–9:02 AM ET (3 × c-4, about 3.2 droplet-hours, roughly $0.40 at $0.125/h). Everything tagged `heroes-bench` was destroyed and confirmed with doctl: 0 droplets, and the SSH key was removed. Nothing was pushed to GitHub.

This is data only, not blog copy. All four apps serve the same API on the same Postgres and pass the same 15-check curl conformance script (`rig/conformance.sh`, results in `raw_run1/conformance_*.txt`).

## Headline findings (honest version)

1. **Max throughput on one 4-vCPU c-4 (read-heavy mix, HTTP/1.1, every production feature on):** crocket reached **31.3k req/s**, Rocket 15.0k, Fastify on 4 cluster workers 11.8k, Spring 8.2k, and single-process Fastify 5.8k. No run had any errors.
2. **CPU per request at saturation:** crocket used **96 µs**, Fastify 180 µs (single process), Rocket 218 µs and Spring 408 µs. That makes crocket about 2.3× Rocket and 4.2× Spring per core.
3. **crocket's own code is almost invisible in its profile.** About 59% of its CPU is in the kernel (58% stime from /proc agrees), and about 38% of its samples sit under libpq/libpqxx, kernel I/O included. Handler, JSON and logging together are about 3%. At this point the remaining cost is mostly the network and the Postgres protocol. Spring spends about 37% in framework code and about 26% in the JVM runtime (virtual-thread park and unpark, continuation freeze and thaw, and GC at 8.8%). Fastify spends about 21% in the V8 and event-loop runtime.
4. **Memory:** crocket idled at about 13 MB and peaked at 21 MB, the same as Rocket (11 and 22 MB). Fastify used 87 and 220 MB, Fastify cluster 392 and 857 MB, and Spring 237 and 445 MB.
5. **Cold start (container start to first 200 on GET /heroes/1):** Rocket took **165 ms**, crocket 356 ms, Fastify 598 ms and Spring 5.2 s.
6. **Tail latency at a common 4,000 req/s:** p99 was crocket 2.9 ms, Spring 3.1 ms, Rocket 4.4 ms, Fastify cluster 4.9 ms and single-process Fastify 14.6 ms. Spring with virtual threads keeps up with crocket at light load. It just burns about 2.4× the CPU (1.74 cores against 0.71).

### Where crocket loses or looks bad
- **Cold start:** Rocket starts in about half the time (165 ms against 356 ms). crocket's time looks like it goes to opening the pool up front, but I haven't profiled it.
- **Light-load efficiency:** at 4k req/s crocket used 179 µs of CPU per request, almost twice its 96 µs at saturation. The 16 worker threads wake up and spin on a small amount of work. With the default 4 workers (`crocket-w4`) it dropped to 121 µs. Rocket's equivalent figures are 278 µs and 218 µs.
- **The default worker count is a footgun with `Db&`.** On defaults (workers = cores = 4, pool 16), crocket only reached **11.1k req/s** with the CPU at 1.1 cores. Blocking libpq calls on 4 workers cap concurrency at 4 queries in flight. I set `CROCKET_WORKERS=16` to match the pool for the main runs. Spring's virtual threads and Rocket and Fastify's async I/O don't need that setting. Either the docs or the defaults should tie workers to `database.pool_size`.
- **crocket's max number partly depends on Postgres.** Postgres was at 74% CPU on its own c-4 and the server host at 88%. crocket is the only app that came close to the database's limit, so its true ceiling may be a little higher than 31k, and the gap to the others is probably understated rather than overstated.
- **libpqxx compatibility:** crocket at 36eaa12 doesn't compile against libpqxx 8.0 (pgdg's current package), because `pqxx::row_ref` can't convert to `const pqxx::row&` in db.hpp:395 and :537. I built it against libpqxx 7.10.0, the same version as `docker/toolchain.Dockerfile`. This needs a fix before users on newer distributions hit it.
- **Kernel share:** 58% of crocket's CPU goes to the kernel, mostly sendmsg/sendto, scheduling and epoll. More gains need fewer syscalls (batched writes to Postgres, pipelining, io_uring), not faster C++.

## Setup and methodology

**Apps:** each is in `./<app>` with a Dockerfile.
| App | Stack | DB access | Logging | Metrics | Request timeout |
|---|---|---|---|---|---|
| crocket | main **36eaa12**, GCC 16 C++26, RelWithDebInfo, `-fno-omit-frame-pointer` | `crocket::db`/`crocket::pg` (libpqxx 7.10.0 static, libpq 17), `Db&` param, plain struct | `Logger{}` JSON to stdout (async buffered writer) | `Metrics{}` `/metrics` | `CROCKET_REQUEST_TIMEOUT=10s` |
| rocket | Rocket 0.5.1, rustc 1.99, release + debuginfo + frame pointers | **rocket_db_pools 0.2 + diesel-async 0.4 (deadpool)**, the idiomatic async route in Rocket 0.5. This forces diesel 2.1. | tracing-subscriber JSON via tracing-appender non_blocking, one line per request from a fairing; Rocket's own logs off | rocket_prometheus 0.10 | Rocket has none built in, so a `tokio::time::timeout(10s)` wraps each query |
| spring | Spring Boot **3.5.16**, Java **25** (Temurin), **virtual threads on**, Tomcat | JdbcClient (JdbcTemplate underneath), Hikari | ECS structured JSON to console (Logback, synchronous) from a OncePerRequestFilter | Actuator + Micrometer Prometheus at `/metrics` | `spring.jdbc.template.query-timeout=10s`, Tomcat 10 s |
| fastify | Fastify 5.12, Node **24.22 LTS**, pg 8 (Pool, named prepared statements), JSON schema response serialization | node-postgres | pino (Fastify's built-in), one line per request | prom-client histogram + default metrics | `requestTimeout` 10 s + pg `statement_timeout` 10 s |
| fastify-cluster | the same app run as `node:cluster` with 4 workers (`cluster.js`) | pool 4 per worker, 16 in total | same | same, per worker | same |

- **Pool:** 16 connections everywhere, with min = max, so every pool is warm.
- **API:** GET /heroes (first 50 by id), GET/PUT/DELETE /heroes/:id and POST /heroes. Hero is {id, name, alias, power, mentor}.
- **Seed data:** Barry Allen/The Flash and the Robins (Dick Grayson, Jason Todd, Tim Drake, Damian Wayne), plus 995 filler rows (`db/init.sql`). The schema comes only from init.sql, and the database is reset before every app run.

**Rig:** DigitalOcean nyc1, VPC `crocket-bench-nyc1`, all traffic over private IPs, Ubuntu 24.04, kernel 6.8, Xeon Platinum 8280.
- **hb-srv** (c-4): the app runs in Docker with `--network host`. Logs go to stdout and Docker's json-file driver. That driver uses 0.1–0.8 cores, which is counted separately as dockerd/shim and isn't included in app CPU.
- **hb-db** (c-4): Postgres **16.15** in Docker with shared_buffers=2GB and synchronous_commit=off. I put it on a separate droplet so DB CPU doesn't contaminate app CPU or flamegraphs.
- **hb-lg** (c-4): wrk2 (giltene, HdrHistogram, corrected for coordinated omission), `-t4 -c128`, keep-alive HTTP/1.1. I used HTTP/1.1 for all four, since Rocket and Fastify don't serve h2c by default.

**Mix (`rig/mix.lua`):** 80% GET /heroes/{rand 1..1000}, 10% GET /heroes, 5% POST with a unique name, 5% PUT on ids 6..1000.

**Procedure per app:**
- **Phase A:** 3 cold starts, then idle RSS 10 s after start, a **60 s warmup at 20k req/s** (the same for every app, so JIT is fair) and a 30 s run at an unreachable rate to find the max.
- **Phase B:** a fresh start, a 60 s warmup, constant-rate steps at 25/50/70/85/100/115% of that app's own max (30 s each), then the common load and saturation.
  - **Common load:** 4,000 req/s, which is about 70% of the slowest app (single-process Fastify).
  - **Saturation:** 150% of max.
- **CPU and RSS:** sampled once a second from /proc for the app process and its children, plus the DB droplet's CPU.
- **Spring profiling:** the first async-profiler attempt failed because the library wasn't visible inside the container. I reran Spring's profiles (`raw_run1/phaseB_spring_prof.jsonl`) with the same warmup.

**Flamegraphs:** `flamegraphs/*.svg`, with the collapsed stacks in `raw_run1/profiles/`. Each is 20 s, taken during the common-load step and the saturation step.
- **crocket and Rocket:** `perf record -F 999 --call-graph fp`, Rust symbols demangled with rustfilt.
- **Node:** perf with `--perf-basic-prof --interpreted-frames-native-stack`.
- **Java:** async-profiler 4.1 with `-e cpu -i 1ms` and `-XX:+PreserveFramePointer`.

Caveats:
- libc and libstdc++ in the containers have no frame pointers or symbols. Those leaves with no parent context show up as "other": 8–11% for crocket and Rocket.
- async-profiler didn't capture kernel stacks inside the container. For Spring, kernel time is estimated from syscall leaf frames (write/read/epoll); its 23% is lower than the 38% stime from /proc.
- The 99/999 Hz sampling over 20 s gives about 6–20k samples per profile.

**Bucket rules (`analysis/buckets.py`):**
- Any kernel frame puts the sample in **kernel**, split into net, epoll/sched/futex and other.
- Otherwise, GC or JIT frames anywhere put it in **runtime**.
- Otherwise the script walks from leaf to root, skipping generic frames (libc, malloc, std::, java.lang basics, v8::internal helpers), and takes the first frame that matches logging, metrics, serialization, db_driver, handler, framework or runtime, in that order.
- crocket has no separate async runtime. Its h2o event loop and worker threads count as **framework**, which is why crocket's runtime shows 0%.
- Percentages are of profiled on-CPU time. The "µs per request" table multiplies them by measured CPU/request at max, so the apps can be compared in absolute terms.
- Bucket boundaries are judgment calls. For example, crocket's DB path *including* the kernel I/O beneath libpq is about 38% inclusive, against 14% exclusive.

## Max throughput (Phase A, 30 s, unbounded rate)

| App | Max req/s | App CPU (cores) | CPU µs/req | req/s per core | Host CPU % | Postgres droplet CPU % | dockerd/shim CPU (cores) | Peak RSS MB | Non-2xx/errors |
|---|---|---|---|---|---|---|---|---|---|
| crocket | 31,312 | 3.02 | 96 | 10,368 | 87.8 | 73.5 | 0.52 | 20.7 | 0 |
| rocket | 15,019 | 3.28 | 218 | 4,579 | 92.8 | 68.9 | 0.45 | 20.9 | 0 |
| spring | 8,156 | 3.33 | 408 | 2,449 | 98.7 | 20.3 | 0.78 | 443.8 | 0 |
| fastify | 5,777 | 1.04 | 180 | 5,555 | 28.1 | 15.1 | 0.07 | 218.9 | 0 |
| fastify-cluster | 11,777 | 3.63 | 308 | 3,244 | 95.1 | 29.2 | 0.48 | 774.5 | 0 |
| crocket-w4 | 11,073 | 1.12 | 101 | 9,887 | 38.6 | 27.3 | 0.2 | 16.1 | 0 |

## Cold start and memory

| App | Cold start to first 200 (median of n, ms) | n | Startup RSS MB | Idle RSS MB (after 10 s) | Peak RSS under load MB (ramp) | Image size |
|---|---|---|---|---|---|---|
| crocket | 356 | 4 | 13.2 | 13.3 | 20.7 | 182MB |
| rocket | 165 | 4 | 11.2 | 11.1 | 21.6 | 318MB |
| spring | 5180 | 5 | 227.7 | 237.1 | 445.4 | 555MB |
| fastify | 598 | 4 | 87.0 | 86.9 | 220.0 | 366MB |
| fastify-cluster | 981 | 4 | 392.3 | 392.5 | 857.0 | 366MB |
| crocket-w4 | 348 | 4 | 13.0 | 12.8 | 16.4 | 182MB |

## Load ramp (Phase B, wrk2 constant rate, 30 s/step, latencies corrected for coordinated omission)

| App | Step | Target req/s | Achieved | p50 ms | p99 ms | p99.9 ms | Errors | App CPU cores | RSS MB | Postgres CPU % |
|---|---|---|---|---|---|---|---|---|---|---|
| crocket | ramp_0.25 | 7,828 | 7,809 | 1.49 | 2.79 | 3.06 | 0 | 0.91 | 19.6 | 19.3 |
| crocket | ramp_0.5 | 15,656 | 15,616 | 1.56 | 3.16 | 3.83 | 0 | 1.7 | 19.7 | 54.9 |
| crocket | ramp_0.7 | 21,918 | 21,522 | 1.91 | 3.83 | 5.04 | 0 | 2.29 | 19.9 | 54.8 |
| crocket | ramp_0.85 | 26,615 | 26,340 | 1.88 | 4.24 | 6.61 | 0 | 2.67 | 20.1 | 57.9 |
| crocket | ramp_1.0 | 31,312 | 30,611 | 218.62 | 524.29 | 606.21 | 0 | 3.04 | 20.3 | 74.7 |
| crocket | ramp_1.15 | 36,009 | 31,119 | 2723.84 | 4231.17 | 4366.34 | 0 | 3.0 | 20.6 | 73.4 |
| crocket | common | 4,000 | 3,962 | 1.67 | 2.93 | 3.44 | 0 | 0.71 | 20.6 | 12.5 |
| crocket | saturation | 46,968 | 27,035 | 8691.71 | 13385.73 | 13615.10 | 0 | 3.28 | 20.7 | 63.6 |
| rocket | ramp_0.25 | 3,754 | 3,715 | 1.98 | 3.80 | 4.66 | 0 | 0.84 | 20.4 | 17.2 |
| rocket | ramp_0.5 | 7,509 | 7,433 | 2.00 | 3.85 | 4.94 | 0 | 1.68 | 20.5 | 34.2 |
| rocket | ramp_0.7 | 10,513 | 10,405 | 2.15 | 4.32 | 6.12 | 0 | 2.31 | 20.5 | 48.7 |
| rocket | ramp_0.85 | 12,765 | 12,532 | 3.30 | 203.52 | 231.42 | 0 | 2.7 | 20.8 | 57.6 |
| rocket | ramp_1.0 | 15,018 | 14,806 | 125.06 | 183.17 | 196.86 | 0 | 3.23 | 21.0 | 69.7 |
| rocket | ramp_1.15 | 17,271 | 15,030 | 2572.29 | 3780.61 | 3842.05 | 0 | 3.26 | 21.3 | 69.4 |
| rocket | common | 4,000 | 3,962 | 2.08 | 4.37 | 5.58 | 0 | 1.1 | 21.1 | 19.5 |
| rocket | saturation | 22,528 | 13,388 | 7651.33 | 12320.77 | 12435.45 | 0 | 3.16 | 21.6 | 61.5 |
| spring | ramp_0.25 | 2,039 | 2,036 | 1.69 | 2.84 | 3.75 | 0 | 0.91 | 404.1 | 4.4 |
| spring | ramp_0.5 | 4,078 | 4,069 | 1.73 | 3.23 | 5.01 | 0 | 1.78 | 404.6 | 8.7 |
| spring | ramp_0.7 | 5,709 | 5,696 | 1.87 | 3.80 | 8.17 | 0 | 2.35 | 405.0 | 13.2 |
| spring | ramp_0.85 | 6,932 | 6,916 | 1.89 | 6.25 | 13.87 | 0 | 2.8 | 405.4 | 18.3 |
| spring | ramp_1.0 | 8,156 | 8,113 | 3.08 | 84.80 | 167.68 | 0 | 3.24 | 405.7 | 17.9 |
| spring | ramp_1.15 | 9,379 | 8,173 | 2414.59 | 4280.32 | 5009.41 | 0 | 3.29 | 405.8 | 21.4 |
| spring | common | 4,000 | 3,992 | 1.71 | 3.12 | 3.94 | 0 | 1.74 | 406.0 | 10.9 |
| spring | saturation | 12,234 | 7,865 | 7630.85 | 11419.65 | 11862.01 | 0 | 3.15 | 406.1 | 24.5 |
| spring | common_prof | 4,000 | 3,992 | 1.69 | 3.17 | 4.43 | 0 | 1.83 | 440.7 | 8.7 |
| spring | saturation_prof | 12,234 | 7,865 | 7327.74 | 11689.98 | 12320.77 | 0 | 3.32 | 445.4 | 20.2 |
| fastify | ramp_0.25 | 1,444 | 1,428 | 1.83 | 6.33 | 7.39 | 0 | 0.38 | 218.2 | 3.8 |
| fastify | ramp_0.5 | 2,888 | 2,834 | 4.17 | 11.49 | 13.57 | 0 | 0.6 | 218.2 | 7.8 |
| fastify | ramp_0.7 | 4,044 | 4,004 | 2.88 | 8.64 | 12.13 | 0 | 0.9 | 218.1 | 10.1 |
| fastify | ramp_0.85 | 4,910 | 4,861 | 4.57 | 11.80 | 22.14 | 0 | 1.02 | 218.1 | 12.7 |
| fastify | ramp_1.0 | 5,777 | 5,737 | 142.85 | 201.73 | 206.21 | 0 | 1.04 | 219.1 | 12.8 |
| fastify | ramp_1.15 | 6,644 | 5,663 | 2914.30 | 4321.28 | 4378.62 | 0 | 1.04 | 219.3 | 13.2 |
| fastify | common | 4,000 | 3,990 | 2.34 | 14.62 | 18.03 | 0 | 1.05 | 219.6 | 8.9 |
| fastify | saturation | 8,666 | 6,028 | 6524.93 | 9371.65 | 9428.99 | 0 | 1.05 | 220.0 | 15.0 |
| fastify-cluster | ramp_0.25 | 2,944 | 2,915 | 1.79 | 4.73 | 6.33 | 0 | 1.11 | 700.5 | 9.5 |
| fastify-cluster | ramp_0.5 | 5,888 | 5,828 | 1.96 | 5.82 | 8.15 | 0 | 2.09 | 700.6 | 15.1 |
| fastify-cluster | ramp_0.7 | 8,244 | 8,224 | 2.07 | 10.02 | 20.72 | 0 | 3.03 | 698.6 | 16.0 |
| fastify-cluster | ramp_0.85 | 10,010 | 9,907 | 3.58 | 41.41 | 58.40 | 0 | 3.38 | 798.8 | 24.3 |
| fastify-cluster | ramp_1.0 | 11,777 | 11,135 | 253.18 | 3864.57 | 3919.87 | 0 | 3.6 | 855.6 | 28.2 |
| fastify-cluster | ramp_1.15 | 13,544 | 11,733 | 2562.05 | 6385.66 | 6635.52 | 0 | 3.6 | 856.3 | 29.8 |
| fastify-cluster | common | 4,000 | 3,961 | 1.80 | 4.93 | 6.55 | 0 | 1.45 | 857.0 | 8.9 |
| crocket-w4 | ramp_0.25 | 2,768 | 2,763 | 1.48 | 2.61 | 2.94 | 0 | 0.35 | 16.1 | 8.4 |
| crocket-w4 | ramp_0.5 | 5,536 | 5,434 | 2.59 | 6.30 | 7.00 | 0 | 0.61 | 16.1 | 13.1 |
| crocket-w4 | ramp_0.7 | 7,751 | 7,732 | 1.57 | 3.00 | 3.50 | 0 | 0.84 | 16.1 | 19.0 |
| crocket-w4 | ramp_0.85 | 9,412 | 9,389 | 1.64 | 3.16 | 4.21 | 0 | 0.98 | 16.1 | 25.1 |
| crocket-w4 | ramp_1.0 | 11,073 | 10,662 | 538.62 | 807.42 | 834.05 | 0 | 1.1 | 16.3 | 26.1 |
| crocket-w4 | ramp_1.15 | 12,734 | 10,719 | 2955.26 | 4407.30 | 4452.35 | 0 | 1.09 | 16.4 | 26.8 |
| crocket-w4 | common | 4,000 | 3,961 | 1.65 | 3.92 | 4.41 | 0 | 0.48 | 16.4 | 11.5 |

## Common load: 4,000 req/s for every app

| App | p50 ms | p99 ms | p99.9 ms | App CPU cores | CPU µs/req | RSS MB |
|---|---|---|---|---|---|---|
| crocket | 1.67 | 2.93 | 3.44 | 0.71 | 179 | 20.6 |
| rocket | 2.08 | 4.37 | 5.58 | 1.1 | 278 | 21.1 |
| spring | 1.71 | 3.12 | 3.94 | 1.74 | 436 | 406.0 |
| spring (profiled run) | 1.69 | 3.17 | 4.43 | 1.83 | 458 | 440.7 |
| fastify | 2.34 | 14.62 | 18.03 | 1.05 | 263 | 219.6 |
| fastify-cluster | 1.80 | 4.93 | 6.55 | 1.45 | 366 | 857.0 |
| crocket-w4 | 1.65 | 3.92 | 4.41 | 0.48 | 121 | 16.4 |

## User vs kernel CPU at saturation (/proc utime/stime, 20 s)

| App | user % | kernel % |
|---|---|---|
| crocket | 42 | 58 |
| rocket | 60 | 40 |
| spring | 62 | 38 |
| fastify | 71 | 29 |

## Flamegraph buckets (% of profiled on-CPU samples)

| Profile | handler | serialization | db_driver | framework | logging | metrics | runtime | kernel | other | kernel split | runtime split |
|---|---|---|---|---|---|---|---|---|---|---|---|
| crocket_common | 0.2 | 1.7 | 13.0 | 16.9 | 0.9 | 0.4 | 0.0 | 57.4 | 9.5 | other 10.6, net 27.3, epoll/sched/futex 19.1, syscall (kernel stack not captured) 0.4 |  |
| crocket_saturation | 0.2 | 2.2 | 14.0 | 15.1 | 0.9 | 0.3 | 0.0 | 59.3 | 8.1 | other 10.0, net 38.7, epoll/sched/futex 10.3, syscall (kernel stack not captured) 0.3 |  |
| fastify_common | 3.4 | 1.1 | 20.0 | 23.9 | 4.1 | 0.1 | 19.9 | 26.5 | 0.9 | net 17.6, other 4.7, syscall (kernel stack not captured) 0.3, epoll/sched/futex 3.9 | other(scheduler/event loop/async) 18.2, gc 1.7, jit 0.0 |
| fastify_saturation | 4.1 | 1.4 | 22.4 | 23.8 | 4.8 | 0.1 | 21.2 | 21.1 | 0.9 | epoll/sched/futex 1.7, syscall (kernel stack not captured) 0.2, net 14.3, other 4.9 | other(scheduler/event loop/async) 18.5, gc 2.6, jit 0.1 |
| rocket_common | 0.7 | 1.3 | 14.2 | 18.0 | 5.3 | 0.9 | 8.7 | 40.4 | 10.5 | net 22.5, epoll/sched/futex 11.0, other 6.6, syscall (kernel stack not captured) 0.2 | other(scheduler/event loop/async) 8.7 |
| rocket_saturation | 0.8 | 1.2 | 14.2 | 18.7 | 4.8 | 0.9 | 8.1 | 40.1 | 11.1 | other 6.3, net 28.0, epoll/sched/futex 5.6, syscall (kernel stack not captured) 0.2 | other(scheduler/event loop/async) 8.1 |
| spring_common | 0.1 | 1.6 | 2.9 | 36.3 | 2.6 | 4.5 | 29.4 | 22.0 | 0.7 | syscall (kernel stack not captured) 22.0 | other(scheduler/event loop/async) 22.5, jit 0.4, gc 6.5 |
| spring_saturation | 0.1 | 2.2 | 3.7 | 37.4 | 2.9 | 4.0 | 26.0 | 23.0 | 0.6 | syscall (kernel stack not captured) 23.0 | other(scheduler/event loop/async) 16.1, jit 1.2, gc 8.8 |

## Estimated CPU µs per request by bucket at saturation (bucket % × CPU µs/req at max)

| App | CPU µs/req | handler | serialization | db_driver | framework | logging | metrics | runtime | kernel | other |
|---|---|---|---|---|---|---|---|---|---|---|
| crocket | 96 | 0.2 | 2.1 | 13.5 | 14.6 | 0.9 | 0.3 | 0.0 | 57.2 | 7.8 |
| fastify | 180 | 7.4 | 2.5 | 40.3 | 42.8 | 8.6 | 0.2 | 38.2 | 38.0 | 1.6 |
| rocket | 218 | 1.7 | 2.6 | 31.0 | 40.8 | 10.5 | 2.0 | 17.7 | 87.6 | 24.2 |
| spring | 408 | 0.4 | 9.0 | 15.1 | 152.7 | 11.8 | 16.3 | 106.2 | 93.9 | 2.4 |

## Files
- `raw_run1/phaseA.jsonl`, `raw_run1/phaseB.jsonl`, `raw_run1/phaseB_spring_prof.jsonl`: one JSON line per step (wrk2 summary + app CPU/RSS + DB CPU). `raw_run1/wrk_<app>_<step>.txt` holds the full wrk2 output.
- `raw_run1/coldstart*.jsonl`, `raw_run1/idle.jsonl`, `raw_run1/user_sys_split.jsonl`, `raw_run1/conformance_*.txt`, `raw_run1/server_env.txt`
- `raw_run1/profiles/*.collapsed`, `raw_run1/buckets.jsonl`, `flamegraphs/*.svg`
- `rig/`: conformance.sh, mix.lua, srv_run.sh, mon.sh, dbmon.sh, srv_prof.sh, phaseA.sh, phaseB.sh, ustime.sh, cleanup.sh. `analysis/`: buckets.py, tables.md

## Not done or open
- **Single samples:** each step ran once and there's no repeat-run variance yet. Re-run before quoting exact ratios in a post.
- **Load generator:** one load generator. It was never saturated, since the apps' own hosts hit 88–99% CPU first.
- **h2c:** not tested in this shootout.
- **Postgres ceiling:** a bigger Postgres box would show crocket's real limit.
