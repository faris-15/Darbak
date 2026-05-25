const pool = require('../config/db');
const Shipment = require('../models/Shipment');
const Bid = require('../models/Bid');
const Wallet = require('../models/Wallet');
const User = require('../models/User');
const Notification = require('../models/Notification');
const ShipmentStatus = require('../models/ShipmentStatus');
const Contract = require('../models/Contract');
const { generatePresignedUrl } = require('../utils/s3Config');
const { emitAdminDashboard } = require('../utils/adminRealtime');
const {
  computeLatePenaltyFromDeadline,
  shipmentDeadline,
} = require('../utils/lateDeliveryPenalty');
const { ensureShipmentTruckSchema } = require('../utils/shipmentTruckSchema');
const { buildTruckRequirementPayload } = require('../utils/shipmentTruckMatch');
const Truck = require('../models/Truck');
const { TRUCK_GROUPS, getCategoryById } = require('../constants/truckClassification');

const Message = require('../models/Message');

const OPEN_SHIPMENT_STATUSES = ['pending', 'bidding', 'assigned', 'at_pickup', 'en_route', 'at_dropoff'];
const MAX_OPEN_SHIPMENTS_PER_SHIPPER = 5;

const jsonError = (res, status, code, message) =>
  res.status(status).json({ success: false, code, message });

const parseMoney = (value) => {
  const amount = Number(value);
  if (!Number.isFinite(amount) || amount <= 0 || amount > 99999999.99) return null;
  return Number(amount.toFixed(2));
};

const SHIPMENT_STATUSES = new Set([
  'pending',
  'bidding',
  'assigned',
  'at_pickup',
  'en_route',
  'at_dropoff',
  'delivered',
  'cancelled',
]);
const MAX_FILTER_TEXT_LENGTH = 80;
const MAX_SHIPMENT_PAGE_SIZE = 100;

const firstQueryValue = (value) => (Array.isArray(value) ? value[0] : value);

const readFilterText = (query, keys) => {
  for (const key of keys) {
    const raw = firstQueryValue(query[key]);
    if (raw == null) continue;
    const text = String(raw).trim();
    if (!text) continue;
    if (text.length > MAX_FILTER_TEXT_LENGTH) {
      return { error: `${key} is too long` };
    }
    return { value: text };
  }
  return { value: null };
};

const parseOptionalPrice = (query, keys) => {
  for (const key of keys) {
    const raw = firstQueryValue(query[key]);
    if (raw == null || raw === '') continue;
    const value = Number(raw);
    if (!Number.isFinite(value) || value < 0 || value > 99999999.99) {
      return { error: `${key} is invalid` };
    }
    return { value: Number(value.toFixed(2)) };
  }
  return { value: null };
};

const parsePositiveInt = (query, key) => {
  const raw = firstQueryValue(query[key]);
  if (raw == null || raw === '') return { value: null };
  const parsed = Number(raw);
  if (!Number.isInteger(parsed) || parsed <= 0) {
    return { error: `${key} must be a positive integer` };
  }
  return { value: parsed };
};

