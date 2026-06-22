const request = require('supertest');
const app = require('../server');

describe('GET /health', () => {
  it('returns status ok', async () => {
    const res = await request(app).get('/health');
    expect(res.statusCode).toBe(200);
    expect(res.body).toEqual({ status: 'ok' });
  });
});

describe('GET /version', () => {
  it('returns version string', async () => {
    const res = await request(app).get('/version');
    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('version');
  });
});

describe('GET /api/time', () => {
  it('returns time for valid city', async () => {
    const res = await request(app).get('/api/time?city=Warsaw');
    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('city', 'Warsaw');
    expect(res.body).toHaveProperty('time');
    expect(res.body).toHaveProperty('timezone', 'Europe/Warsaw');
  });

  it('returns 400 when city param is missing', async () => {
    const res = await request(app).get('/api/time');
    expect(res.statusCode).toBe(400);
  });

  it('returns 404 for unknown city', async () => {
    const res = await request(app).get('/api/time?city=Atlantis');
    expect(res.statusCode).toBe(404);
  });
});
