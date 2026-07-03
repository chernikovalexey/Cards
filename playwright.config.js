// Parity suite: run against production to pin behavior, against a local
// static server to verify the backend-less build behaves the same.
//
//   BASE_URL=https://twocubes.io npx playwright test   # pin production
//   npx playwright test                                # local static build
const { defineConfig } = require('@playwright/test');

const BASE_URL = process.env.BASE_URL || 'http://127.0.0.1:8080';
const isLocal = BASE_URL.includes('127.0.0.1') || BASE_URL.includes('localhost');

module.exports = defineConfig({
    testDir: 'tests',
    timeout: 90000,
    expect: { timeout: 30000 },
    retries: 1,
    use: {
        baseURL: BASE_URL,
        screenshot: 'only-on-failure',
    },
    // Firefox matters: Cloudflare's HTTP/3 + Firefox dropped subresource
    // loads (NS_ERROR_NET_HTTP3_PROTOCOL_ERROR), which broke the chapter
    // screen. Run the suite in both engines.
    projects: [
        { name: 'chromium', use: { browserName: 'chromium' } },
        { name: 'firefox', use: { browserName: 'firefox' } },
    ],
    webServer: isLocal ? {
        command: 'python3 -m http.server 8080 --bind 127.0.0.1',
        url: BASE_URL + '/web/cards.html',
        reuseExistingServer: true,
    } : undefined,
});
