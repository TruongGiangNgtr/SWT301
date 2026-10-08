# Local HTTP performance characterization

`date-time-checker.js` measures the real Razor Pages workflow: GET page → Check POST for 29/02/2000 → Clear POST. It extracts actual antiforgery tokens and uses the VU cookie jar. It checks returned messages and blank fields; no CSRF protection is disabled. Public targets and redirects are rejected.

Approved workload: local isolated server, **1 VU, 30 seconds, no acceptance thresholds**. Exact review: “Duyệt local 1 VU, 30 giây; chỉ đo, chưa đặt acceptance thresholds”. Configuration is `local-characterization.json`. The workload is a closed loop with no think time, three requests per successful iteration; results do not simulate concurrent real users or production.

## Run and export

Install a .NET 10 SDK, PowerShell 7 and k6. From repository root:

```powershell
dotnet restore SWT.slnx
dotnet build SWT.slnx -c Release --no-restore
pwsh tests/performance/run-local.ps1 -K6Path 'C:/tools/k6/k6.exe'
```

Replace the example k6 path with the actual executable. The verified local run used portable k6 v2.3.0, downloaded from its official release and verified against the release checksum. The wrapper starts its own Release server on an OS-assigned loopback port, waits for readiness, runs k6, and stops only that owned process tree. Server logging is reduced to Warning plus lifetime Information to limit console overhead; Development mode and local hardware remain part of the measurement environment.

Each run has a unique output directory beneath `TestResults/performance/` (or `-ResultsDirectory`): raw `metrics.json`, full `summary.json`, concise `measurements.json`, reviewed workload copy, k6 version, execution/server logs, and `run.json` with cleanup status. No usage report is sent by k6.

For a different reviewed local workload, provide `-WorkloadFile <json>`. VUs, duration and optional k6 thresholds come from that file. Direct JS execution requires explicit `BASE_URL`, `VUS`, `DURATION` and optional `THRESHOLDS_JSON`. Changing these values does not create a business requirement. Retain the actual review record and measurement context.

## Interpretation

Reports include HTTP request rate/count, per-workflow latency avg/min/median/max/p90/p95/p99, errors and functional checks. k6's HTTP duration excludes browser rendering and user interaction. Functional checks succeeding only establishes that the measured workflow behaved as asserted. With empty thresholds, there is **no performance acceptance verdict**.

NFR-003 specifies a result within one second after clicking Check. This characterization cannot certify it: browser measurement, target environment, workload and acceptance method remain undefined. Local throughput is not a capacity guarantee, SLA or production benchmark. Raw output collection and local machine activity also affect timings.

References: [k6 HTTP requests](https://grafana.com/docs/k6/latest/using-k6/http-requests/), [HTML forms](https://grafana.com/docs/k6/latest/examples/html-forms/), [custom summary](https://grafana.com/docs/k6/latest/results-output/end-of-test/custom-summary/).
