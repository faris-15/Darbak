const Rating = require('../models/Rating');
const Shipment = require('../models/Shipment');
const Notification = require('../models/Notification');

const addRating = async (req, res) => {
  try {
    const rater_id = req.user?.id;
    const rater_role = req.user?.role;
    const { shipment_id, rated_id, stars, comment } = req.body;

    if (!rater_id || !['driver', 'shipper'].includes(rater_role)) {
      return res.status(401).json({ message: 'يجب تسجيل الدخول' });
    }

    if (!shipment_id || !rated_id || !stars) {
      return res.status(400).json({ message: 'حقول مطلوبة مفقودة' });
    }

    if (stars < 1 || stars > 5) {
      return res.status(400).json({ message: 'التقييم يجب أن يكون بين 1 و 5' });
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

    const existingRating = await Rating.findByShipmentAndRater(shipment_id, rater_id);
    if (existingRating) {
      return res.status(400).json({ message: 'لديك تقييم لهذه الشحنة بالفعل' });
    }

    const rating = await Rating.create({
      shipment_id,
      rater_id,
      rated_id,
      stars: Number(stars),
      comment,
    });

    try {
      await Notification.create({
        user_id: rated_id,
        title: 'تقييم جديد',
        message: `حصلت على تقييم ${stars} نجمة`,
        is_read: 0,
      });
    } catch (e) {
      console.warn('[addRating] notification:', e.message);
    }

    res.status(201).json(rating);
  } catch (error) {
    console.error('Add rating error:', error);
    res.status(500).json({ message: 'خطأ في إضافة التقييم' });
  }
};

const getUserRatings = async (req, res) => {
  try {
    const { userId } = req.params;

    // Check if user exists
    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ message: 'المستخدم غير موجود' });
    }

    const ratings = await Rating.findByUserId(userId);
    const averageRating = await Rating.getAverageRating(userId);

    res.json({
      user_id: userId,
      average_rating: parseFloat(averageRating.average_rating).toFixed(2),
      total_ratings: averageRating.total_ratings,
      ratings: ratings,
    });
  } catch (error) {
    console.error('Get user ratings error:', error);
    res.status(500).json({ message: 'خطأ في جلب التقييمات' });
  }
};

const updateRating = async (req, res) => {
  try {
    const { ratingId } = req.params;
    const { stars, comment } = req.body;

    if (!stars || stars < 1 || stars > 5) {
      return res.status(400).json({ message: 'التقييم غير صحيح' });
    }

    const updated = await Rating.update(ratingId, {
      stars: Number(stars),
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
    const { ratingId } = req.params;

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
