const express = require('express');
  const path = require('path');
  const app = express();

  app.use(express.static('public'));

  app.get('/health',  (req, res) => res.json({ status: 'ok' }));
  app.get('/version', (req, res) => res.json({ version: '1.0.0' }));

  app.listen(3000, () => console.log('Running on port 3000'));

  module.exports = app;