const parseShipmentListQuery = (query) => {
  const statuses = [];
  const rawStatus = firstQueryValue(query.status);
  if (rawStatus) {
    for (const status of String(rawStatus).split(',')) {
      const normalized = status.trim();
      if (!normalized) continue;
      if (!SHIPMENT_STATUSES.has(normalized)) {
        return { error: 'حالة الشحنة غير صحيحة' };
      }
      statuses.push(normalized);
    }
  }

  const availableOnly = ['1', 'true', 'yes'].includes(
    String(firstQueryValue(query.availableOnly) ?? '').toLowerCase(),
  );
  if (!statuses.length && availableOnly) {
    statuses.push('pending', 'bidding');
  }

  const pickupCity = readFilterText(query, ['pickupCity', 'originCity', 'fromCity']);
  if (pickupCity.error) return { error: 'مدينة الانطلاق طويلة جداً' };
  const dropoffCity = readFilterText(query, ['dropoffCity', 'destinationCity', 'toCity']);
  if (dropoffCity.error) return { error: 'مدينة الوصول طويلة جداً' };
  const city = readFilterText(query, ['city', 'q', 'search']);
  if (city.error) return { error: 'نص البحث طويل جداً' };
  const cargoCategory = readFilterText(query, [
    'cargoCategory',
    'cargoType',
    'shipmentType',
  ]);
  if (cargoCategory.error) return { error: 'نوع الحمولة طويل جداً' };

  const minWeight = parseOptionalPrice(query, ['minWeight', 'weightMin']);
  if (minWeight.error) return { error: 'أقل وزن غير صحيح' };
  const maxWeight = parseOptionalPrice(query, ['maxWeight', 'weightMax']);
  if (maxWeight.error) return { error: 'أعلى وزن غير صحيح' };
  if (minWeight.value != null && maxWeight.value != null && minWeight.value > maxWeight.value) {
    return { error: 'نطاق الوزن غير صحيح' };
  }

  const minPrice = parseOptionalPrice(query, [
    'minPrice',
    'priceMin',
    'minSuggestedPrice',
    'suggestedPriceMin',
  ]);
  if (minPrice.error) return { error: 'أقل سعر غير صحيح' };
  const maxPrice = parseOptionalPrice(query, [
    'maxPrice',
    'priceMax',
    'maxSuggestedPrice',
    'suggestedPriceMax',
  ]);
  if (maxPrice.error) return { error: 'أعلى سعر غير صحيح' };
  if (minPrice.value != null && maxPrice.value != null && minPrice.value > maxPrice.value) {
    return { error: 'نطاق السعر غير صحيح' };
  }

  const page = parsePositiveInt(query, 'page');
  if (page.error) return { error: 'رقم الصفحة غير صحيح' };
  const limit = parsePositiveInt(query, 'limit');
  if (limit.error) return { error: 'حجم الصفحة غير صحيح' };

  const truckGroup = readFilterText(query, ['truckGroup', 'requiredTruckGroup']);
  if (truckGroup.error) return { error: 'مجموعة الشاحنة طويلة جداً' };
  const truckCategory = readFilterText(query, ['truckCategory', 'requiredTruckCategory']);
  if (truckCategory.error) return { error: 'فئة الشاحنة طويلة جداً' };

  const matchMyTruck = ['1', 'true', 'yes'].includes(
    String(firstQueryValue(query.matchMyTruck) ?? '').toLowerCase(),
  );

  if (truckGroup.value && !Object.values(TRUCK_GROUPS).includes(truckGroup.value)) {
    return { error: 'مجموعة الشاحنة غير صالحة' };
  }

  return {
    filters: {
      statuses,
      pickupCity: pickupCity.value,
      dropoffCity: dropoffCity.value,
      city: city.value,
      cargoCategory: cargoCategory.value,
      minWeight: minWeight.value,
      maxWeight: maxWeight.value,
      minPrice: minPrice.value,
      maxPrice: maxPrice.value,
      truckGroup: truckGroup.value,
      truckCategory: truckCategory.value,
      matchMyTruck,
    },
    pagination:
      page.value || limit.value
        ? {
            page: page.value ?? 1,
            limit: Math.min(limit.value ?? 20, MAX_SHIPMENT_PAGE_SIZE),
          }
        : null,
  };
};

