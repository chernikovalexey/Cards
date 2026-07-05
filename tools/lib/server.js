'use strict';
const http = require('http');
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..', '..');
const MIME = {
    '.html': 'text/html', '.js': 'application/javascript', '.css': 'text/css',
    '.json': 'application/json', '.png': 'image/png', '.gif': 'image/gif',
    '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.svg': 'image/svg+xml',
    '.woff': 'font/woff', '.woff2': 'font/woff2', '.ttf': 'font/ttf', '.ico': 'image/x-icon',
};

function startServer() {
    const server = http.createServer((req, res) => {
        let urlPath = new URL(req.url, 'http://x').pathname;
        try { urlPath = decodeURIComponent(urlPath); } catch (e) { /* keep raw path */ }
        let file = path.normalize(path.join(ROOT, urlPath));
        if (!file.startsWith(ROOT)) { res.writeHead(403); res.end(); return; }
        fs.stat(file, (err, st) => {
            if (!err && st.isDirectory()) file = path.join(file, 'index.html');
            fs.readFile(file, (err2, data) => {
                if (err2) { res.writeHead(404); res.end('not found'); return; }
                res.writeHead(200, { 'Content-Type': MIME[path.extname(file)] || 'application/octet-stream' });
                res.end(data);
            });
        });
    });
    return new Promise((resolve) => {
        server.listen(0, '127.0.0.1', () => {
            resolve({ port: server.address().port, close: () => new Promise((r) => server.close(r)) });
        });
    });
}

module.exports = { startServer };
