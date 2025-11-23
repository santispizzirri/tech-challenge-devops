/**
 * Load test script for Canary deployment
 * Tests traffic distribution and monitors version responses
 * Run with: k6 run test/load/canary-test.js
 */

import http from 'k6/http';
import { check, sleep, group } from 'k6';

export const options = {
  stages: [
    { duration: '15s', target: 10 },  // Ramp up to 10 VUs
    { duration: '60s', target: 20 },  // Ramp up to 20 VUs
    { duration: '30s', target: 10 },  // Ramp down to 10 VUs
    { duration: '15s', target: 0 },   // Scale down to 0 VUs
  ],
  thresholds: {
    http_req_duration: ['p(95)<500', 'p(99)<1000'],
    http_req_failed: ['rate<0.1'],
  },
};

const BASE_URL = __ENV.SERVICE_URL || 'http://localhost:80';

// Track version distribution
const versionCounts = {};

export default function () {
  group('Canary Service Tests', function () {
    // Test version endpoint and track version distribution
    let response = http.get(`${BASE_URL}/version`);
    check(response, {
      'version status is 200': (r) => r.status === 200,
    });

    if (response.status === 200) {
      try {
        const body = JSON.parse(response.body);
        const version = body.version || 'unknown';
        versionCounts[version] = (versionCounts[version] || 0) + 1;
      } catch (e) {
        // Ignore parse errors
      }
    }

    sleep(0.3);

    // Test root endpoint
    response = http.get(`${BASE_URL}/`);
    check(response, {
      'root status is 200': (r) => r.status === 200,
      'root response is JSON': (r) => r.headers['Content-Type'].includes('application/json'),
    });

    sleep(0.3);

    // Test health endpoint
    response = http.get(`${BASE_URL}/health`);
    check(response, {
      'health status is 200': (r) => r.status === 200,
      'health is healthy': (r) => r.body.includes('healthy'),
    });

    sleep(0.5);

    // Test info endpoint
    response = http.get(`${BASE_URL}/api/info`);
    check(response, {
      'info status is 200': (r) => r.status === 200,
    });

    sleep(0.8);
  });
}

export function teardown() {
  console.log('=== Traffic Distribution Summary ===');
  let total = 0;
  for (const version in versionCounts) {
    total += versionCounts[version];
  }
  for (const version in versionCounts) {
    const percentage = ((versionCounts[version] / total) * 100).toFixed(2);
    console.log(`Version ${version}: ${versionCounts[version]} requests (${percentage}%)`);
  }
}
