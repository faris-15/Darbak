const Truck = require('../models/Truck');

const User = require('../models/User');

const ComplianceDocument = require('../models/ComplianceDocument');

const { encryptText, decryptText } = require('../utils/encryption');

const { deleteS3Object } = require('../utils/s3Config');

const {
  validateTruckClassification,
  resolveTruckClassification,
} = require('../utils/truckClassificationValidator');



const MAX_TRUCKS_PER_DRIVER = 5;



const buildTruckDefaults = () => {

  const now = new Date();

  return {

    manufacturingYear: now.getFullYear(),

    insuranceExpiryDate: new Date(now.getFullYear() + 1, now.getMonth(), now.getDate())

      .toISOString()

      .split('T')[0],

  };

};



function mapTruckResponse(truck, isthimaraPlain = null) {

  if (!truck) return truck;

  return {

    ...truck,

    isthimara_no:

      isthimaraPlain ??

      (truck.isthimara_no ? decryptText(truck.isthimara_no) : null),

    classification: {

      category: truck.category,

      axle_count: truck.axle_count,

      body_type: truck.body_type,

      payload_capacity: truck.payload_capacity,

      max_weight_tons: truck.max_weight_tons != null ? Number(truck.max_weight_tons) : null,

    },

  };

}



const registerTruck = async (req, res) => {

  try {

    const {

      plate_number,

      isthimara_no,

      capacity_kg,

      manufacturing_year,

      insurance_expiry_date,

      is_active,

    } = req.body;

    const user_id = req.user?.id;



    const classificationResult = resolveTruckClassification(req, req.body, {
      requireAll: true,
    });

    if (!classificationResult.ok) {

      return res.status(400).json({

        message:
          classificationResult.errors?.[0] ||
          'بيانات تصنيف الشاحنة غير صالحة',

        errors: classificationResult.errors || [],

      });

    }

    const classification = classificationResult.data;



    if (!user_id || !plate_number || !isthimara_no) {

      return res.status(400).json({ message: 'جميع الحقول المطلوبة يجب ملؤها' });

    }

    if (req.user?.role !== 'driver') {

      return res.status(403).json({ message: 'فقط السائق يمكنه تسجيل شاحنة' });

    }



    const driver = await User.findById(user_id);

    if (!driver || driver.role !== 'driver') {

      return res.status(404).json({ message: 'السائق غير موجود أو غير صحيح' });

    }



    const truckCount = await Truck.countByDriverId(user_id);

    if (truckCount >= MAX_TRUCKS_PER_DRIVER) {

      return res.status(400).json({ message: 'وصلت للحد الأقصى من الشاحنات' });

    }



    const existingByPlate = await Truck.findByPlateNumber(plate_number.trim());

    if (existingByPlate) {

      return res.status(400).json({ message: 'رقم اللوحة مستخدم مسبقاً' });

    }

    const defaults = buildTruckDefaults();

    const plainIsthimara = isthimara_no.trim();



    const truck = await Truck.create({

      user_id,

      plate_number: plate_number.trim(),

      isthimara_no: encryptText(plainIsthimara),

      ...classification,

      capacity_kg: capacity_kg != null ? Number(capacity_kg) : classification.capacity_kg,

      manufacturing_year: manufacturing_year || defaults.manufacturingYear,

      insurance_expiry_date: insurance_expiry_date || defaults.insuranceExpiryDate,

      is_active: truckCount === 0 || !!is_active,

    });



    res.status(201).json(mapTruckResponse(truck, plainIsthimara));

  } catch (error) {

    console.error('Register truck error:', error);

    res.status(500).json({ message: 'خطأ في تسجيل الشاحنة' });

  }

};



const getTruckByDriver = async (req, res) => {

  try {

    const driverId = req.user?.id;

    if (req.user?.role !== 'driver') {

      return res.status(403).json({ message: 'فقط السائق يمكنه الوصول لشاحناته' });

    }



    const trucks = await Truck.listByDriverId(driverId);



    res.json((trucks || []).map((truck) => mapTruckResponse(truck)));

  } catch (error) {

    console.error('Get truck error:', error);

    res.status(500).json({ message: 'خطأ في جلب بيانات الشاحنة' });

  }

};



