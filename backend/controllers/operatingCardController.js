const OperatingCard = require('../models/OperatingCard');
const { deleteS3Object, generatePresignedUrl } = require('../utils/s3Config');

const getOperatingCard = async (req, res) => {
  try {
    const driverId = req.user.id;
    const card = await OperatingCard.findByDriverId(driverId);

    if (card) {
      card.file_url = await generatePresignedUrl(card.file_key || card.file_url);
    }

    res.json({ success: true, data: card || null });
  } catch (error) {
    console.error('[getOperatingCard] Error:', error);
    res.status(500).json({ success: false, message: 'تعذر جلب بيانات بطاقة التشغيل' });
  }
};

const uploadOperatingCard = async (req, res) => {
  try {
    const driverId = req.user.id;
    const { expiry_date } = req.body;

    if (!req.file) {
      return res.status(400).json({ success: false, message: 'يرجى اختيار ملف' });
    }

    if (!expiry_date) {
      await deleteS3Object(req.file.key).catch(() => {});
      return res.status(400).json({ success: false, message: 'تاريخ انتهاء الصلاحية مطلوب' });
    }

    const existingCard = await OperatingCard.findByDriverId(driverId);

    const cardData = {
      driver_id: driverId,
      file_url: req.file.location, // multer-s3 provides location
      file_key: req.file.key,
      file_type: req.file.mimetype,
      expiry_date: expiry_date
    };

    if (existingCard) {
      // Update existing
      await OperatingCard.update(existingCard.id, cardData);
      // Delete old file if key exists
      if (existingCard.file_key) {
        await deleteS3Object(existingCard.file_key).catch(() => {});
      }
    } else {
      // Create new
      await OperatingCard.create(cardData);
    }

    const updatedCard = await OperatingCard.findByDriverId(driverId);
    if (updatedCard) {
       updatedCard.file_url = await generatePresignedUrl(updatedCard.file_key);
    }

    res.json({
      success: true,
      message: 'تم رفع بطاقة التشغيل بنجاح، وهي بانتظار المراجعة',
      data: updatedCard
    });
  } catch (error) {
    console.error('[uploadOperatingCard] Error:', error);
    if (req.file) {
      await deleteS3Object(req.file.key).catch(() => {});
    }
    res.status(500).json({ success: false, message: 'تعذر رفع بطاقة التشغيل' });
  }
};

const deleteOperatingCard = async (req, res) => {
  try {
    const driverId = req.user.id;
    const card = await OperatingCard.findByDriverId(driverId);

    if (!card) {
      return res.status(404).json({ success: false, message: 'بطاقة التشغيل غير موجودة' });
    }

    await OperatingCard.delete(card.id);
    if (card.file_key) {
      await deleteS3Object(card.file_key).catch(() => {});
    }

    res.json({ success: true, message: 'تم حذف بطاقة التشغيل بنجاح' });
  } catch (error) {
    console.error('[deleteOperatingCard] Error:', error);
    res.status(500).json({ success: false, message: 'تعذر حذف بطاقة التشغيل' });
  }
};

// Admin section
const verifyOperatingCard = async (req, res) => {
  try {
    if (req.user.role !== 'admin') {
      return res.status(403).json({ success: false, message: 'غير مصرح للقيام بهذا الإجراء' });
    }

    const { id } = req.params;
    const { status, rejection_reason } = req.body;

    if (!['verified', 'rejected'].includes(status)) {
      return res.status(400).json({ success: false, message: 'حالة غير صالحة' });
    }

    await OperatingCard.updateStatus(id, { status, rejection_reason });
    res.json({ success: true, message: `تم ${status === 'verified' ? 'قبول' : 'رفض'} بطاقة التشغيل بنجاح` });
  } catch (error) {
    console.error('[verifyOperatingCard] Error:', error);
    res.status(500).json({ success: false, message: 'تعذر تحديث حالة بطاقة التشغيل' });
  }
};

module.exports = {
  getOperatingCard,
  uploadOperatingCard,
  deleteOperatingCard,
  verifyOperatingCard
};
