CREATE TABLE IF NOT EXISTS payments (
    id SERIAL PRIMARY KEY,
    amount NUMERIC(10, 2) NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'EUR',
    status VARCHAR(20) NOT NULL DEFAULT 'pending', -- pending, processing, completed, failed
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status);
