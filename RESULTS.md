# Heroes shootout: crocket vs Rocket vs Spring Boot vs Fastify

> Published copy. Raw load-generator output, collapsed profiles and rig scripts referenced under "Files" are not included in this repo; charts, flamegraphs, the load mix and conformance script are.

## Benchmark — Thu Oct 15, 2026, 9:57–11:49 AM ET

**crocket:** current main at commit `63317f2`, where the default worker count follows the database pool size. With pool size 16 that means **16 workers** (no `CROCKET_WORKERS` override). Matching workers to the pool matters here: blocking libpq calls with fewer workers than connections leave pool slots idle and cap how many queries can be in flight

**Rig:** 3 × DigitalOcean c-4 in nyc1 (VPC `crocket-bench-nyc1`), Postgres 16 on its own droplet, wrk2 load generator. 3 repetitions per load level; tables show median (min–max). Flamegraphs at 4k req/s and at saturation for all four apps. Droplets tore down at end; doctl shows 0 `heroes-bench` resources. About **1.9 h × 3 = 5.7 droplet-hours (~$0.71)**

### Headline findings

1. **Max throughput (median of 3):** crocket **35.2k** req/s (35.2–35.6), Rocket 17.4k (17.4–17.5), Spring 8.4k (8.4–8.6), Fastify 6.6k (6.1–7.0). No errors on the max runs
2. **CPU per request at max:** crocket **94 µs**, Fastify 157 µs, Rocket 204 µs, Spring 393 µs. crocket is about **2.2×** Rocket and **4.2×** Spring per core
3. **Workers follow the pool by default:** at 4,000 req/s, crocket with 16 workers (matching the pool) uses **122 µs/req**. Matching workers to the pool is what lets blocking `Db&` handlers use the full pool under load
4. **Tail latency at 4,000 req/s:** crocket p99 **2.55 ms**, Rocket 3.03, Spring 3.11, Fastify 8.21
5. **Memory:** crocket 13 / 21 MB (idle / peak), Rocket 11 / 22, Fastify 87 / 216, Spring 225 / 471
6. **Cold start:** Rocket 154 ms, crocket 324 ms, Fastify 560 ms, Spring 4.8 s

### Where crocket still loses / caveats
- **Cold start** still about 2× Rocket
- **One flaky mid-ramp sample:** crocket `ramp_0.5` rep 3 returned 128 non-2xx and multi-second latencies while the other two reps at the same rate were clean (p99 3.2–5.0 ms). Medians still include that outlier; treat the 0.5× p99 range as noisy. No matching failures at 0.7× or above on the other reps
- **Postgres still near the ceiling** for crocket (66% of a c-4 at max). The gap to the others is if anything understated
- **Three incomplete ramp steps** (rocket 1.15_r1, spring 1.0_r2, fastify 1.0_r2) lost their SSH session mid-step (box egress); those lines were dropped. The other 2 reps for each level remain
- crocket flamegraphs refreshed with statically linked libstdc++ on ubuntu:24.04 (glibc frame pointers + `libc6-dbg`); **other** at saturation 7.7%→3.3%. Residual libpq `[unknown]` frames folded in the published SVGs. Rocket/Spring/Fastify charts unchanged. Spring kernel share still estimated from syscall leaves

### Setup notes
- crocket: main `63317f2`, **no** `CROCKET_WORKERS` override (defaults follow pool → 16)
- Fastify ran as a single process (keeps per-request cost honest; max req/s therefore uses about one core)
- 3 reps per level; user/sys CPU split recorded in every mon sample

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

## Flamegraph buckets (% of on-CPU samples)

| Profile | handler | serialization | db_driver | framework | logging | metrics | runtime | kernel | other |
|---|---|---|---|---|---|---|---|---|---|
| crocket_common | 0.2 | 2.3 | 12.8 | 16.8 | 0.9 | 0.3 | 0.0 | 62.7 | 4.1 |
| crocket_saturation | 0.2 | 3.0 | 14.8 | 15.6 | 0.9 | 0.3 | 0.0 | 61.8 | 3.3 |
| fastify_common | 3.6 | 1.4 | 18.5 | 22.6 | 5.7 | 1.0 | 18.2 | 28.1 | 0.9 |
| fastify_saturation | 4.9 | 2.1 | 22.9 | 22.9 | 7.3 | 1.4 | 19.6 | 17.9 | 0.9 |
| rocket_common | 0.7 | 1.2 | 13.9 | 17.9 | 5.6 | 0.9 | 9.3 | 41.0 | 9.4 |
| rocket_saturation | 0.8 | 1.3 | 14.7 | 18.3 | 4.9 | 0.9 | 8.0 | 39.7 | 11.2 |
| spring_common | 0.0 | 1.1 | 2.9 | 35.3 | 2.4 | 4.2 | 30.5 | 23.0 | 0.5 |
| spring_saturation | 0.1 | 1.8 | 3.8 | 38.8 | 2.7 | 3.9 | 25.0 | 23.3 | 0.6 |

## Files
- Charts and flamegraphs in this repo: `charts/*.png`, `flamegraphs/*.svg`
- Load mix and conformance: `load/mix.lua`, `load/conformance.sh`, `init.sql`
- Raw load-generator output and collapsed profiles are not published here
