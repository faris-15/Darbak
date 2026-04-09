const Rating = require('../models/Rating');
const Shipment = require('../models/Shipment');
const User = require('../models/User');
const Notification = require('../models/Notification');

const addRating = async (req, res) => {
  try {
    const { shipment_id, rater_id, rated_id, stars, comment } = req.body;

    // Validate
    if (!shipment_id || !rater_id || !rated_id || !stars) {
      return res.status(400).json({ message: 'حقول مطلوبة مفقودة' });
    }

    if (stars < 1 || stars > 5) {
      return res.status(400).json({ message: 'التقييم يجب أن يكون بين 1 و 5' });
    }

    // Check if shipment exists and is delivered
    const shipment = await Shipment.findById(shipment_id);
    if (!shipment) {
      return res.status(404).json({ message: 'الشحنة غير موجودة' });
    }

    if (shipment.status !== 'delivered') {
      return res.status(400).json({ message: 'لا يمكن تقييم شحنة لم تكتمل بعد' });
    }

    // Check if rating already exists
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

    // Notify the rated user
    await Notification.create({
      user_id: rated_id,
      title: 'تقييم جديد',
      message: `حصلت على تقييم ${stars} نجمة`,
      is_read: 0,
    });

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
