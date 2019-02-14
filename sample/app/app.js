const express = require('express');
const app = express();

app.get('/', (req, res) => {
  console.log(`[process ${process.env.PM2_INSTANCE_ID}] GET /`);
  res.send('Hello World!\n');
});

app.listen(process.env.PORT || 3000, () => {
  console.log('Example app listening on port 3000!');
});
