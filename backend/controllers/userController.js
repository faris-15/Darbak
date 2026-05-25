const { buildReviewTargetPublicProfile } = require('../services/profileService');

const getAuthenticatedUserId = (req) => Number(req.user?.id || 0);

/**
 * GET /api/users/:id/profile — بيانات العرض لبطاقة المستخدم في شاشة التقييم.
 */
const getUserPublicProfile = async (req, res) => {
  try {
    const requesterId = getAuthenticatedUserId(req);
    if (!requesterId) {
      return res.status(401).json({ success: false, message: 'غير مصرح' });
    }

    const rawId = req.params.id;
    const targetId = Number.parseInt(String(rawId), 10);
    if (!Number.isFinite(targetId) || targetId < 1) {
      return res.status(400).json({ success: false, message: 'معرّف المستخدم غير صالح' });
    }

    const profile = await buildReviewTargetPublicProfile(targetId);
    if (!profile) {
      return res.status(404).json({ success: false, message: 'المستخدم غير موجود' });
    }

    return res.json({ success: true, data: profile });
  } catch (error) {
    console.error('[getUserPublicProfile] Error:', error);
    return res.status(500).json({ success: false, message: 'تعذر تحميل بيانات المستخدم' });
  }
};

module.exports = {
  getUserPublicProfile,
};
