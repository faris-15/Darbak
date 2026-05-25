const pool = require('../config/db');
const Rating = require('./Rating');
const { TRUCK_CATEGORIES } = require('../constants/truckClassification');
const {
  computeLatePenaltyFromDeadline,
  shipmentDeadline,
} = require('../utils/lateDeliveryPenalty');

const withSuggestedPrice = (shipment) => {
  if (!shipment) return shipment;
  return {
    ...shipment,
    suggested_price: shipment.suggested_price ?? shipment.base_price,
  };
};

const acceptedBidAmountSql = (shipmentAlias = 's') => `(
          SELECT b.bid_amount
          FROM bids b
          WHERE b.shipment_id = ${shipmentAlias}.id
            AND b.bid_status = 'accepted'
          ORDER BY b.created_at DESC
          LIMIT 1
        ) AS accepted_bid_amount`;

const escapeLikeTerm = (value) =>
  String(value).replace(/[\\%_]/g, (match) => `\\${match}`);

const buildSearchWhere = (filters = {}) => {
  const where = [];
  const params = [];

  if (filters.shipperId) {
    where.push('s.shipper_id = ?');
    params.push(filters.shipperId);
  }

  if (Array.isArray(filters.statuses) && filters.statuses.length > 0) {
    where.push(`s.status IN (${filters.statuses.map(() => '?').join(', ')})`);
    params.push(...filters.statuses);
  }

  const addLike = (column, value) => {
    if (!value) return;
    where.push(`LOWER(${column}) LIKE LOWER(?)`);
    params.push(`%${escapeLikeTerm(value)}%`);
  };

  addLike('s.pickup_address', filters.pickupCity);
  addLike('s.dropoff_address', filters.dropoffCity);
  addLike('s.cargo_description', filters.cargoCategory);

  if (filters.city) {
    where.push('(LOWER(s.pickup_address) LIKE LOWER(?) OR LOWER(s.dropoff_address) LIKE LOWER(?))');
    const cityTerm = `%${escapeLikeTerm(filters.city)}%`;
    params.push(cityTerm, cityTerm);
  }

  if (filters.minPrice != null) {
    where.push('s.base_price >= ?');
    params.push(filters.minPrice);
  }

  if (filters.maxPrice != null) {
    where.push('s.base_price <= ?');
    params.push(filters.maxPrice);
  }

  if (filters.minWeight != null) {
    where.push('s.weight_kg >= ?');
    params.push(filters.minWeight);
  }

  if (filters.maxWeight != null) {
    where.push('s.weight_kg <= ?');
    params.push(filters.maxWeight);
  }

  if (filters.truckGroup) {
    const categoryIds = TRUCK_CATEGORIES.filter((c) => c.group === filters.truckGroup).map(
      (c) => c.id
    );
    if (categoryIds.length) {
      where.push(
        `(s.required_truck_group = ? OR s.required_truck_category IN (${categoryIds.map(() => '?').join(', ')}))`
      );
      params.push(filters.truckGroup, ...categoryIds);
    } else {
      where.push('s.required_truck_group = ?');
      params.push(filters.truckGroup);
    }
  }

  if (filters.truckCategory) {
    where.push('(s.required_truck_category IS NULL OR s.required_truck_category = ?)');
    params.push(filters.truckCategory);
  }

  if (filters.driverTruckCategory) {
    where.push('(s.required_truck_category IS NULL OR s.required_truck_category = ?)');
    params.push(filters.driverTruckCategory);
  } else if (filters.driverTruckGroup) {
    const categoryIds = TRUCK_CATEGORIES.filter((c) => c.group === filters.driverTruckGroup).map(
      (c) => c.id
    );
    if (categoryIds.length) {
      where.push(
        `(s.required_truck_category IS NULL OR s.required_truck_category IN (${categoryIds.map(() => '?').join(', ')}))`
      );
      params.push(...categoryIds);
    }
  }

  if (filters.driverMaxCapacityTons != null) {
    where.push('s.weight_kg <= ?');
    params.push(Number(filters.driverMaxCapacityTons) * 1000);
    where.push('(s.required_min_capacity_tons IS NULL OR s.required_min_capacity_tons <= ?)');
    params.push(filters.driverMaxCapacityTons);
  }

  if (filters.driverAxleCount != null) {
    where.push('(s.required_axle_count IS NULL OR s.required_axle_count <= ?)');
    params.push(filters.driverAxleCount);
  }

  if (filters.driverBodyType) {
    where.push('(s.required_body_type IS NULL OR s.required_body_type = ?)');
    params.push(filters.driverBodyType);
  }

  return {
    whereSql: where.length ? `WHERE ${where.join(' AND ')}` : '',
    params,
  };
};