const updateTruck = async (req, res) => {

  try {

    const { truckId } = req.params;

    const {

      plate_number,

      isthimara_no,

      capacity_kg,

      manufacturing_year,

      insurance_expiry_date,

      is_active,

      category,

      axle_count,

      body_type,

      payload_capacity,

      max_weight_tons,

      truck_type,

    } = req.body;



    if (req.user?.role !== 'driver') {

      return res.status(403).json({ message: 'فقط السائق يمكنه تعديل الشاحنة' });

    }



    const truck = await Truck.findById(truckId);

    if (!truck) {

      return res.status(404).json({ message: 'الشاحنة غير موجودة' });

    }

    if (Number(truck.user_id) !== Number(req.user.id)) {

      return res.status(403).json({ message: 'لا يمكنك تعديل هذه الشاحنة' });

    }

    if (plate_number && plate_number.trim() !== truck.plate_number) {

      const existingByPlate = await Truck.findByPlateNumber(plate_number.trim());

      if (existingByPlate && Number(existingByPlate.id) !== Number(truckId)) {

        return res.status(400).json({ message: 'رقم اللوحة مستخدم مسبقاً' });

      }

    }



    const hasClassificationPatch =

      category ||

      axle_count != null ||

      body_type ||

      payload_capacity ||

      max_weight_tons != null ||

      truck_type;



    let classification = {

      category: truck.category,

      axle_count: truck.axle_count,

      body_type: truck.body_type,

      payload_capacity: truck.payload_capacity,

      max_weight_tons: truck.max_weight_tons,

      truck_type: truck.truck_type,

      capacity_kg: truck.capacity_kg,

    };



    if (hasClassificationPatch) {

      const classificationResult = resolveTruckClassification(
        req,
        {
          category: category ?? truck.category,
          axle_count: axle_count ?? truck.axle_count,
          body_type: body_type ?? truck.body_type,
          payload_capacity: payload_capacity ?? truck.payload_capacity,
          max_weight_tons: max_weight_tons ?? truck.max_weight_tons,
          truck_type,
        },
        { requireAll: true }
      );

      if (!classificationResult.ok) {

        return res.status(400).json({

          message:
            classificationResult.errors?.[0] ||
            'بيانات تصنيف الشاحنة غير صالحة',

          errors: classificationResult.errors || [],

        });

      }

      classification = classificationResult.data;

    }



    const updated = await Truck.update(truckId, {

      plate_number: plate_number?.trim() || truck.plate_number,

      isthimara_no:

        typeof isthimara_no === 'string' && isthimara_no.trim().length

          ? encryptText(isthimara_no.trim())

          : truck.isthimara_no,

      truck_type: classification.truck_type,

      category: classification.category,

      axle_count: classification.axle_count,

      body_type: classification.body_type,

      payload_capacity: classification.payload_capacity,

      max_weight_tons: classification.max_weight_tons,

      capacity_kg: capacity_kg != null ? Number(capacity_kg) : classification.capacity_kg,

      manufacturing_year: manufacturing_year || truck.manufacturing_year,

      insurance_expiry_date: insurance_expiry_date || truck.insurance_expiry_date,

      is_active: typeof is_active === 'boolean' ? is_active : !!truck.is_active,

    });



    if (!updated) {

      return res.status(400).json({ message: 'فشل تحديث الشاحنة' });

    }



    const updatedTruck = await Truck.findById(truckId);

    res.json(mapTruckResponse(updatedTruck));

  } catch (error) {

    console.error('Update truck error:', error);

    res.status(500).json({ message: 'خطأ في تحديث الشاحنة' });

  }

};



const setActiveTruck = async (req, res) => {

  try {

    const { truckId } = req.params;

    const userId = req.user?.id;



    if (!userId) {

      return res.status(401).json({ message: 'غير مصرح' });

    }

    if (req.user?.role !== 'driver') {

      return res.status(403).json({ message: 'فقط السائق يمكنه تحديد الشاحنة النشطة' });

    }



    const updated = await Truck.setActiveForDriver(truckId, userId);

    if (!updated) {

      return res.status(404).json({ message: 'الشاحنة غير موجودة' });

    }



    const trucks = await Truck.listByDriverId(userId);

    return res.json({

      success: true,

      message: 'تم تحديد الشاحنة النشطة',

      data: trucks.map((t) => mapTruckResponse(t)),

    });

  } catch (error) {

    console.error('Set active truck error:', error);

    return res.status(500).json({ message: 'خطأ في تحديد الشاحنة النشطة' });

  }

};



