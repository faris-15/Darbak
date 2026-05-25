-- Supports driver market filtering by cargo weight with status pagination.
CREATE INDEX idx_shipments_status_weight_created
  ON shipments (status, weight_kg, created_at);