const shipmentSelectSql = (ratingColumns) => `SELECT s.*,
        ${acceptedBidAmountSql('s')},
        (
          SELECT COALESCE(AVG(${ratingColumns.starsColumn}), 0)
          FROM ratings
          WHERE ${ratingColumns.ratedColumn} = s.shipper_id
            AND ${ratingColumns.starsColumn} BETWEEN 1 AND 5
        ) AS shipper_rating,
        (
          SELECT COUNT(*)
          FROM ratings
          WHERE ${ratingColumns.ratedColumn} = s.shipper_id
            AND ${ratingColumns.starsColumn} BETWEEN 1 AND 5
        ) AS shipper_rating_count
       FROM shipments s`;

const Shipment = {
  create: async ({
    shipperId,
    weightKg,
    cargoDescription,
    pickupAddress,
    dropoffAddress,
    pickupLat,
    pickupLng,
    dropoffLat,
    dropoffLng,
    basePrice,
    expectedDeliveryDate,
    period,
    specialInstructions,
    auctionDurationHours,
    auctionEndTime,
    requiredTruckGroup = null,
    requiredTruckCategory = null,
    requiredAxleCount = null,
    requiredBodyType = null,
    requiredMinCapacityTons = null,
  }) => {
    const [result] = await pool.execute(
      `INSERT INTO shipments (
         shipper_id, weight_kg, cargo_description,
         required_truck_group, required_truck_category, required_axle_count,
         required_body_type, required_min_capacity_tons,
         pickup_address, dropoff_address, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng,
         base_price, expected_delivery_date, final_delivery_date, period, special_instructions,
         auction_duration_hours, auction_end_time, status
       ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        shipperId,
        weightKg,
        cargoDescription,
        requiredTruckGroup,
        requiredTruckCategory,
        requiredAxleCount,
        requiredBodyType,
        requiredMinCapacityTons,
        pickupAddress,
        dropoffAddress,
        pickupLat,
        pickupLng,
        dropoffLat,
        dropoffLng,
        basePrice,
        expectedDeliveryDate,
        expectedDeliveryDate,
        period,
        specialInstructions,
        auctionDurationHours,
        auctionEndTime,
        'bidding',
      ]
    );
    return {
      id: result.insertId,
      shipper_id: shipperId,
      weight_kg: weightKg,
      cargo_description: cargoDescription,
      required_truck_group: requiredTruckGroup,
      required_truck_category: requiredTruckCategory,
      required_axle_count: requiredAxleCount,
      required_body_type: requiredBodyType,
      required_min_capacity_tons: requiredMinCapacityTons,
      pickup_address: pickupAddress,
      dropoff_address: dropoffAddress,
      pickup_lat: pickupLat,
      pickup_lng: pickupLng,
      dropoff_lat: dropoffLat,
      dropoff_lng: dropoffLng,
      base_price: basePrice,
      suggested_price: basePrice,
      expected_delivery_date: expectedDeliveryDate,
      final_delivery_date: expectedDeliveryDate,
      period: period,
      special_instructions: specialInstructions,
      auction_duration_hours: auctionDurationHours,
      auction_end_time: auctionEndTime,
      status: 'bidding',
    };
  },

  findById: async (id) => {
    const [rows] = await pool.execute(
      `SELECT s.*, ${acceptedBidAmountSql('s')},
              sh.full_name AS shipper_name
       FROM shipments s
       LEFT JOIN users sh ON sh.id = s.shipper_id
       WHERE s.id = ?`,
      [id]
    );
    return withSuggestedPrice(rows[0]);
  },

  findChatShipmentBetweenUsers: async ({
    senderId,
    receiverId,
    preferredShipmentId = null,
    statuses = [],
  }) => {
    if (!statuses.length) return null;
    const placeholders = statuses.map(() => '?').join(', ');
    const preferredSort = preferredShipmentId ? 'CASE WHEN id = ? THEN 0 ELSE 1 END,' : '';
    const params = [
      senderId,
      receiverId,
      receiverId,
      senderId,
      ...statuses,
    ];
    if (preferredShipmentId) params.push(preferredShipmentId);

    const [rows] = await pool.execute(
      `SELECT *
       FROM shipments
       WHERE (
           (shipper_id = ? AND driver_id = ?)
           OR (shipper_id = ? AND driver_id = ?)
         )
         AND status IN (${placeholders})
       ORDER BY ${preferredSort} id DESC
       LIMIT 1`,
      params
    );
    return withSuggestedPrice(rows[0]);
  },

  /** Count shipments for a shipper in given lifecycle statuses (e.g. active, open, bidding). */
  countByShipperInStatuses: async (shipperId, statuses) => {
    if (!statuses.length) return 0;
    const placeholders = statuses.map(() => '?').join(', ');
    const [rows] = await pool.execute(
      `SELECT COUNT(*) AS cnt FROM shipments WHERE shipper_id = ? AND status IN (${placeholders})`,
      [shipperId, ...statuses],
    );
    return Number(rows[0]?.cnt ?? 0);
  },

  list: async () => {
    return Shipment.search();
  },

  listForShipper: async (shipperId) => {
    return Shipment.search({ filters: { shipperId } });
  },

  search: async ({ filters = {}, pagination = null } = {}) => {
    const ratingColumns = await Rating.getColumnMap();
    const { whereSql, params } = buildSearchWhere(filters);
    const orderSql = 'ORDER BY s.created_at DESC';

    // Count separately from the rating SELECT so paginated filter refreshes stay
    // cheap; the composite indexes added in migrations support status/price/order.
    let total = null;
    if (pagination) {
      const [countRows] = await pool.execute(
        `SELECT COUNT(*) AS total FROM shipments s ${whereSql}`,
        params,
      );
      total = Number(countRows[0]?.total ?? 0);
    }

    const limitSql = pagination ? ' LIMIT ? OFFSET ?' : '';
    const queryParams = [...params];
    if (pagination) {
      queryParams.push(
        Number(pagination.limit),
        Number((pagination.page - 1) * pagination.limit),
      );
    }

    const [rows] = await pool.execute(
      `${shipmentSelectSql(ratingColumns)} ${whereSql} ${orderSql}${limitSql}`,
      queryParams,
    );

    const data = rows.map(withSuggestedPrice);
    if (!pagination) return data;

    return {
      data,
      pagination: {
        page: pagination.page,
        limit: pagination.limit,
        total,
        totalPages: Math.ceil(total / pagination.limit),
      },
    };
  },

  assignDriver: async (shipmentId, driverId) => {
    const [result] = await pool.execute('UPDATE shipments SET driver_id = ?, status = ? WHERE id = ?', [driverId, 'assigned', shipmentId]);
    return result.affectedRows > 0;
  },

  completeDelivery: async ({ shipmentId, bidAmount, actualDeliveryDate, shipment }) => {
    const targetShipment = shipment || await Shipment.findById(shipmentId);
    if (!targetShipment) throw new Error('Shipment not found');

    const deadlineRaw = shipmentDeadline(targetShipment);
    if (!deadlineRaw) throw new Error('Shipment has no delivery deadline');

    const { percent: penaltyPercent, amount: penaltyAmount } = computeLatePenaltyFromDeadline(
      deadlineRaw,
      actualDeliveryDate,
      bidAmount,
    );
    const finalPrice = Number((Number(bidAmount) - penaltyAmount).toFixed(2));

    const [result] = await pool.execute(
      'UPDATE shipments SET actual_delivery_date = ?, final_price = ?, penalty_amount = ?, status = ? WHERE id = ?',
      [actualDeliveryDate, finalPrice, penaltyAmount, 'delivered', shipmentId]
    );

    return {
      success: result.affectedRows > 0,
      final_price: finalPrice,
      penalty_percent: penaltyPercent,
      penalty_amount: penaltyAmount,
    };
  },

  updateStatus: async (shipmentId, status) => {
    const [result] = await pool.execute(
      'UPDATE shipments SET status = ? WHERE id = ?',
      [status, shipmentId]
    );
    return result.affectedRows > 0;
  },

  listActiveByDriver: async (driverId) => {
    const [rows] = await pool.execute(
      `SELECT s.*, ${acceptedBidAmountSql('s')},
              sh.full_name AS shipper_name
       FROM shipments s
       LEFT JOIN users sh ON sh.id = s.shipper_id
       WHERE s.driver_id = ?
         AND status IN ('assigned', 'at_pickup', 'en_route', 'at_dropoff')
       ORDER BY s.created_at DESC`,
      [driverId]
    );
    return rows.map(withSuggestedPrice);
  },

  listByDriverPriority: async (driverId) => {
    const [rows] = await pool.execute(
      `SELECT s.*,
        ${acceptedBidAmountSql('s')},
        sh.full_name AS shipper_name,
        CASE
          WHEN s.status IN ('assigned', 'at_pickup', 'en_route', 'at_dropoff') THEN 1
          WHEN s.status IN ('delivered', 'cancelled') THEN 2
          ELSE 3
        END AS status_priority
       FROM shipments s
       LEFT JOIN users sh ON sh.id = s.shipper_id
       WHERE s.driver_id = ?
       ORDER BY
         status_priority ASC,
         CASE
           WHEN s.status IN ('assigned', 'at_pickup', 'en_route', 'at_dropoff') THEN s.created_at
           ELSE NULL
         END DESC,
         CASE
           WHEN s.status IN ('delivered', 'cancelled') THEN COALESCE(s.actual_delivery_date, s.created_at)
           ELSE NULL
         END DESC,
         s.created_at DESC`,
      [driverId]
    );
    return rows.map(withSuggestedPrice);
  },

  setDeliveryMetadata: async (shipmentId, { actualDeliveryDate, podPhotoPath }) => {
    const [result] = await pool.execute(
      'UPDATE shipments SET actual_delivery_date = ? WHERE id = ?',
      [actualDeliveryDate, shipmentId]
    );
    return result.affectedRows > 0;
  },

  getDriverStats: async (driverId) => {
    const [rows] = await pool.execute(
      'SELECT COUNT(*) as completed_trips, SUM(final_price) as total_earnings FROM shipments WHERE driver_id = ? AND status = ?',
      [driverId, 'delivered']
    );
    return {
      completed_trips: rows[0]?.completed_trips || 0,
      total_earnings: rows[0]?.total_earnings || 0,
    };
  },

  getShipperStats: async (shipperId) => {
    const [rows] = await pool.execute(
      'SELECT \
         COUNT(*) as total_shipments, \
         SUM(CASE WHEN status = \'delivered\' THEN 1 ELSE 0 END) as delivered_shipments, \
         SUM(CASE WHEN status != \'delivered\' AND status != \'cancelled\' THEN 1 ELSE 0 END) as active_shipments \
       FROM shipments \
       WHERE shipper_id = ?',
      [shipperId]
    );
    return {
      total_shipments: rows[0]?.total_shipments || 0,
      delivered_shipments: rows[0]?.delivered_shipments || 0,
      active_shipments: rows[0]?.active_shipments || 0,
    };
  },
};

module.exports = Shipment;
