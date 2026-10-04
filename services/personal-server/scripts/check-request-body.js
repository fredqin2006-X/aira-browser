const { Readable } = require('stream');
const { readJson } = require('../src/http');

const title = '第二百十四章 人质';
const payload = Buffer.from(JSON.stringify({ title }), 'utf8');
const splitAt = payload.indexOf(Buffer.from(title, 'utf8')) + 4;

readJson(chunksAsRequest([payload.subarray(0, splitAt), payload.subarray(splitAt)]))
  .then((parsed) => {
    if (parsed.title !== title) {
      throw new Error(`split UTF-8 request was corrupted: ${JSON.stringify(parsed.title)}`);
    }
    console.log('Request body UTF-8 boundary check passed.');
  })
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

function chunksAsRequest(chunks) {
  const stream = new Readable({ read() {} });
  process.nextTick(() => {
    chunks.forEach((chunk) => stream.push(chunk));
    stream.push(null);
  });
  return stream;
}
