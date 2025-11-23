/**
 * Load test script for Blue/Green deployment
 * Tests traffic routing between blue and green deployments
 * Run with: k6 run test/load/blue-green-test.js
 */

import http from 'k6/http';
import { check, sleep, group } from 'k6';

export const options = {
  stages: [
    { duration: '10s', target: 5 },   // Ramp up to 5 VUs
    { duration: '30s', target: 10 },  // Stay at 10 VUs
    { duration: '10s', target: 5 },   // Ramp down to 5 VUs
    { duration: '10s', target: 0 },   // Scale down to 0 VUs
  ],
  thresholds: {
    http_req_duration: ['p(95)<500', 'p(99)<1000'], // 95% of requests complete within 500ms
    http_req_failed: ['rate<0.1'], // Error rate less than 10%
  },
};

const BASE_URL = __ENV.SERVICE_URL || 'http://localhost:80';

export default function () {
  group('Blue/Green Service Tests', function () {
    // Test root endpoint
    let response = http.get(`${BASE_URL}/`);
    check(response, {
      'root status is 200': (r) => r.status === 200,
      'root has version': (r) => r.body.includes('version'),
    });

    sleep(0.5);

    // Test version endpoint
    response = http.get(`${BASE_URL}/version`);
    check(response, {
      'version status is 200': (r) => r.status === 200,
      'version response has version field': (r) => r.body.includes('version'),
    });

    sleep(0.5);

    // Test health endpoint
    response = http.get(`${BASE_URL}/health`);
    check(response, {
      'health status is 200': (r) => r.status === 200,
      'health status is healthy': (r) => r.body.includes('healthy'),
    });

    sleep(0.5);

    // Test info endpoint
    response = http.get(`${BASE_URL}/api/info`);
    check(response, {
      'info status is 200': (r) => r.status === 200,
      'info has service name': (r) => r.body.includes('service'),
    });

    sleep(1);
  });
}
