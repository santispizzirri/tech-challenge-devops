/**
 * Simple smoke test for deployment verification
 * Tests basic health and functionality
 * Run with: k6 run test/load/smoke-test.js
 */

import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  vus: 1,
  duration: '10s',
  thresholds: {
    http_req_failed: ['rate<0.1'],
  },
};

const BASE_URL = __ENV.SERVICE_URL || 'http://localhost:80';

export default function () {
  // Health check
  let response = http.get(`${BASE_URL}/health`);
  check(response, {
    'Health check passes': (r) => r.status === 200 && r.body.includes('healthy'),
  });

  sleep(1);

  // Version check
  response = http.get(`${BASE_URL}/version`);
  check(response, {
    'Version endpoint returns version': (r) => r.status === 200 && r.body.includes('version'),
  });

  sleep(1);

  // Root endpoint
  response = http.get(`${BASE_URL}/`);
  check(response, {
    'Root endpoint responds': (r) => r.status === 200,
  });
}