const createShipment = async (req, res) => {
  try {
    const {
      weightKg,
      cargoDescription,
      pickupAddress,
      dropoffAddress,
      pickupLat,
      pickupLng,
      dropoffLat,
      dropoffLng,
      basePrice,
      suggestedPrice,
      expectedDeliveryDate,
      period,
      specialInstructions,
      auctionDurationHours,
    } = req.body;
    const shipperId = req.user?.id;
    const parsedSuggestedPrice = parseMoney(suggestedPrice ?? basePrice);

    console.log('[createShipment] Input:', {
      shipperId,
      weightKg,
      period,
      suggestedPrice: parsedSuggestedPrice,
      expectedDeliveryDate,
    });

    // Validate all required fields
    if (!shipperId || !weightKg || !pickupAddress || !dropoffAddress || !expectedDeliveryDate || !period) {
      return jsonError(res, 400, 'VALIDATION_ERROR', 'جميع الحقول مطلوبة');
    }

    const parsedPickupLat = Number(pickupLat);
    const parsedPickupLng = Number(pickupLng);
    const parsedDropoffLat = Number(dropoffLat);
    const parsedDropoffLng = Number(dropoffLng);

    if (
      !Number.isFinite(parsedPickupLat) ||
      !Number.isFinite(parsedPickupLng) ||
      !Number.isFinite(parsedDropoffLat) ||
      !Number.isFinite(parsedDropoffLng)
    ) {
      return jsonError(res, 400, 'VALIDATION_ERROR', 'إحداثيات التحميل والتسليم مطلوبة');
    }

    // Validate shipper exists and is of type 'shipper'
    const shipper = await User.findById(shipperId);
    if (!shipper) {
      return jsonError(res, 404, 'NOT_FOUND', 'المستخدم غير موجود');
    }
    if (shipper.role !== 'shipper') {
      return jsonError(res, 403, 'FORBIDDEN', 'فقط الشاحنون يمكنهم إنشاء شحنات');
    }

    const openCount = await Shipment.countByShipperInStatuses(shipperId, OPEN_SHIPMENT_STATUSES);
    if (openCount >= MAX_OPEN_SHIPMENTS_PER_SHIPPER) {
      return jsonError(
        res,
        400,
        'LIMIT_EXCEEDED',
        'لا يمكنك إضافة أكثر من 5 شحنات نشطة/مفتوحة',
      );
    }

    // Validate company suggested price; it remains stored in base_price for old tenders/clients.
    if (parsedSuggestedPrice == null) {
      return jsonError(res, 400, 'VALIDATION_ERROR', 'السعر المقترح يجب أن يكون أكبر من صفر');
    }

    // Validate weight
    const parsedWeightKg = Number(weightKg);
    if (!Number.isFinite(parsedWeightKg) || parsedWeightKg <= 0) {
      return jsonError(res, 400, 'VALIDATION_ERROR', 'الوزن يجب أن يكون أكبر من صفر');
    }

    // Create shipment
    const parsedAuctionDuration = Number(auctionDurationHours ?? 24);
    if (!Number.isInteger(parsedAuctionDuration) || parsedAuctionDuration <= 0) {
      return jsonError(res, 400, 'VALIDATION_ERROR', 'مدة المزاد يجب أن تكون بالساعات وبقيمة صحيحة');
    }
    const auctionEndTime = new Date(Date.now() + parsedAuctionDuration * 60 * 60 * 1000);

    await ensureShipmentTruckSchema();
    const truckReq = buildTruckRequirementPayload(req.body, parsedWeightKg);
    if (!truckReq.ok) {
      return jsonError(res, 400, 'VALIDATION_ERROR', truckReq.error);
    }

    const shipment = await Shipment.create({
      shipperId,
      weightKg: parsedWeightKg,
      cargoDescription,
      requiredTruckGroup: truckReq.data.required_truck_group,
      requiredTruckCategory: truckReq.data.required_truck_category,
      requiredAxleCount: truckReq.data.required_axle_count,
      requiredBodyType: truckReq.data.required_body_type,
      requiredMinCapacityTons: truckReq.data.required_min_capacity_tons,
      pickupAddress,
      dropoffAddress,
      pickupLat: parsedPickupLat,
      pickupLng: parsedPickupLng,
      dropoffLat: parsedDropoffLat,
      dropoffLng: parsedDropoffLng,
      basePrice: parsedSuggestedPrice,
      expectedDeliveryDate,
      period,
      specialInstructions:
        typeof specialInstructions === 'string' &&
        specialInstructions.trim().length > 0
          ? specialInstructions.trim()
          : null,
      auctionDurationHours: parsedAuctionDuration,
      auctionEndTime,
    });

    console.log('[createShipment] Success:', { shipmentId: shipment.id, period });
    emitAdminDashboard(req, 'shipment.created', { shipmentId: shipment.id, shipperId });
    res.status(201).json(shipment);
  } catch (error) {
    console.error('[createShipment] Database error:', error.message, 'Code:', error.code, 'SQLState:', error.sqlState);
    return jsonError(
      res,
      500,
      'INTERNAL_ERROR',
      error.message || 'خطأ في إنشاء الشحنة',
    );
  }
};

