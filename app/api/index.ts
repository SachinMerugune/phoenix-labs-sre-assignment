import express, { Request, Response } from 'express';
import { Pool } from 'pg';
import dotenv from 'dotenv';
import client from 'prom-client';

dotenv.config();

const app = express();
app.use(express.json());

const port = process.env.PORT || 3000;

// PostgreSQL Connection Pool
const pool = new Pool({
  connectionString: process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/payments_db'
});

// Prometheus Metrics Registry & Default Metrics
const register = new client.Registry();
client.collectDefaultMetrics({ register });

// Custom HTTP Metrics
const httpRequestDurationMicroseconds = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.01, 0.05, 0.1, 0.2, 0.5, 1, 2, 5]
});

const httpRequestsTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code']
});

register.registerMetric(httpRequestDurationMicroseconds);
register.registerMetric(httpRequestsTotal);

// Middleware to track request duration and counts
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    const route = req.route ? req.route.path : req.path;
    const statusCode = res.statusCode.toString();
    httpRequestsTotal.inc({ method: req.method, route, status_code: statusCode });
    httpRequestDurationMicroseconds.observe({ method: req.method, route, status_code: statusCode }, duration);
  });
  next();
});

// Health check endpoint for Kubernetes
app.get('/health', async (_req: Request, res: Response) => {
  try {
    await pool.query('SELECT 1');
    res.status(200).json({ status: 'healthy', database: 'connected' });
  } catch (err) {
    res.status(503).json({ status: 'unhealthy', database: 'disconnected' });
  }
});

// Prometheus scraping endpoint
app.get('/metrics', async (_req: Request, res: Response) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// POST /payments - Create payment
app.post('/payments', async (req: Request, res: Response) => {
  const { amount, currency } = req.body;
  if (!amount) {
    return res.status(400).json({ error: 'amount is required' });
  }

  try {
    const result = await pool.query(
      'INSERT INTO payments (amount, currency, status) VALUES ($1, $2, $3) RETURNING *',
      [amount, currency || 'EUR', 'pending']
    );
    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('Error inserting payment:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /payments/:id - Fetch payment status
app.get('/payments/:id', async (req: Request, res: Response) => {
  const { id } = req.params;
  try {
    const result = await pool.query('SELECT * FROM payments WHERE id = $1', [id]);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Payment not found' });
    }
    res.status(200).json(result.rows[0]);
  } catch (error) {
    console.error('Error fetching payment:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.listen(port, () => {
  console.log(`Payment API listening on port ${port}`);
});
