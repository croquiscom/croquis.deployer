const express = require('express');
const http = require('http');

const app = express();

app.use((req, res, next) => {
  res.on('finish', () => {
    console.log(`[${new Date().toISOString()} at ${process.env.PM2_INSTANCE_ID}] ${req.method} ${req.url} finished`);
  });
  next();
});

app.get('/', (req, res) => {
  console.log(`[${new Date().toISOString()} at ${process.env.PM2_INSTANCE_ID}] process GET /`);
  if (req.query.wait) {
    setTimeout(() => {
      res.send(`Hello World! after ${req.query.wait}ms\n`);
    }, Number(req.query.wait));
  } else {
    res.send('Hello World!\n');
  }
});

const server = http.createServer(app);
server.listen(process.env.PORT || 3000, () => {
  console.log(`[${new Date().toISOString()} at ${process.env.PM2_INSTANCE_ID}] Started`);
});

let shutdowning = false;
function shutdown() {
  const worker_num = process.env.WORKER_NUM || process.env.PM2_INSTANCE_ID || 0;
  if (shutdowning) {
    return;
  }
  console.log(`[${new Date().toISOString()} at ${process.env.PM2_INSTANCE_ID}] Shutdown`);
  shutdowning = true;

  // 60초간 끝나지 않으면 강제 종료
  setTimeout(() => {
    console.log(`[${new Date().toISOString()} at ${process.env.PM2_INSTANCE_ID}] Terminated by force`);
    process.exit(0);
  }, 60 * 1000);

  server.close(() => {
    console.log(`[${new Date().toISOString()} at ${process.env.PM2_INSTANCE_ID}] Terminate`);
    process.exit(0);
  });
}

process.on('SIGHUP', shutdown);
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
