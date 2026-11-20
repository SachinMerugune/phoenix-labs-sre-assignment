import express, { Request, Response } from 'express';
import { Pool } from 'pg';
import dotenv from 'dotenv';
import client from 'prom-client';

dotenv.config();

const port = process.env.PORT || 3001;
const pollIntervalMs = parseInt(process.env.POLL_INTERVAL_MS || '3000', 10);
let isStalled = process.env.STALL_WORKER === 'true';

const pool = new Pool({
  connectionString: process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/payments_db'
});

// Prometheus Registry
const register = new client.Registry();
client.collectDefaultMetrics({ register });

const paymentsProcessedTotal = new client.Counter({
  name: 'payments_processed_total',
  help: 'Total payments processed by worker',
  labelNames: ['status']
});

const paymentsPendingGauge = new client.Gauge({
  name: 'payments_pending_count',
  help: 'Current count of pending payments waiting in database'
});

const paymentsCompletedGauge = new client.Gauge({
  name: 'payments_completed_count',
  help: 'Total completed payments in database'
});

const paymentProcessingDuration = new client.Histogram({
  name: 'payment_processing_duration_seconds',
  help: 'Time taken to process payment and update CRM',
  buckets: [0.1, 0.5, 1, 2, 5, 10]
});

register.registerMetric(paymentsProcessedTotal);
register.registerMetric(paymentsPendingGauge);
register.registerMetric(paymentsCompletedGauge);
register.registerMetric(paymentProcessingDuration);

// Worker HTTP Server for health and metrics
const app = express();
app.use(express.json());

app.get('/health', async (_req: Request, res: Response) => {
  try {
    await pool.query('SELECT 1');
    res.status(200).json({ status: 'healthy', worker_stalled: isStalled });
  } catch (err) {
    res.status(503).json({ status: 'unhealthy', database: 'disconnected' });
  }
});

app.get('/metrics', async (_req: Request, res: Response) => {
  try {
    const pendingRes = await pool.query("SELECT COUNT(*) FROM payments WHERE status = 'pending'");
    paymentsPendingGauge.set(parseInt(pendingRes.rows[0].count, 10));

    const completedRes = await pool.query("SELECT COUNT(*) FROM payments WHERE status = 'completed'");
    paymentsCompletedGauge.set(parseInt(completedRes.rows[0].count, 10));
  } catch (err) {
    console.error('Error updating counts for metrics:', err);
  }
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// Endpoint to simulate worker stall for the take-home fault test
app.post('/fault/stall', (req: Request, res: Response) => {
  isStalled = true;
  console.warn('⚠️ FAULT INJECTED: Worker processing stalled via endpoint');
  res.status(200).json({ status: 'stalled', message: 'Worker is now stalled' });
});

app.post('/fault/resume', (req: Request, res: Response) => {
  isStalled = false;
  console.log('✅ RECOVERY: Worker processing resumed');
  res.status(200).json({ status: 'active', message: 'Worker resumed' });
});

// Background loop to consume pending payments
async function processPayments() {
  if (isStalled) {
    console.log('Worker is currently stalled (simulation active). Skipping processing cycle.');
    return;
  }

  const clientDb = await pool.connect();
  try {
    // Check pending count for gauge metric
    const countRes = await clientDb.query("SELECT COUNT(*) FROM payments WHERE status = 'pending'");
    paymentsPendingGauge.set(parseInt(countRes.rows[0].count, 10));

    // Atomically fetch and lock pending payments
    await clientDb.query('BEGIN');
    const selectQuery = `
      SELECT id, amount, currency, created_at 
      FROM payments 
      WHERE status = 'pending' 
      ORDER BY created_at ASC 
      LIMIT 10 
      FOR UPDATE SKIP LOCKED;
    `;
    const res = await clientDb.query(selectQuery);

    for (const payment of res.rows) {
      const startTime = Date.now();
      console.log(`Processing payment ${payment.id} (${payment.amount} ${payment.currency})...`);

      // Simulate hand-off latency to CRM / accounting
      await new Promise(resolve => setTimeout(resolve, 500));

      // Complete payment
      await clientDb.query(
        "UPDATE payments SET status = 'completed', updated_at = CURRENT_TIMESTAMP WHERE id = $1",
        [payment.id]
      );

      const durationSec = (Date.now() - startTime) / 1000;
      paymentProcessingDuration.observe(durationSec);
      paymentsProcessedTotal.inc({ status: 'completed' });
      console.log(`Payment ${payment.id} successfully completed and handed off to CRM.`);
    }

    await clientDb.query('COMMIT');
  } catch (err) {
    await clientDb.query('ROLLBACK');
    console.error('Error processing payments:', err);
    paymentsProcessedTotal.inc({ status: 'failed' });
  } finally {
    clientDb.release();
  }
}

// Start worker background loop
setInterval(processPayments, pollIntervalMs);

app.listen(port, () => {
  console.log(`Worker monitoring server listening on port ${port}`);
  console.log(`Worker started polling every ${pollIntervalMs}ms`);
});
