const pool = require('../config/db');

const { ensureTruckInsuranceSchema } = require('../utils/truckInsuranceSchema');

const { ensureTruckClassificationSchema } = require('../utils/truckClassificationSchema');



const baseTruckListQuery = 'SELECT * FROM trucks WHERE user_id = ? ORDER BY is_active DESC, created_at DESC';



const Truck = {

  create: async ({

    user_id,

    plate_number,

    isthimara_no,

    truck_type,

    category,

    axle_count,

    body_type,

    payload_capacity,

    max_weight_tons,

    capacity_kg,

    manufacturing_year,

    insurance_expiry_date,

    is_active = false,

  }) => {

    await ensureTruckClassificationSchema();

    const connection = await pool.getConnection();

    try {

      await connection.beginTransaction();

      const shouldBeActive = is_active ? 1 : 0;

      if (shouldBeActive) {

        await connection.execute('UPDATE trucks SET is_active = 0 WHERE user_id = ?', [user_id]);

      }

      const [result] = await connection.execute(

        `INSERT INTO trucks (

           user_id, plate_number, isthimara_no, truck_type,

           category, axle_count, body_type, payload_capacity, max_weight_tons,

           capacity_kg, manufacturing_year, insurance_expiry_date, verification_status, is_active

         ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,

        [

          user_id,

          plate_number,

          isthimara_no,

          truck_type,

          category,

          axle_count,

          body_type,

          payload_capacity,

          max_weight_tons,

          capacity_kg,

          manufacturing_year,

          insurance_expiry_date,

          'pending',

          shouldBeActive,

        ]

      );

      await connection.commit();

      return {

        id: result.insertId,

        user_id,

        plate_number,

        isthimara_no,

        truck_type,

        category,

        axle_count,

        body_type,

        payload_capacity,

        max_weight_tons,

        capacity_kg,

        manufacturing_year,

        insurance_expiry_date,

        is_active: !!shouldBeActive,

        verification_status: 'pending',

      };

    } catch (error) {

      await connection.rollback();

      throw error;

    } finally {

      connection.release();

    }

  },



  listByDriverId: async (user_id) => {

    try {

      await ensureTruckInsuranceSchema();

      await ensureTruckClassificationSchema();

      const [rows] = await pool.execute(

        `SELECT

           t.*,

           cd.document_id AS insurance_document_id,

           cd.document_url AS insurance_document_url,

           cd.expiry_date AS insurance_document_expiry_date,

           cd.uploaded_at AS insurance_uploaded_at,

           cd.is_verified AS insurance_document_verified

         FROM trucks t

         LEFT JOIN compliance_documents cd

           ON cd.document_id = (

             SELECT cd2.document_id

             FROM compliance_documents cd2

             WHERE cd2.user_id = t.user_id

               AND cd2.truck_id = t.id

               AND cd2.document_type = 'vehicle_insurance'

             ORDER BY cd2.uploaded_at DESC, cd2.created_at DESC, cd2.document_id DESC

             LIMIT 1

           )

         WHERE t.user_id = ?

         ORDER BY t.is_active DESC, t.created_at DESC`,

        [user_id]

      );

      return rows;

    } catch (error) {

      console.warn('[Truck.listByDriverId] Falling back without insurance join:', error.message);

      const [rows] = await pool.execute(baseTruckListQuery, [user_id]);

      return rows.map((truck) => ({

        ...truck,

        insurance_document_id: null,

        insurance_document_url: null,

        insurance_document_expiry_date: null,

        insurance_uploaded_at: null,

        insurance_document_verified: null,

      }));

    }

  },



  findById: async (id) => {

    await ensureTruckClassificationSchema();

    const [rows] = await pool.execute('SELECT * FROM trucks WHERE id = ?', [id]);

    return rows[0];

  },



  countByDriverId: async (user_id) => {

    const [rows] = await pool.execute('SELECT COUNT(*) AS cnt FROM trucks WHERE user_id = ?', [user_id]);

    return Number(rows[0]?.cnt ?? 0);

  },



  findByPlateNumber: async (plate_number) => {

    const [rows] = await pool.execute('SELECT * FROM trucks WHERE plate_number = ? LIMIT 1', [plate_number]);

    return rows[0];

  },

  findActiveByDriverId: async (user_id) => {

    const [rows] = await pool.execute(

      'SELECT * FROM trucks WHERE user_id = ? AND is_active = 1 ORDER BY id DESC LIMIT 1',

      [user_id]

    );

    return rows[0] || null;

  },



  update: async (

    id,

    {

      plate_number,

      isthimara_no,

      truck_type,

      category,

      axle_count,

      body_type,

      payload_capacity,

      max_weight_tons,

      capacity_kg,

      manufacturing_year,

      insurance_expiry_date,

      is_active,

    }

  ) => {

    await ensureTruckClassificationSchema();

    const connection = await pool.getConnection();

    try {

      await connection.beginTransaction();

      const [[truck]] = await connection.execute('SELECT user_id FROM trucks WHERE id = ? LIMIT 1', [id]);

      if (!truck) {

        await connection.rollback();

        return false;

      }

      if (is_active) {

        await connection.execute('UPDATE trucks SET is_active = 0 WHERE user_id = ?', [truck.user_id]);

      }

      const [result] = await connection.execute(

        `UPDATE trucks SET

           plate_number = ?,

           isthimara_no = ?,

           truck_type = ?,

           category = ?,

           axle_count = ?,

           body_type = ?,

           payload_capacity = ?,

           max_weight_tons = ?,

           capacity_kg = ?,

           manufacturing_year = ?,

           insurance_expiry_date = ?,

           is_active = ?

         WHERE id = ?`,

        [

          plate_number,

          isthimara_no,

          truck_type,

          category,

          axle_count,

          body_type,

          payload_capacity,

          max_weight_tons,

          capacity_kg,

          manufacturing_year,

          insurance_expiry_date,

          is_active ? 1 : 0,

          id,

        ]

      );

      await connection.commit();

      return result.affectedRows > 0;

    } catch (error) {

      await connection.rollback();

      throw error;

    } finally {

      connection.release();

    }

  },



  setActiveForDriver: async (id, user_id) => {

    const connection = await pool.getConnection();

    try {

      await connection.beginTransaction();

      const [[truck]] = await connection.execute(

        'SELECT id FROM trucks WHERE id = ? AND user_id = ? LIMIT 1',

        [id, user_id]

      );

      if (!truck) {

        await connection.rollback();

        return false;

      }

      await connection.execute('UPDATE trucks SET is_active = 0 WHERE user_id = ?', [user_id]);

      const [result] = await connection.execute(

        'UPDATE trucks SET is_active = 1 WHERE id = ? AND user_id = ?',

        [id, user_id]

      );

      await connection.commit();

      return result.affectedRows > 0;

    } catch (error) {

      await connection.rollback();

      throw error;

    } finally {

      connection.release();

    }

  },



  verifyTruck: async (id, status) => {

    const [result] = await pool.execute('UPDATE trucks SET verification_status = ? WHERE id = ?', [status, id]);

    return result.affectedRows > 0;

  },



  list: async () => {

    const [rows] = await pool.execute('SELECT * FROM trucks ORDER BY created_at DESC');

    return rows;

  },



  listPending: async () => {

    const [rows] = await pool.execute(

      'SELECT * FROM trucks WHERE verification_status = "pending" ORDER BY created_at ASC'

    );

    return rows;

  },

};



module.exports = Truck;
