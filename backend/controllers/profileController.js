const User = require('../models/User');
const { encryptText } = require('../utils/encryption');
const {
  deleteS3Object,
  generatePresignedUrl,
  sanitizeApiErrorMessage,
} = require('../utils/s3Config');
const { buildProfileResponse } = require('../services/profileService');

const getAuthenticatedUserId = (req) => Number(req.user?.id || 0);

const getMyProfile = async (req, res) => {
  try {
    const userId = getAuthenticatedUserId(req);
    if (!userId) return res.status(401).json({ success: false, message: 'غير مصرح' });

    const profile = await buildProfileResponse(userId);
    if (!profile) return res.status(404).json({ success: false, message: 'المستخدم غير موجود' });

    return res.json({ success: true, data: profile });
  } catch (error) {
    console.error('[getMyProfile] Error:', error);
    return res.status(500).json({ success: false, message: 'تعذر تحميل الملف الشخصي' });
  }
};

const updateMyProfile = async (req, res) => {
  try {
    const userId = getAuthenticatedUserId(req);
    if (!userId) return res.status(401).json({ success: false, message: 'غير مصرح' });

    const existing = await User.findById(userId);
    if (!existing) return res.status(404).json({ success: false, message: 'المستخدم غير موجود' });

    const { fullName, email, phone, licenseNo, commercialNo } = req.body;
    await User.updateProfileFields(userId, {
      fullName: fullName?.toString().trim(),
      email: email?.toString().trim().toLowerCase(),
      phone: phone?.toString().trim(),
      licenseNo: licenseNo ? encryptText(licenseNo.toString().trim()) : existing.license_no,
      commercialNo: commercialNo ? encryptText(commercialNo.toString().trim()) : existing.commercial_no,
    });

    const profile = await buildProfileResponse(userId);
    return res.json({ success: true, data: profile, message: 'تم تحديث البيانات بنجاح' });
  } catch (error) {
    console.error('[updateMyProfile] Error:', error);
    return res.status(500).json({ success: false, message: 'تعذر تحديث الملف الشخصي' });
  }
};

const uploadProfileImage = async (req, res) => {
  const userId = getAuthenticatedUserId(req);
  const uploadedKey = req.file?.key || null;

  try {
    if (!userId) return res.status(401).json({ success: false, message: 'غير مصرح' });
    if (!uploadedKey) {
      return res.status(400).json({ success: false, message: 'لم يتم رفع صورة' });
    }

    const user = await User.findById(userId);
    if (!user) {
      await deleteS3Object(uploadedKey).catch(() => {});
      return res.status(404).json({ success: false, message: 'المستخدم غير موجود' });
    }

    const previousKey = user.profile_image_url || null;
    const updated = await User.updateProfileImage(userId, uploadedKey);
    if (!updated) {
      await deleteS3Object(uploadedKey).catch(() => {});
      return res.status(500).json({ success: false, message: 'تعذر حفظ الصورة' });
    }

    if (previousKey && previousKey !== uploadedKey) {
      deleteS3Object(previousKey).catch((error) => {
        console.warn('[uploadProfileImage] Could not delete previous image:', sanitizeApiErrorMessage(error.message));
      });
    }

    const profileImageUrl = await generatePresignedUrl(uploadedKey);
    return res.json({
      success: true,
      profileImageUrl,
      profile_image_url: profileImageUrl,
      profileImageKey: uploadedKey,
      message: 'تم تحديث الصورة بنجاح',
    });
  } catch (error) {
    if (uploadedKey) {
      await deleteS3Object(uploadedKey).catch(() => {});
    }
    console.error('[uploadProfileImage] Error:', error);
    return res.status(500).json({ success: false, message: 'تعذر رفع صورة الحساب' });
  }
};

const removeProfileImage = async (req, res) => {
  try {
    const userId = getAuthenticatedUserId(req);
    if (!userId) return res.status(401).json({ success: false, message: 'غير مصرح' });

    const user = await User.findById(userId);
    if (!user) return res.status(404).json({ success: false, message: 'المستخدم غير موجود' });

    const previousKey = user.profile_image_url || null;
    await User.updateProfileImage(userId, null);

    if (previousKey) {
      deleteS3Object(previousKey).catch((error) => {
        console.warn('[removeProfileImage] Could not delete previous image:', sanitizeApiErrorMessage(error.message));
      });
    }

    return res.json({
      success: true,
      profileImageUrl: null,
      profile_image_url: null,
      profileImageKey: null,
      message: 'تم حذف الصورة بنجاح',
    });
  } catch (error) {
    console.error('[removeProfileImage] Error:', error);
    return res.status(500).json({ success: false, message: 'تعذر حذف صورة الحساب' });
  }
};

module.exports = {
  getMyProfile,
  updateMyProfile,
  uploadProfileImage,
  removeProfileImage,
};
