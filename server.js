const express = require('express');
  const path = require('path');
  const app = express();
  const CITIES = {
    'Warsaw':      'Europe/Warsaw',
    'London':      'Europe/London',
    'New York':    'America/New_York',
    'Los Angeles': 'America/Los_Angeles',
    'Moscow':      'Europe/Moscow',
    'Tokyo':       'Asia/Tokyo',
    'Beijing':     'Asia/Shanghai',
    'Sydney':      'Australia/Sydney',
  }; 

  app.use(express.static('public'));

  app.get('/health',  (req, res) => res.json({ status: 'ok' }));
  app.get('/version', (req, res) => res.json({ version: '1.0.2' }));
  app.get('/api/time', (req, res) => {
    const { city } = req.query;
    if (!city) return res.status(400).json({ error:
  'Missing city parameter' });
    const timezone = CITIES[city];
    if (!timezone) return res.status(404).json({ error:
  'City not found' });
    const time = new Date().toLocaleTimeString('pl-PL', {
  timeZone: timezone, hour12: false });
    res.json({ city, time, timezone });
  });

  if (require.main === module){
    app.listen(3000, () => console.log('Running on port 3000'));
  }
  
  module.exports = app;