const listShipments = async (req, res) => {
  try {
    const parsedQuery = parseShipmentListQuery(req.query);
    if (parsedQuery.error) {
      return jsonError(res, 400, 'VALIDATION_ERROR', parsedQuery.error);
    }

    const isShipper = req.user?.role === 'shipper';
    const hasQuery = Object.keys(req.query ?? {}).length > 0;

    // Preserve the legacy raw-array response when callers do not opt into the
    // searchable contract. The driver market sends pagination, so it receives
    // the new envelope without breaking older shipper screens.
    if (!hasQuery) {
      const shipments = isShipper ? await Shipment.listForShipper(req.user.id) : await Shipment.list();
      return res.json(shipments);
    }

    const filters = {
      ...parsedQuery.filters,
      shipperId: isShipper ? req.user.id : null,
    };

    if (req.user?.role === 'driver' && parsedQuery.filters.matchMyTruck) {
      const activeTruck = await Truck.findActiveByDriverId(req.user.id);
      if (!activeTruck) {
        return res.json(
          parsedQuery.pagination
            ? { data: [], pagination: { ...parsedQuery.pagination, total: 0, totalPages: 0 } }
            : []
        );
      }
      filters.driverTruckCategory = activeTruck.category || null;
      filters.driverTruckGroup = getCategoryById(activeTruck.category)?.group || null;
      filters.driverMaxCapacityTons = Number(activeTruck.max_weight_tons || 0) || null;
      filters.driverAxleCount = activeTruck.axle_count;
      filters.driverBodyType = activeTruck.body_type;
    }

    delete filters.matchMyTruck;

    const result = await Shipment.search({
      filters,
      pagination: parsedQuery.pagination,
    });
    return res.json(result);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'خطأ في جلب الشحنات' });
  }
};

const getShipment = async (req, res) => {
  try {
    const { id } = req.params;
    const shipment = await Shipment.findById(id);
    if (!shipment) return res.status(404).json({ message: 'الشحنة غير موجودة' });
    let contract_pdf_key = null;
    try {
      const row = await Contract.findByShipmentId(id);
      contract_pdf_key = row?.pdf_key ?? null;
    } catch (_) {
      /* contracts table may not exist yet */
    }

    const deadline = shipmentDeadline(shipment);
    const bidAmount = Number(shipment.accepted_bid_amount ?? 0);
    const isTerminal = ['delivered', 'cancelled'].includes(shipment.status);
    let late_penalty_percent = 0;
    let late_penalty_amount = 0;
    if (!isTerminal && deadline && bidAmount > 0) {
      const v = computeLatePenaltyFromDeadline(deadline, new Date(), bidAmount);
      late_penalty_percent = v.percent;
      late_penalty_amount = v.amount;
    } else if (shipment.status === 'delivered') {
      late_penalty_amount = Number(shipment.penalty_amount ?? 0);
      if (bidAmount > 0 && late_penalty_amount > 0) {
        late_penalty_percent = Math.round((late_penalty_amount / bidAmount) * 100);
      }
    }

    let out = {
      ...shipment,
      contract_pdf_key,
      late_penalty_percent,
      late_penalty_amount,
    };
    if (!String(out.shipper_name ?? '').trim() && shipment.shipper_id) {
      const shipper = await User.findById(shipment.shipper_id);
      const fn = shipper?.full_name?.toString?.()?.trim?.();
      if (fn) out = { ...out, shipper_name: fn };
    }

    res.json(out);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'خطأ خادم' });
  }
};

const getShipmentContractPdfUrl = async (req, res) => {
  try {
    const { id } = req.params;
    const uid = req.user?.id;
    if (!uid) return res.status(401).json({ message: 'غير مصرح' });

    const shipment = await Shipment.findById(id);
    if (!shipment) return res.status(404).json({ message: 'الشحنة غير موجودة' });

    const allowed =
      Number(shipment.shipper_id) === Number(uid) || Number(shipment.driver_id) === Number(uid);
    if (!allowed) return res.status(403).json({ message: 'لا يمكنك الوصول لهذا العقد' });

    const row = await Contract.findByShipmentId(id);
    if (!row?.pdf_key) return res.status(404).json({ message: 'لا يوجد عقد لهذه الشحنة' });

    const url = await generatePresignedUrl(row.pdf_key);
    console.log('[getShipmentContractPdfUrl] Generated URL:', url);
    return res.json({ url, pdf_key: row.pdf_key });
  } catch (error) {
    console.error('[getShipmentContractPdfUrl]', error);
    return res.status(500).json({ message: 'خطأ في جلب رابط العقد' });
  }
};

