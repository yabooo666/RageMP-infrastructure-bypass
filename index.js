const https = require('https');
const fs = require('fs');
const tls = require('tls');
const path = require('path');

const hosts = ['cdn.rgsvc.io', 'cdn-r2.rgsvc.io', 'cdn-emerg.rgsvc.io', 'cdn.jsdelivr.net'];
const contexts = Object.fromEntries(
  hosts.map(host => [
    host,
    {
      key: fs.readFileSync(`./certs/${host}.key`),
      cert: fs.readFileSync(`./certs/${host}.crt`),
    },
  ])
);
const secureContexts = Object.fromEntries(
  Object.entries(contexts).map(([host, context]) => [host, tls.createSecureContext(context)])
);

function stamp() {
  return new Date().toISOString();
}

const server = https.createServer(
  {
    ...contexts['cdn.rgsvc.io'],
    SNICallback: (servername, callback) => {
      console.log(`[${stamp()}] SNI: ${servername || '(none)'}`);
      const context = secureContexts[servername];
      if (!context) {
        console.log(`[${stamp()}] SNI fallback certificate: cdn.rgsvc.io`);
        callback(null, secureContexts['cdn.rgsvc.io']);
        return;
      }
      callback(null, context);
    },
  },
  (req, res) => {
    let body = '';

    req.on('data', chunk => { body += chunk.toString(); });

    req.on('end', () => {
      console.log(`\n[${stamp()}] ${req.method} ${req.url} (Host: ${req.headers.host})`);
      if (body) console.log('Body:', body);

      // --- cdn.rgsvc.io routes ---

      if (req.url === '/updater/prerelease/data.xml') {
        const xml = fs.readFileSync(path.join(__dirname, 'data.xml'));
        res.writeHead(200, {
          'Content-Type': 'application/xml',
          'Content-Length': xml.length,
        });
        res.end(xml);
        console.log(`[${stamp()}] Served data.xml (${xml.length} bytes)`);
        return;
      }

      if (req.url === '/master/cache4.bin') {
        const bin = fs.readFileSync(path.join(__dirname, 'cache4.bin'));
        res.writeHead(200, {
          'Content-Type': 'application/octet-stream',
          'Content-Length': bin.length,
        });
        res.end(bin);
        console.log(`[${stamp()}] Served cache4.bin (${bin.length} bytes)`);
        return;
      }

      // --- catch-all ---

      console.log(`[${stamp()}] UNHANDLED: ${req.method} ${req.url} (Host: ${req.headers.host})`);
      res.writeHead(200, { 'Content-Type': 'text/plain' });
      res.end('OK\n');
    });
  }
);

server.on('connection', socket => {
  console.log(`[${stamp()}] TCP connect from ${socket.remoteAddress}:${socket.remotePort}`);
});

server.on('secureConnection', socket => {
  console.log(
    `[${stamp()}] TLS established from ${socket.remoteAddress}:${socket.remotePort} protocol=${socket.getProtocol()} cipher=${JSON.stringify(socket.getCipher())}`
  );
});

server.on('tlsClientError', (err, socket) => {
  console.log(
    `[${stamp()}] TLS client error from ${socket.remoteAddress}:${socket.remotePort}: ${err.code || err.name} ${err.message}`
  );
});

server.on('clientError', (err, socket) => {
  console.log(
    `[${stamp()}] HTTP client error from ${socket.remoteAddress}:${socket.remotePort}: ${err.code || err.name} ${err.message}`
  );
});

server.listen(443, '127.0.0.1', () => {
  console.log(`HTTPS logger running at ${hosts.map(host => `https://${host}`).join(', ')}`);
});