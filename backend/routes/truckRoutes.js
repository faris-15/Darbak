const express = require('express');

const { body, validationResult } = require('express-validator');

const {

  registerTruck,

  getTruckByDriver,

  updateTruck,

  setActiveTruck,

  uploadTruckInsurance,

  deleteTruck,

  listPendingTrucks,

  verifyTruck,

} = require('../controllers/truckController');

const { getTruckClassificationCatalog } = require('../controllers/truckClassificationController');

const { validateTruckClassificationMiddleware } = require('../utils/truckClassificationValidator');

const { upload, logS3SdkErrorResponsePreview, sanitizeApiErrorMessage } = require('../utils/s3Config');

const { requireAuth } = require('../middleware/authMiddleware');

const router = express.Router();



const handleInsuranceUpload = (req, res, next) => {

  upload.single('insurance')(req, res, async (err) => {

    if (err) {

      console.error('[Truck insurance upload error]:', err);

      await logS3SdkErrorResponsePreview(err);

      return res.status(400).json({

        success: false,

        message: 'خطأ في رفع ملف التأمين: ' + sanitizeApiErrorMessage(err.message),

      });

    }

    next();

  });

};



const classificationFieldsValidator = [

  body('category').optional().isString().notEmpty(),

  body('axle_count').optional().isInt({ min: 1, max: 10 }),

  body('body_type').optional().isString().notEmpty(),

  body('payload_capacity').optional().isString().notEmpty(),

  body('max_weight_tons').optional().isFloat({ min: 0.5, max: 120 }),

  body('truck_type').optional().isString(),

  body('truckType').optional().isString(),

];



const addTruckValidators = [

  body('plate_number').notEmpty(),

  body('isthimara_no').notEmpty(),

  ...classificationFieldsValidator,

  body('capacity_kg').optional().isFloat({ min: 0 }),

];



router.get('/catalog', getTruckClassificationCatalog);



router.post(

  '/register',

  requireAuth,

  addTruckValidators,

  (req, res, next) => {

    const errors = validationResult(req);

    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

    next();

  },

  validateTruckClassificationMiddleware(true),

  registerTruck

);



router.post(

  '/add',

  requireAuth,

  addTruckValidators,

  (req, res, next) => {

    const errors = validationResult(req);

    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

    next();

  },

  validateTruckClassificationMiddleware(true),

  registerTruck

);



router.get('/my', requireAuth, getTruckByDriver);



router.post('/insurance', requireAuth, (_req, res) => {

  res.status(400).json({ message: 'يجب رفع التأمين من بطاقة الشاحنة المحددة' });

});



router.post('/:truckId/insurance', requireAuth, handleInsuranceUpload, uploadTruckInsurance);



router.patch('/:truckId/active', requireAuth, setActiveTruck);



router.put(

  '/:truckId',

  requireAuth,

  [

    body('isthimara_no').optional().notEmpty(),

    body('plate_number').optional().notEmpty(),

    ...classificationFieldsValidator,

    body('capacity_kg').optional().isFloat({ min: 0 }),

    body('manufacturing_year').optional().isInt({ min: 1900 }),

    body('insurance_expiry_date').optional().isISO8601(),

  ],

  (req, res, next) => {

    const errors = validationResult(req);

    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

    const hasClassification =

      req.body.category ||

      req.body.axle_count != null ||

      req.body.body_type ||

      req.body.payload_capacity ||

      req.body.max_weight_tons != null ||

      req.body.truck_type ||

      req.body.truckType;

    if (hasClassification) {

      return validateTruckClassificationMiddleware(true)(req, res, next);

    }

    return next();

  },

  updateTruck

);



router.delete('/:truckId', requireAuth, deleteTruck);



router.get('/admin/pending', requireAuth, listPendingTrucks);

router.post('/admin/:truckId/verify', requireAuth, [body('status').isIn(['verified', 'rejected'])], (req, res) => {

  const errors = validationResult(req);

  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

  verifyTruck(req, res);

});



module.exports = router;
