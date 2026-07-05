const express = require('express');
const twilio = require('twilio');
const Anthropic = require('@anthropic-ai/sdk');

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
app.use(express.urlencoded({ extended: false }));
app.use(express.json());

app.get('/health',  (req, res) => res.json({ status: 'ok' }));
app.get('/api/config', (req, res) => {
  res.json({ vapiPublicKey: process.env.VAPI_PUBLIC_KEY });
});
app.get('/version', (req, res) => res.json({ version: '1.0.0' }));
app.get('/api/time', (req, res) => {
  const { city } = req.query;
  if (!city) return res.status(400).json({ error: 'Missing city parameter' });
  const timezone = CITIES[city];
  if (!timezone) return res.status(404).json({ error: 'City not found' });
  const time = new Date().toLocaleTimeString('pl-PL', { timeZone: timezone, hour12: false });
  res.json({ city, time, timezone });
});

const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
const TWILIO_PHONE = process.env.TWILIO_PHONE || 'whatsapp:+14155238886';

const tools = [{
  name: 'get_time',
  description: 'Zwraca aktualny czas w podanym mieście',
  input_schema: {
    type: 'object',
    properties: {
      city: { type: 'string', description: 'Nazwa miasta: Warsaw, London, New York, Los Angeles, Moscow, Tokyo, Beijing, Sydney' }
    },
    required: ['city']
  }
}];

async function askAgent(userMessage) {
  const messages = [{ role: 'user', content: userMessage }];
  while (true) {
    const response = await anthropic.messages.create({
      model: 'claude-haiku-4-5-20251001',
      max_tokens: 512,
      system: 'Jesteś pomocnym asystentem który sprawdza czas na świecie. Odpowiadaj krótko po polsku. Dostępne miasta: Warsaw, London, New York, Los Angeles, Moscow, Tokyo, Beijing, Sydney.',
      tools,
      messages
    });
    if (response.stop_reason === 'tool_use') {
      const toolUse = response.content.find(b => b.type === 'tool_use');
      const city = toolUse.input.city;
      const tz = CITIES[city];
      const result = tz
        ? { city, time: new Date().toLocaleTimeString('pl-PL', { timeZone: tz, hour12: false }), timezone: tz }
        : { error: `Nieznane miasto: ${city}` };
      messages.push({ role: 'assistant', content: response.content });
      messages.push({ role: 'user', content: [{ type: 'tool_result', tool_use_id: toolUse.id, content: JSON.stringify(result) }] });
    } else {
      return response.content[0].text;
    }
  }
}

app.post('/api/whatsapp/initiate', async (req, res) => {
  const { phone } = req.body;
  const to = `whatsapp:+${phone.replace(/\D/g, '')}`;
  const client = twilio(process.env.TWILIO_ACCOUNT_SID, process.env.TWILIO_AUTH_TOKEN);
  try {
    await client.messages.create({
      from: TWILIO_PHONE,
      to,
      body: 'Hej! 👋 Jestem WorldClock Agent. Napisz nazwę miasta, a powiem Ci aktualny czas!\n\nDostępne miasta: Warsaw, London, New York, Los Angeles, Moscow, Tokyo, Beijing, Sydney'
    });
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post('/api/call', async (req, res) => {
  const { phone } = req.body;
  const customerNumber = `+${phone.replace(/\D/g, '')}`;
  try {
    const response = await fetch('https://api.vapi.ai/call/phone', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${process.env.VAPI_API_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        assistantId: '34bd5128-4664-440f-b974-81411b9f46f6',
        phoneNumberId: process.env.VAPI_PHONE_NUMBER_ID,
        customer: { number: customerNumber }
      })
    });
    const data = await response.json();
    if (response.ok) {
      res.json({ ok: true });
    } else {
      res.status(500).json({ error: data.message || 'Błąd połączenia' });
    }
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post('/webhook/whatsapp', async (req, res) => {
  const reply = await askAgent(req.body.Body);
  const twiml = new twilio.twiml.MessagingResponse();
  twiml.message(reply);
  res.type('text/xml').send(twiml.toString());
});

if (require.main === module) {
  app.listen(3000, () => console.log('Running on port 3000'));
}

module.exports = app;
