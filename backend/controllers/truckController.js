const Truck = require('../models/Truck');
const User = require('../models/User');

const registerTruck = async (req, res) => {
  try {
    const { user_id, plate_number, truck_type, capacity_kg, manufacturing_year, insurance_expiry_date } = req.body;

    // Validate required fields
    if (!user_id || !plate_number || !truck_type || !capacity_kg) {
      return res.status(400).json({ message: 'جميع الحقول المطلوبة يجب ملؤها' });
    }

    // Check if driver exists
    const driver = await User.findById(user_id);
    if (!driver || driver.role !== 'driver') {
      return res.status(404).json({ message: 'السائق غير موجود أو غير صحيح' });
    }

    // Check if driver already has a truck
    const existingTruck = await Truck.findByDriverId(user_id);
    if (existingTruck) {
      return res.status(400).json({ message: 'لديك شاحنة مسجلة بالفعل' });
    }

    const truck = await Truck.create({
      user_id,
      plate_number,
      truck_type,
      capacity_kg: Number(capacity_kg),
      manufacturing_year,
      insurance_expiry_date,
    });

    res.status(201).json(truck);
  } catch (error) {
    console.error('Register truck error:', error);
    res.status(500).json({ message: 'خطأ في تسجيل الشاحنة' });
  }
};

const getTruckByDriver = async (req, res) => {
  try {
    const { driverId } = req.params;

    const truck = await Truck.findByDriverId(driverId);
    if (!truck) {
      return res.status(404).json({ message: 'لا توجد شاحنة مسجلة لهذا السائق' });
    }

    res.json(truck);
  } catch (error) {
    console.error('Get truck error:', error);
    res.status(500).json({ message: 'خطأ في جلب بيانات الشاحنة' });
  }
};

const updateTruck = async (req, res) => {
  try {
    const { truckId } = req.params;
    const { plate_number, truck_type, capacity_kg, manufacturing_year, insurance_expiry_date } = req.body;

    const truck = await Truck.findById(truckId);
    if (!truck) {
      return res.status(404).json({ message: 'الشاحنة غير موجودة' });
    }

    const updated = await Truck.update(truckId, {
      plate_number: plate_number || truck.plate_number,
      truck_type: truck_type || truck.truck_type,
      capacity_kg: capacity_kg ? Number(capacity_kg) : truck.capacity_kg,
      manufacturing_year: manufacturing_year || truck.manufacturing_year,
      insurance_expiry_date: insurance_expiry_date || truck.insurance_expiry_date,
    });

    if (!updated) {
      return res.status(400).json({ message: 'فشل تحديث الشاحنة' });
    }

    const updatedTruck = await Truck.findById(truckId);
    res.json(updatedTruck);
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
    const trucks = await Truck.listPending();
    res.json(trucks);
  } catch (error) {
    console.error('List pending trucks error:', error);
    res.status(500).json({ message: 'خطأ في جلب الشاحنات المعلقة' });
  }
};

const verifyTruck = async (req, res) => {
  try {
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