const recordLiveLocation = async (req, res) => {
  try {
    if (req.user?.role !== 'driver') {
      return res.status(403).json({ message: 'Forbidden' });
    }
    const { id } = req.params;
    const { location_lat, location_lng } = req.body;
    const lat = Number(location_lat);
    const lng = Number(location_lng);
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
      return res.status(400).json({ message: 'إحداثيات غير صالحة' });
    }

    const shipment = await Shipment.findById(id);
    if (!shipment) return res.status(404).json({ message: 'الشحنة غير موجودة' });
    if (Number(shipment.driver_id) !== Number(req.user.id)) {
      return res.status(403).json({ message: 'لا يمكنك تحديث موقع هذه الشحنة' });
    }

    const activeStatuses = new Set(['assigned', 'at_pickup', 'en_route', 'at_dropoff']);
    if (!activeStatuses.has(shipment.status)) {
      return res.status(400).json({ message: 'لا يمكن إرسال الموقع لهذه الحالة' });
    }

    const history = await ShipmentStatus.recordStatus({
      shipment_id: id,
      status: shipment.status,
      location_lat: lat,
      location_lng: lng,
      photo_path: null,
    });

    return res.json({ message: 'تم تسجيل الموقع', history });
  } catch (error) {
    console.error('[recordLiveLocation]', error);
    return res.status(500).json({ message: 'خطأ في تسجيل الموقع' });
  }
};

const completeDelivery = async (req, res) => {
  try {
    const { id } = req.params;
    const { bidId, actualDeliveryDate } = req.body;

    const bid = await Bid.findById(bidId);
    if (!bid) return res.status(404).json({ message: 'العرض غير موجود' });
    if (Number(bid.shipment_id) !== Number(id)) return res.status(400).json({ message: 'العرض لا ينتمي لهذه الشحنة' });

    // قبول هذا العرض ورفض الباقي
    await Bid.setStatus(bidId, 'accepted');
    await Bid.rejectOtherBidsForShipment(id, bidId);

    const result = await Shipment.completeDelivery({ shipmentId: id, bidAmount: Number(bid.bid_amount), actualDeliveryDate });

    // إضافة الايراد إلى المحفظة للسائق
    await Wallet.adjustBalance(bid.driver_id, result.final_price);

    // Delete chat conversation when shipment is completed
    await Message.deleteByShipment(id).catch(err => console.error('[completeDelivery] Chat deletion error:', err));

    res.json({ message: 'تم إكمال التسليم', result });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'خطأ في إنهاء الشحنة' });
  }
};

const attachShipperDisplayNames = async (shipments) => {
  if (!Array.isArray(shipments) || !shipments.length) return shipments;
  const needs = shipments.filter((s) => !String(s?.shipper_name ?? '').trim());
  if (!needs.length) return shipments;
  const ids = needs.map((s) => s.shipper_id);
  const byId = await User.getFullNamesByIds(ids);
  return shipments.map((s) => {
    const name = String(s?.shipper_name ?? '').trim();
    if (name) return s;
    const sid = Number(s.shipper_id);
    const full = byId[sid];
    if (!full) return s;
    return { ...s, shipper_name: full };
  });
};

const getActiveShipmentsForDriver = async (req, res) => {
  try {
    if (req.user?.role !== 'driver') {
      return res.status(403).json({ message: 'Forbidden' });
    }

    const shipments = await attachShipperDisplayNames(
      await Shipment.listActiveByDriver(req.user.id),
    );
    return res.json(shipments);
  } catch (error) {
    console.error('[getActiveShipmentsForDriver] Error:', error);
    return res.status(500).json({ message: 'خطأ في جلب الشحنات النشطة' });
  }
};

