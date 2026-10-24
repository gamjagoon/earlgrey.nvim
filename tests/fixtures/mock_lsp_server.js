const fs = require('node:fs');

const logPath = process.argv[2];
let input = Buffer.alloc(0);

function send(message) {
  const body = Buffer.from(JSON.stringify(message));
  process.stdout.write(`Content-Length: ${body.length}\r\n\r\n`);
  process.stdout.write(body);
}

function handle(message) {
  if (message.method && logPath) fs.appendFileSync(logPath, `${message.method}\n`);
  if (message.method === 'exit') process.exit(0);
  if (!Object.prototype.hasOwnProperty.call(message, 'id')) return;

  let result = null;
  if (message.method === 'initialize') {
    result = {
      capabilities: {
        textDocumentSync: 1,
        hoverProvider: true,
        codeActionProvider: true,
      },
      serverInfo: { name: 'earlgrey-mock-lsp', version: '1' },
    };
  } else if (message.method === 'textDocument/codeAction') {
    result = [{ title: 'Mock code action', kind: 'quickfix' }];
  } else if (message.method === 'workspace/configuration') {
    result = [];
  } else if (message.method && message.method.startsWith('textDocument/')) {
    result = {};
  }

  send({ jsonrpc: '2.0', id: message.id, result });
}

process.stdin.on('data', (chunk) => {
  input = Buffer.concat([input, chunk]);
  while (true) {
    const separator = input.indexOf('\r\n\r\n');
    if (separator < 0) return;
    const headers = input.subarray(0, separator).toString('ascii');
    const match = headers.match(/Content-Length:\s*(\d+)/i);
    if (!match) process.exit(2);
    const bodyStart = separator + 4;
    const bodyLength = Number(match[1]);
    if (input.length < bodyStart + bodyLength) return;
    const body = input.subarray(bodyStart, bodyStart + bodyLength);
    input = input.subarray(bodyStart + bodyLength);
    handle(JSON.parse(body.toString('utf8')));
  }
});
