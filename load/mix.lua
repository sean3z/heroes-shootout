-- Read-heavy Heroes mix: 80% GET /heroes/{id}, 10% GET /heroes, 5% POST, 5% PUT.
-- ids 6..1000 for PUT so the seed heroes (1..5) are never rewritten.
local counter, tid = 0, 0
local threads = {}
function setup(thread) tid = tid + 1; thread:set("tid", tid); table.insert(threads, thread) end
function init(args) math.randomseed(os.time() * 1000 + tid); counter = 0 end
local hdr = { ["Content-Type"] = "application/json" }
function request()
  local r = math.random(100)
  if r <= 80 then
    return wrk.format("GET", "/heroes/" .. math.random(1, 1000))
  elseif r <= 90 then
    return wrk.format("GET", "/heroes")
  elseif r <= 95 then
    counter = counter + 1
    local b = string.format('{"name":"Recruit %d-%d-%d","alias":"Robin","power":"Acrobatics","mentor":"Bruce Wayne"}', tid, counter, math.random(1e9))
    return wrk.format("POST", "/heroes", hdr, b)
  else
    local id = math.random(6, 1000)
    local b = string.format('{"name":"Hero %d","alias":"Alias %d","power":"Power %d","mentor":null}', id, id, math.random(17))
    return wrk.format("PUT", "/heroes/" .. id, hdr, b)
  end
end
function done(summary, latency, requests)
  io.write(string.format("JSON {\"requests\":%d,\"duration_us\":%d,\"rps\":%.1f,\"errors_connect\":%d,\"errors_read\":%d,\"errors_write\":%d,\"errors_status\":%d,\"errors_timeout\":%d,\"p50_ms\":%.3f,\"p90_ms\":%.3f,\"p99_ms\":%.3f,\"p999_ms\":%.3f,\"max_ms\":%.3f}\n",
    summary.requests, summary.duration, summary.requests / summary.duration * 1e6,
    summary.errors.connect, summary.errors.read, summary.errors.write, summary.errors.status, summary.errors.timeout,
    latency:percentile(50)/1000, latency:percentile(90)/1000, latency:percentile(99)/1000, latency:percentile(99.9)/1000, latency.max/1000))
end
