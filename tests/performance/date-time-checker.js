import http from 'k6/http';
import { check } from 'k6';
import { Rate, Trend } from 'k6/metrics';

const baseUrl = (__ENV.BASE_URL || '').replace(/\/$/, '');
const localMatch = /^http:\/\/(127\.0\.0\.1|localhost|\[::1\]):(\d{1,5})$/.exec(baseUrl);
if (!localMatch || Number(localMatch[2]) < 1 || Number(localMatch[2]) > 65535) {
  throw new Error('BASE_URL must be an explicit loopback HTTP address and port; public targets are not approved.');
}
const virtualUsers = Number(__ENV.VUS);
if (!Number.isInteger(virtualUsers) || virtualUsers < 1 || !__ENV.DURATION) {
  throw new Error('Set approved VUS and DURATION explicitly before execution.');
}
const profile = __ENV.PROFILE || 'characterization';
const stages = JSON.parse(__ENV.STAGES_JSON || '[]');
if (!['characterization', 'load', 'stress'].includes(profile) || virtualUsers > 8) throw new Error('Only bounded local demo profiles, max 8 VUs.');
const thresholds = JSON.parse(__ENV.THRESHOLDS_JSON || '{}');
const getLatency = new Trend('page_get_latency', true);
const checkLatency = new Trend('check_post_latency', true);
const clearLatency = new Trend('clear_post_latency', true);
const workflowErrors = new Rate('workflow_errors');

export const options = {
  ...(profile === 'stress' ? { scenarios: { local_stress: { executor: 'ramping-vus',
    startVUs: 0, stages, gracefulRampDown: '5s', gracefulStop: '5s' } } }
    : { vus: virtualUsers, duration: __ENV.DURATION }),
  thresholds,
  maxRedirects: 0,
  summaryTrendStats: ['avg', 'min', 'med', 'max', 'p(90)', 'p(95)', 'p(99)', 'count'],
};

function tokenFrom(response) {
  return response.html().find('input[name="__RequestVerificationToken"]').first().attr('value');
}

export default function () {
  // k6 maintains the antiforgery cookie in this VU's cookie jar. No protection is disabled.
  const page = http.get(`${baseUrl}/`, { tags: { workflow: 'get' }, timeout: '5s' });
  getLatency.add(page.timings.duration);
  const getValid = check(page, {
    'GET page returns 200': (response) => response.status === 200,
    'GET contains Date Time Checker': (response) => response.body.includes('Date Time Checker'),
  });
  if (!getValid) { workflowErrors.add(true); return; }
  const checkToken = tokenFrom(page);
  if (!check(checkToken, { 'GET supplies antiforgery token': (value) => Boolean(value) })) {
    workflowErrors.add(true); return;
  }

  const checked = http.post(`${baseUrl}/`, {
    Day: '29', Month: '02', Year: '2000', action: 'check', __RequestVerificationToken: checkToken,
  }, { tags: { workflow: 'check' }, timeout: '5s' });
  checkLatency.add(checked.timings.duration);
  const checkValid = check(checked, {
    'Check POST returns 200': (response) => response.status === 200,
    'Check returns existing valid-date message': (response) =>
      response.body.includes('29/02/2000 is correct date time!'),
  });
  if (!checkValid) { workflowErrors.add(true); return; }
  const clearToken = tokenFrom(checked);
  if (!check(clearToken, { 'Check response supplies antiforgery token': (value) => Boolean(value) })) {
    workflowErrors.add(true); return;
  }

  const cleared = http.post(`${baseUrl}/`, {
    Day: '12', Month: '10', Year: '2000', action: 'clear', __RequestVerificationToken: clearToken,
  }, { tags: { workflow: 'clear' }, timeout: '5s' });
  clearLatency.add(cleared.timings.duration);
  const clearValid = check(cleared, {
    'Clear POST returns 200': (response) => response.status === 200,
    'Clear empties all fields': (response) => ['Day', 'Month', 'Year'].every((field) =>
      response.html().find(`input[name="${field}"]`).first().attr('value') === ''),
  });
  workflowErrors.add(!clearValid);
}

export function handleSummary(data) {
  const results = {
    interpretation: Object.keys(thresholds).length === 0
      ? 'CHARACTERIZATION_ONLY: no performance acceptance thresholds were approved.'
      : 'Configured thresholds apply only to HTTP metrics, not browser render time.',
    workload: { environment: 'loopback', profile, vus: virtualUsers, duration: __ENV.DURATION, stages,
      workflow: 'GET -> Check POST -> Clear POST', pacing: 'closed loop, no think time', thresholds },
    thresholdResults: Object.fromEntries(Object.entries(data.metrics).filter(([, metric]) => metric.thresholds).map(([name, metric]) => [name, metric.thresholds])),
    httpRequests: data.metrics.http_reqs?.values,
    httpErrors: data.metrics.http_req_failed?.values,
    workflowErrors: data.metrics.workflow_errors?.values,
    checks: data.metrics.checks?.values,
    getLatencyMs: data.metrics.page_get_latency?.values,
    checkLatencyMs: data.metrics.check_post_latency?.values,
    clearLatencyMs: data.metrics.clear_post_latency?.values,
    iterations: data.metrics.iterations?.values,
  };
  return {
    'summary.json': JSON.stringify(data, null, 2),
    'measurements.json': JSON.stringify(results, null, 2),
    stdout: `${JSON.stringify(results, null, 2)}\n`,
  };
}
