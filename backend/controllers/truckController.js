const Truck = require('../models/Truck');
const User = require('../models/User');
const { encryptText, decryptText } = require('../utils/encryption');

const MAX_TRUCKS_PER_DRIVER = 5;
const buildTruckDefaults = () => {
  const now = new Date();
  return {
    manufacturingYear: now.getFullYear(),
    insuranceExpiryDate: new Date(
      now.getFullYear() + 1,
      now.getMonth(),
      now.getDate()
    )
      .toISOString()
      .split('T')[0],
  };
};

const registerTruck = async (req, res) => {
  try {
    const { plate_number, isthimara_no, truck_type, capacity_kg, manufacturing_year, insurance_expiry_date, is_active } = req.body;
    const user_id = req.user?.id;

    // Validate required fields
    if (!user_id || !plate_number || !isthimara_no || !truck_type) {
      return res.status(400).json({ message: 'جميع الحقول المطلوبة يجب ملؤها' });
    }
    if (req.user?.role !== 'driver') {
      return res.status(403).json({ message: 'فقط السائق يمكنه تسجيل شاحنة' });
    }

    // Check if driver exists
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

    const truck = await Truck.create({
      user_id,
      plate_number: plate_number.trim(),
      isthimara_no: encryptText(isthimara_no.trim()),
      truck_type,
      capacity_kg: Number(capacity_kg ?? 0),
      manufacturing_year: manufacturing_year || defaults.manufacturingYear,
      insurance_expiry_date: insurance_expiry_date || defaults.insuranceExpiryDate,
      is_active: !!is_active,
    });

    res.status(201).json({
      ...truck,
      isthimara_no: isthimara_no.trim(),
    });
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
    if (!trucks.length) {
      return res.status(404).json({ message: 'لا توجد شاحنة مسجلة لهذا السائق' });
    }

    res.json(
      trucks.map((truck) => ({
        ...truck,
        isthimara_no: truck.isthimara_no ? decryptText(truck.isthimara_no) : null,
      }))
    );
  } catch (error) {
    console.error('Get truck error:', error);
    res.status(500).json({ message: 'خطأ في جلب بيانات الشاحنة' });
  }
};

const updateTruck = async (req, res) => {
  try {
    const { truckId } = req.params;
    const { plate_number, isthimara_no, truck_type, capacity_kg, manufacturing_year, insurance_expiry_date, is_active } = req.body;
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

    const updated = await Truck.update(truckId, {
      plate_number: plate_number?.trim() || truck.plate_number,
      isthimara_no: typeof isthimara_no === 'string' && isthimara_no.trim().length
        ? encryptText(isthimara_no.trim())
        : truck.isthimara_no,
      truck_type: truck_type || truck.truck_type,
      capacity_kg: capacity_kg ? Number(capacity_kg) : truck.capacity_kg,
      manufacturing_year: manufacturing_year || truck.manufacturing_year,
      insurance_expiry_date: insurance_expiry_date || truck.insurance_expiry_date,
      is_active: typeof is_active === 'boolean' ? is_active : !!truck.is_active,
    });

    if (!updated) {
      return res.status(400).json({ message: 'فشل تحديث الشاحنة' });
    }

    const updatedTruck = await Truck.findById(truckId);
    res.json({
      ...updatedTruck,
      isthimara_no: updatedTruck.isthimara_no ? decryptText(updatedTruck.isthimara_no) : null,
    });
  } catch (error) {
    console.error('Update truck error:', error);
    res.status(500).json({ message: 'خطأ في تحديث الشاحنة' });
  }
};

const deleteTruck = async (req, res) => {
  try {
    const { truckId } = req.params;

    // Delete truck (cannot delete if truck is linked to active shipments)
    const truck = await Truck.findById(truckId);
    if (Number(truck.user_id) !== Number(req.user.id)) {
      return res.status(403).json({ message: 'لا يمكنك حذف هذه الشاحنة' });
    }
    if (!truck) {
      return res.status(404).json({ message: 'الشاحنة غير موجودة' });
    }

    // Simply set verification_status to rejected to "delete"
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

module.exports = { registerTruck, getTruckByDriver, updateTruck, deleteTruck, listPendingTrucks, verifyTruck };
