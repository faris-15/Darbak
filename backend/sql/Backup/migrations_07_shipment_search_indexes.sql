-- Indexes for driver market search, filtering, pagination, and refresh.
-- They narrow by lifecycle status/price first and keep created_at ordering cheap.
CREATE INDEX idx_shipments_status_created
  ON shipments (status, created_at);

CREATE INDEX idx_shipments_status_price_created
  ON shipments (status, base_price, created_at);

CREATE INDEX idx_shipments_driver_status_created
  ON shipments (driver_id, status, created_at);

CREATE INDEX idx_shipments_shipper_created
  ON shipments (shipper_id, created_at);
