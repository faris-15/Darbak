const Rating = require('../models/Rating');
const Shipment = require('../models/Shipment');
const Notification = require('../models/Notification');
const User = require('../models/User');
const { buildReviewTargetPublicProfile } = require('../services/profileService');
const { emitAdminDashboard } = require('../utils/adminRealtime');

const formatRatingSummary = (summary = {}) => {
  const averageRating = Number(summary.average_rating ?? 0);
  const totalRatings = Number(summary.total_ratings ?? 0);

  return {
    average_rating: Number.isFinite(averageRating) ? averageRating.toFixed(2) : '0.00',
    total_ratings: Number.isFinite(totalRatings) ? totalRatings : 0,
  };
};

const parsePositiveInt = (value) => {
  const parsed = Number(value);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : null;
};

const parseStars = (value) => {
  const parsed = Number(value);
  return Number.isInteger(parsed) && parsed >= 1 && parsed <= 5 ? parsed : null;
};

const normalizeComment = (value) => {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return trimmed.length ? trimmed : null;
};

const addRating = async (req, res) => {
  try {
    const rater_id = req.user?.id;
    const rater_role = req.user?.role;
    const shipment_id = parsePositiveInt(req.body.shipment_id);
    const rated_id = parsePositiveInt(req.body.rated_id);
    const stars = parseStars(req.body.stars);
    const comment = normalizeComment(req.body.comment);

    if (!rater_id || !['driver', 'shipper'].includes(rater_role)) {
      return res.status(401).json({ message: 'يجب تسجيل الدخول' });
    }

    if (!shipment_id || !rated_id || !stars) {
      return res.status(400).json({ message: 'حقول مطلوبة مفقودة' });
    }

    if (Number(rater_id) === Number(rated_id)) {
      return res.status(400).json({ message: 'لا يمكنك تقييم حسابك' });
    }

    const shipment = await Shipment.findById(shipment_id);
    if (!shipment) {
      return res.status(404).json({ message: 'الشحنة غير موجودة' });
    }

    if (shipment.status !== 'delivered') {
      return res.status(400).json({ message: 'لا يمكن تقييم شحنة لم تكتمل بعد' });
    }

    if (rater_role === 'driver') {
      if (Number(shipment.driver_id) !== Number(rater_id)) {
        return res.status(403).json({ message: 'لا يمكنك تقييم هذه الشحنة' });
      }
      if (Number(rated_id) !== Number(shipment.shipper_id)) {
        return res.status(400).json({ message: 'المقيم غير صحيح لهذه الشحنة' });
      }
    } else if (rater_role === 'shipper') {
      if (Number(shipment.shipper_id) !== Number(rater_id)) {
        return res.status(403).json({ message: 'لا يمكنك تقييم هذه الشحنة' });
      }
      if (!shipment.driver_id || Number(rated_id) !== Number(shipment.driver_id)) {
        return res.status(400).json({ message: 'المقيم غير صحيح لهذه الشحنة' });
      }
    } else {
      return res.status(403).json({ message: 'غير مصرح' });
    }

    // The database may not enforce uniqueness in all deployed schemas, so keep
    // duplicate prevention in the application layer for both rating directions.
    const existingRating = await Rating.findByShipmentAndRater(shipment_id, rater_id);
    if (existingRating) {
      return res.status(400).json({ message: 'لديك تقييم لهذه الشحنة بالفعل' });
    }

    const rating = await Rating.create({
      shipment_id,
      rater_id,
      rated_id,
      stars,
      comment,
      rater_role,
    });

    try {
      await Notification.create({
        user_id: rated_id,
        title: 'تقييم جديد',
        message: `حصلت على تقييم ${stars} نجمة`,
        related_shipment_id: shipment_id,
        is_read: 0,
      });
    } catch (e) {
      console.warn('[addRating] notification:', e.message);
    }

    const ratingSummary = await Rating.getAverageRating(rated_id);
    emitAdminDashboard(req, 'rating.created', { shipment_id, rated_id, stars });
    res.status(201).json({
      ...rating,
      ...formatRatingSummary(ratingSummary),
    });
  } catch (error) {
    console.error('Add rating error:', error);
    res.status(500).json({ message: 'خطأ في إضافة التقييم' });
  }
};

const getUserRatings = async (req, res) => {
  try {
    const userId = parsePositiveInt(req.params.userId);
    if (!userId) {
      return res.status(400).json({ message: 'معرف المستخدم غير صحيح' });
    }

    // Check if user exists
    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ message: 'المستخدم غير موجود' });
    }

    const ratings = await Rating.findByUserId(userId);
    const averageRating = await Rating.getAverageRating(userId);

    let rated_profile = null;
    try {
      rated_profile = await buildReviewTargetPublicProfile(userId);
    } catch (e) {
      console.warn('[getUserRatings] rated_profile:', e.message);
    }

    res.json({
      user_id: userId,
      ...formatRatingSummary(averageRating),
      ratings: ratings,
      rated_profile,
    });
  } catch (error) {
    console.error('Get user ratings error:', error);
    res.status(500).json({ message: 'خطأ في جلب التقييمات' });
  }
};

const updateRating = async (req, res) => {
  try {
    const ratingId = parsePositiveInt(req.params.ratingId);
    const stars = parseStars(req.body.stars);
    const comment = normalizeComment(req.body.comment);

    if (!ratingId || !stars) {
      return res.status(400).json({ message: 'التقييم غير صحيح' });
    }

    const current = await Rating.findById(ratingId);
    if (!current) {
      return res.status(404).json({ message: 'التقييم غير موجود' });
    }
    if (Number(current.rater_id) !== Number(req.user?.id)) {
      return res.status(403).json({ message: 'لا يمكنك تعديل هذا التقييم' });
    }

    const updated = await Rating.update(ratingId, {
      stars,
      comment,
    });

    if (!updated) {
      return res.status(404).json({ message: 'التقييم غير موجود' });
    }

    res.json({ message: 'تم تحديث التقييم بنجاح' });
  } catch (error) {
    console.error('Update rating error:', error);
    res.status(500).json({ message: 'خطأ في تحديث التقييم' });
  }
};

const deleteRating = async (req, res) => {
  try {
    const ratingId = parsePositiveInt(req.params.ratingId);
    if (!ratingId) {
      return res.status(400).json({ message: 'التقييم غير صحيح' });
    }

    const current = await Rating.findById(ratingId);
    if (!current) {
      return res.status(404).json({ message: 'التقييم غير موجود' });
    }
    if (Number(current.rater_id) !== Number(req.user?.id)) {
      return res.status(403).json({ message: 'لا يمكنك حذف هذا التقييم' });
    }

    const deleted = await Rating.delete(ratingId);
    if (!deleted) {
      return res.status(404).json({ message: 'التقييم غير موجود' });
    }

    res.json({ message: 'تم حذف التقييم بنجاح' });
  } catch (error) {
    console.error('Delete rating error:', error);
    res.status(500).json({ message: 'خطأ في حذف التقييم' });
  }
};

module.exports = { addRating, getUserRatings, updateRating, deleteRating };