const getShipmentsForDriver = async (req, res) => {
  try {
    if (req.user?.role !== 'driver') {
      return res.status(403).json({ message: 'Forbidden' });
    }

    const shipments = await attachShipperDisplayNames(
      await Shipment.listByDriverPriority(req.user.id),
    );
    return res.json(shipments);
  } catch (error) {
    console.error('[getShipmentsForDriver] Error:', error);
    return res.status(500).json({ message: 'خطأ في جلب رحلات السائق' });
  }
};

const allowedLifecycleStatuses = [
  'assigned',
  'at_pickup',
  'en_route',
  'at_dropoff',
  'delivered',
];

const updateShipmentStatus = async (req, res) => {
  try {
    if (req.user?.role !== 'driver') {
      return res.status(403).json({ message: 'Forbidden' });
    }

    const { id } = req.params;
    const { status, location_lat, location_lng } = req.body;

    if (!allowedLifecycleStatuses.includes(status)) {
      return res.status(400).json({ message: 'حالة الشحنة غير صحيحة' });
    }

    // Step 1: Pre-fetch shipment for validation and to pass to sub-methods (reduces queries)
    const shipment = await Shipment.findById(id);
    if (!shipment) {
      return res.status(404).json({ message: 'الشحنة غير موجودة' });
    }

    if (Number(shipment.driver_id) !== Number(req.user.id)) {
      return res.status(403).json({ message: 'لا يمكنك تحديث هذه الشحنة' });
    }

    if (status === 'delivered' && !req.file) {
      return res.status(400).json({ message: 'صورة إثبات التسليم مطلوبة' });
    }

    const photoPath = req.file ? req.file.location || req.file.key : null;

    // Step 2: Parallelize history recording with main update logic
    const statusRecordPromise = ShipmentStatus.recordStatus({
      shipment_id: id,
      status,
      location_lat: location_lat ?? null,
      location_lng: location_lng ?? null,
      photo_path: photoPath,
    });

    let penaltyInfo = null;
    let updated = false;

    // Step 3: Branch update logic to avoid redundant SQL calls
    if (status === 'delivered') {
      const now = new Date();
      const [bids] = await pool.execute(
        'SELECT id, bid_amount FROM bids WHERE shipment_id = ? AND bid_status = "accepted" LIMIT 1',
        [id],
      );

      if (bids.length > 0) {
        const bid = bids[0];
        // completeDelivery handles status update and penalty calculation in one go
        const resPenalty = await Shipment.completeDelivery({
          shipmentId: id,
          bidAmount: Number(bid.bid_amount),
          actualDeliveryDate: now,
          shipment: shipment
        });

        updated = resPenalty.success;
        await Wallet.adjustBalance(req.user.id, resPenalty.final_price);

        penaltyInfo = {
          final_price: resPenalty.final_price,
          penalty_amount: resPenalty.penalty_amount,
        };
      } else {
        updated = await Shipment.updateStatus(id, status);
      }
    } else {
      updated = await Shipment.updateStatus(id, status);
    }

    if (!updated) {
      return res.status(500).json({ message: 'تعذر تحديث الحالة' });
    }

    // Chat cleanup if terminal
    if (status === 'delivered' || status === 'cancelled') {
        Message.deleteByShipment(id).catch(err => console.error('[updateShipmentStatus] Chat deletion error:', err));
    }

    // Step 4: Final parallel tasks
    const [statusRecord, shipmentAfter] = await Promise.all([
      statusRecordPromise,
      Shipment.findById(id) // Fresh state for the client
    ]);

    emitAdminDashboard(req, 'shipment.status', {
      shipmentId: Number(id),
      status,
      driverId: req.user?.id,
    });

    return res.json({
      success: true,
      message: 'تم تحديث حالة الشحنة بنجاح',
      shipment: shipmentAfter,
      history: statusRecord,
      penalty: penaltyInfo
    });
  } catch (error) {
    console.error('[updateShipmentStatus] Error:', error);
    return res.status(500).json({ message: 'خطأ في تحديث حالة الشحنة' });
  }
};

module.exports = {
  createShipment,
  listShipments,
  getShipment,
  getShipmentContractPdfUrl,
  recordLiveLocation,
  completeDelivery,
  getActiveShipmentsForDriver,
  getShipmentsForDriver,
  updateShipmentStatus,
};