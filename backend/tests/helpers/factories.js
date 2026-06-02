/**
 * Object factories returning realistic shapes for the mock DB to emit.
 * They mirror the column names actually used by controllers/models so that
 * tests stay in sync with real production responses.
 */
'use strict';

const userFactory = (overrides = {}) => ({
  id: 100,
  full_name: 'سائق اختبار',
  email: 'driver@test.local',
  phone: '0500000001',
  password: '$2a$10$Wl5w3xfqWshHGmnDp0Tjqe1V/b/Nf2DfHv4F7mWjBxWk8hKqSXVS6', // bcrypt('password123')
  role: 'driver',
  is_active: 1,
  verification_status: 'verified',
  license_no: null,
  commercial_no: null,
  document_path: null,
  issue_date: null,
  expiry_date: '2099-12-31',
  profile_image_url: null,
  ...overrides,
});

const shipperFactory = (overrides = {}) =>
  userFactory({
    id: 200,
    full_name: 'شركة اختبار',
    email: 'shipper@test.local',
    phone: '0500000002',
    role: 'shipper',
    ...overrides,
  });

const adminFactory = (overrides = {}) =>
  userFactory({
    id: 1,
    full_name: 'مشرف',
    email: 'admin@test.local',
    phone: '0500000099',
    role: 'admin',
    ...overrides,
  });

const shipmentFactory = (overrides = {}) => ({
  id: 1000,
  shipper_id: 200,
  driver_id: null,
  status: 'bidding',
  pickup_address: 'الرياض',
  dropoff_address: 'جدة',
  cargo_description: 'مواد بناء',
  weight_kg: 5000,
  base_price: 1500,
  suggested_price: 1500,
  auction_end_time: null,
  expected_delivery_date: null,
  final_delivery_date: null,
  required_truck_category: null,
  required_truck_group: null,
  required_axle_count: null,
  required_body_type: null,
  required_min_capacity_tons: null,
  ...overrides,
});

const bidFactory = (overrides = {}) => ({
  id: 5000,
  shipment_id: 1000,
  driver_id: 100,
  bid_amount: 1450,
  estimated_days: 2,
  bid_status: 'pending',
  ...overrides,
});

const truckFactory = (overrides = {}) => ({
  id: 9000,
  user_id: 100,
  plate_number: 'AAA-1234',
  truck_type: 'دينا',
  category: 'medium_double_5_10',
  axle_count: 2,
  body_type: 'box',
  payload_capacity: '5_10',
  max_weight_tons: 7.5,
  capacity_kg: 7500,
  manufacturing_year: 2024,
  insurance_expiry_date: '2099-12-31',
  verification_status: 'verified',
  is_active: 1,
  ...overrides,
});

module.exports = {
  userFactory,
  shipperFactory,
  adminFactory,
  shipmentFactory,
  bidFactory,
  truckFactory,
};
