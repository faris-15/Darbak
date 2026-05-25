const User = require('../models/User');
const Rating = require('../models/Rating');
const Shipment = require('../models/Shipment');
const ComplianceDocument = require('../models/ComplianceDocument');
const { decryptText } = require('../utils/encryption');
const { generatePresignedUrl } = require('../utils/s3Config');

const formatRatingValue = (value) => {
  const rating = Number(value ?? 0);
  return Number.isFinite(rating) ? rating.toFixed(2) : '0.00';
};

async function resolveProfileImage(keyOrUrl) {
  if (!keyOrUrl) return null;
  return generatePresignedUrl(keyOrUrl);
}

async function signProfileImageFields(row, {
  keyField = 'profile_image_url',
  urlField = 'profileImageUrl',
  rawKeyField = 'profileImageKey',
} = {}) {
  const key = row?.[keyField] || null;
  return {
    ...row,
    [urlField]: key ? await resolveProfileImage(key) : null,
    [rawKeyField]: key,
  };
}

async function buildProfileResponse(userId) {
  const user = await User.findById(userId);
  if (!user) return null;

  const licenseNo = user.license_no ? decryptText(user.license_no) : null;
  const commercialNo = user.commercial_no ? decryptText(user.commercial_no) : null;

  let stats = {};
  if (user.role === 'driver') {
    const tripStats = await Shipment.getDriverStats(userId);
    stats = {
      completed_trips: tripStats.completed_trips,
      total_earnings: tripStats.total_earnings,
    };
  } else if (user.role === 'shipper') {
    const shipperStats = await Shipment.getShipperStats(userId);
    stats = {
      total_shipments: shipperStats.total_shipments,
      delivered_shipments: shipperStats.delivered_shipments,
      active_shipments: shipperStats.active_shipments,
    };
  }

  let ratingBlock = {};
  try {
    const avg = await Rating.getAverageRating(userId);
    const averageRating = formatRatingValue(avg.average_rating);
    ratingBlock = {
      average_rating: averageRating,
      ratings_total: Number(avg.total_ratings) || 0,
      rating: averageRating,
    };
  } catch (_) {
    ratingBlock = { average_rating: '0.00', ratings_total: 0, rating: '0.00' };
  }

  let complianceDocuments = [];
  let documentsByType = {};
  try {
    complianceDocuments = await ComplianceDocument.findByUserId(userId);
    documentsByType = complianceDocuments.reduce((acc, doc) => {
      if (!acc[doc.document_type]) {
        acc[doc.document_type] = doc;
      }
      return acc;
    }, {});
  } catch (docError) {
    console.warn('[profileService] Could not load compliance documents:', docError.message);
  }

  const profileImageKey = user.profile_image_url || null;
  const profileImageUrl = profileImageKey ? await resolveProfileImage(profileImageKey) : null;

  return {
    id: user.id,
    full_name: user.full_name,
    email: user.email,
    phone: user.phone,
    role: user.role,
    license_no: licenseNo,
    commercial_no: commercialNo,
    document_path: user.document_path,
    issue_date: user.issue_date,
    expiry_date: user.expiry_date,
    verification_status: user.verification_status,
    is_active: user.is_active,
    created_at: user.created_at,
    profile_image_url: profileImageUrl,
    profileImageUrl,
    profileImageKey,
    compliance_documents: complianceDocuments,
    documents: documentsByType,
    vehicle_insurance_document_url: documentsByType.vehicle_insurance?.document_url || null,
    vehicle_insurance_document_id: documentsByType.vehicle_insurance?.document_id || null,
    ...stats,
    ...ratingBlock,
  };
}

/**
 * ملخص عام لبطاقة «من تُقيِّم» (شاشة التقييمات) — بدون بيانات حساسة.
 * يعتمد على جدول users: full_name, role, profile_image_url (مفتاح S3).
 */
async function buildReviewTargetPublicProfile(userId) {
  const user = await User.findById(userId);
  if (!user) return null;

  const profileImageKey = user.profile_image_url || null;
  let profile_image = null;
  if (profileImageKey) {
    try {
      profile_image = await resolveProfileImage(profileImageKey);
    } catch (e) {
      console.warn('[buildReviewTargetPublicProfile] presign failed:', e.message);
    }
  }
  const role = user.role === 'driver' ? 'driver' : 'shipper';

  return {
    id: user.id,
    name: (user.full_name && String(user.full_name).trim()) || 'مستخدم',
    profile_image,
    profileImageKey,
    role,
    role_label_ar: role === 'driver' ? 'سائق' : 'شركة',
  };
}

module.exports = {
  buildProfileResponse,
  buildReviewTargetPublicProfile,
  resolveProfileImage,
  signProfileImageFields,
};