const uploadTruckInsurance = async (req, res) => {

  const userId = req.user?.id;

  const { truckId } = req.params;

  const uploadedKey = req.file?.key;

  const cleanupUploadedFile = async () => {

    if (!uploadedKey) return;

    try {

      await deleteS3Object(uploadedKey);

    } catch (cleanupError) {

      console.error('[Truck insurance cleanup error]:', cleanupError);

    }

  };



  try {

    if (!userId) {

      await cleanupUploadedFile();

      return res.status(401).json({ message: 'غير مصرح' });

    }

    if (req.user?.role !== 'driver') {

      await cleanupUploadedFile();

      return res.status(403).json({ message: 'فقط السائق يمكنه رفع تأمين الشاحنة' });

    }

    if (!uploadedKey) {

      return res.status(400).json({ message: 'ملف التأمين مطلوب' });

    }

    if (!truckId) {

      await cleanupUploadedFile();

      return res.status(400).json({ message: 'اختر الشاحنة قبل رفع التأمين' });

    }



    const [driver, truck] = await Promise.all([User.findById(userId), Truck.findById(truckId)]);

    if (!driver || driver.role !== 'driver') {

      await cleanupUploadedFile();

      return res.status(404).json({ message: 'السائق غير موجود أو غير صحيح' });

    }

    if (!truck || Number(truck.user_id) !== Number(userId)) {

      await cleanupUploadedFile();

      return res.status(404).json({ message: 'الشاحنة غير موجودة' });

    }



    const expiryDate =

      typeof req.body?.expiry_date === 'string' && req.body.expiry_date.trim()

        ? req.body.expiry_date.trim()

        : '2099-12-31';



    const documentId = await ComplianceDocument.create({

      user_id: userId,

      truck_id: truckId,

      document_type: 'vehicle_insurance',

      document_url: uploadedKey,

      issue_date: null,

      expiry_date: expiryDate,

    });



    return res.status(201).json({

      success: true,

      message: 'تم رفع تأمين الشاحنة بنجاح',

      data: {

        document_id: documentId,

        truck_id: Number(truckId),

        document_type: 'vehicle_insurance',

        document_url: uploadedKey,

        expiry_date: expiryDate,

      },

    });

  } catch (error) {

    await cleanupUploadedFile();

    console.error('Upload truck insurance error:', error);

    return res.status(500).json({ message: 'خطأ في رفع تأمين الشاحنة' });

  }

};



const deleteTruck = async (req, res) => {

  try {

    const { truckId } = req.params;



    const truck = await Truck.findById(truckId);

    if (!truck) {

      return res.status(404).json({ message: 'الشاحنة غير موجودة' });

    }

    if (Number(truck.user_id) !== Number(req.user.id)) {

      return res.status(403).json({ message: 'لا يمكنك حذف هذه الشاحنة' });

    }



    await Truck.verifyTruck(truckId, 'rejected');



    res.json({ message: 'تم حذف الشاحنة بنجاح' });

  } catch (error) {

    console.error('Delete truck error:', error);

    res.status(500).json({ message: 'خطأ في حذف الشاحنة' });

  }

};



const listPendingTrucks = async (req, res) => {

  try {

    if (req.user?.role !== 'admin') {

      return res.status(403).json({ message: 'Forbidden' });

    }

    const trucks = await Truck.listPending();

    res.json(trucks);

  } catch (error) {

    console.error('List pending trucks error:', error);

    res.status(500).json({ message: 'خطأ في جلب الشاحنات المعلقة' });

  }

};



const verifyTruck = async (req, res) => {

  try {

    if (req.user?.role !== 'admin') {

      return res.status(403).json({ message: 'Forbidden' });

    }

    const { truckId } = req.params;

    const { status } = req.body;



    if (!['verified', 'rejected'].includes(status)) {

      return res.status(400).json({ message: 'حالة التحقق غير صحيحة' });

    }



    const updated = await Truck.verifyTruck(truckId, status);

    if (!updated) {

      return res.status(404).json({ message: 'الشاحنة غير موجودة' });

    }



    res.json({ message: `تم ${status === 'verified' ? 'تحقق' : 'رفض'} الشاحنة بنجاح` });

  } catch (error) {

    console.error('Verify truck error:', error);

    res.status(500).json({ message: 'خطأ في التحقق من الشاحنة' });

  }

};



module.exports = {

  registerTruck,

  getTruckByDriver,

  updateTruck,

  setActiveTruck,

  uploadTruckInsurance,

  deleteTruck,

  listPendingTrucks,

  verifyTruck,

};
