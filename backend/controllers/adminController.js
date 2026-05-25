const bcrypt = require('bcryptjs');
const pool = require('../config/db');
const { GetObjectCommand } = require('@aws-sdk/client-s3');
const { s3, generatePresignedUrl, resolveS3ObjectKey } = require('../utils/s3Config');
const User = require('../models/User');
const { emitAdminDashboard } = require('../utils/adminRealtime');

function previewKindFromKey(key) {
    const low = String(key || '').toLowerCase();
    if (low.endsWith('.pdf')) return 'pdf';
    if (/\.(jpe?g|png|gif|webp|bmp|svg)$/.test(low)) return 'image';
    return 'other';
}

async function streamS3KeyToResponse(res, key) {
    if (!process.env.MINIO_BUCKET) {
        res.status(500).json({ success: false, message: 'MINIO_BUCKET غير مضبوط' });
        return;
    }
    const out = await s3.send(
        new GetObjectCommand({
            Bucket: process.env.MINIO_BUCKET,
            Key: key,
            ResponseContentDisposition: 'inline',
        })
    );
    const ct = out.ContentType || 'application/octet-stream';
    res.setHeader('Content-Type', ct);
    res.setHeader('X-Preview-Kind', previewKindFromKey(key));
    if (out.ContentLength != null) res.setHeader('Content-Length', String(out.ContentLength));

    const body = out.Body;
    if (body && typeof body.pipe === 'function') {
        body.on('error', (err) => {
            console.error('[AdminController] preview stream:', err);
            if (!res.headersSent) res.status(500).end();
            else res.destroy(err);
        });
        body.pipe(res);
        return;
    }
    if (body && typeof body.transformToByteArray === 'function') {
        const ab = await body.transformToByteArray();
        res.send(Buffer.from(ab));
        return;
    }
    res.status(500).json({ success: false, message: 'لا يمكن قراءة الملف من التخزين' });
}

const AdminController = {
    getStats: async (req, res) => {
        try {
            console.log('[AdminController] Fetching dashboard stats...');

            // 1. جلب إحصائيات الأدوار (سائق/شاحن)
            const [userStats] = await pool.execute('SELECT role, COUNT(*) as total FROM users GROUP BY role');

            // 2. جلب إحصائيات التوثيق المعلق
            const [docStats] = await pool.execute('SELECT COUNT(*) as pending FROM compliance_documents WHERE is_verified = 0');

            // 2.5 جلب إحصائيات الشحنات حسب الحالة (لإظهار الرقم الصحيح في الكروت العلوية)
            const [shipmentStats] = await pool.execute('SELECT status, COUNT(*) as total FROM shipments GROUP BY status');

            // 3. جلب آخر الشحنات (زيادة العدد لـ 15 لملء الفراغ تماماً في الجدول)
            const [recentShipments] = await pool.execute(`
                SELECT s.id, u.full_name as shipper, s.pickup_address, s.dropoff_address, s.status,
                       COALESCE(s.final_price, s.base_price) as final_price
                FROM shipments s
                LEFT JOIN users u ON s.shipper_id = u.id
                ORDER BY s.created_at DESC LIMIT 15
            `);

            // 4. جلب سجل النشاطات الشامل (تصحيح أنواع النشاطات لتتوافق مع أيقونات الواجهة)
            const [activities] = await pool.execute(`
                (SELECT
                    'ship' as type,
                    u.full_name as actor,
                    CONCAT('إضافة شحنة من: ', SUBSTRING_INDEX(s.pickup_address, ',', 1)) as detail,
                    s.created_at as activity_date
                FROM shipments s
                JOIN users u ON s.shipper_id = u.id)

                UNION ALL

                (SELECT
                    'bid' as type,
                    u.full_name as actor,
                    CONCAT('تقديم عرض سعر بقيمة: ', b.bid_amount, ' ر.س') as detail,
                    b.created_at as activity_date
                FROM bids b
                JOIN users u ON b.driver_id = u.id)

                UNION ALL

                (SELECT
                    'document' as type,
                    u.full_name as actor,
                    CONCAT('رفع مستند: ', cd.document_type) as detail,
                    cd.uploaded_at as activity_date
                FROM compliance_documents cd
                JOIN users u ON cd.user_id = u.id)

                ORDER BY activity_date DESC LIMIT 15
            `);

            const [[summary]] = await pool.execute(`
                SELECT
                    (SELECT COUNT(*) FROM users) AS totalUsers,
                    (SELECT COUNT(*) FROM users WHERE role = 'driver') AS driversCount,
                    (SELECT COUNT(*) FROM users WHERE role = 'shipper') AS companiesCount,
                    (SELECT COUNT(*) FROM shipments WHERE status IN ('assigned','at_pickup','en_route','at_dropoff')) AS activeTrips,
                    (SELECT COUNT(*) FROM shipments WHERE status = 'delivered') AS completedTrips,
                    (SELECT COUNT(*) FROM bids WHERE bid_status = 'pending') AS pendingBidsCount,
                    (SELECT COALESCE(SUM(COALESCE(final_price, base_price, 0)), 0) FROM shipments WHERE status = 'delivered') AS totalRevenue,
                    (SELECT COUNT(*) FROM compliance_documents WHERE is_verified = 0) AS pendingVerifications
            `);

            res.json({
                success: true,
                data: {
                    summary: summary || {},
                    userStats: userStats || [],
                    shipmentStats: shipmentStats || [],
                    pendingUsersCount: docStats[0].pending || 0,
                    recentShipments: recentShipments || [],
                    activities: activities || []
                }
            });
        } catch (error) {
            console.error('[AdminController] Stats Error:', error);
            res.status(500).json({ success: false, message: 'خطأ في جلب الإحصائيات' });
        }
    },

    getUsers: async (req, res) => {
        try {
            const [rows] = await pool.execute('SELECT id, full_name, email, phone, role, verification_status, created_at FROM users ORDER BY created_at DESC');
            res.json({ success: true, data: rows });
        } catch (error) {
            console.error('[AdminController] Error in getUsers:', error);
            res.status(500).json({ success: false, message: 'خطأ في جلب المستخدمين' });
        }
    },

    getShipments: async (req, res) => {
        try {
            // جلب الشحنات مع اسم الشاحن وتصحيح السعر الظاهر
            const [rows] = await pool.execute(`
                SELECT s.*, u.full_name as shipper_name,
                       COALESCE(s.final_price, s.base_price) as final_price
                FROM shipments s
                LEFT JOIN users u ON s.shipper_id = u.id
                ORDER BY s.created_at DESC LIMIT 50
            `);
            res.json({ success: true, data: rows });
        } catch (error) {
            console.error('[AdminController] Shipments Error:', error);
            res.json({ success: true, data: [], message: 'خطأ في جلب السجل' });
        }
    },

    /** لوحة الإدارة — قائمة مستخدمين مع تصفية وتصفح (كان ينقص فيقول المتصفح «فشل الاتصال») */
    browseUsers: async (req, res) => {
        try {
            const page = Math.max(1, parseInt(String(req.query.page), 10) || 1);
            const limit = Math.min(100, Math.max(1, parseInt(String(req.query.limit), 10) || 15));
            const offset = (page - 1) * limit;

            let hasUserActive = false;
            try {
                const [c] = await pool.execute("SHOW COLUMNS FROM users LIKE 'is_active'");
                hasUserActive = c.length > 0;
            } catch (_) {
                /* ignore */
            }

            const role = String(req.query.role || '').trim();
            const q = String(req.query.q || '').trim();
            const verification = String(req.query.verification || '').trim();
            const active = req.query.active;
            const dateFrom = String(req.query.dateFrom || '').trim();
            const dateTo = String(req.query.dateTo || '').trim();

            const conditions = [];
            const params = [];

            if (role && ['driver', 'shipper', 'admin'].includes(role)) {
                conditions.push('u.role = ?');
                params.push(role);
            }
            if (q) {
                conditions.push('(u.full_name LIKE ? OR u.email LIKE ? OR u.phone LIKE ?)');
                const like = `%${q}%`;
                params.push(like, like, like);
            }
            if (verification && ['pending', 'verified', 'rejected'].includes(verification)) {
                conditions.push('u.verification_status = ?');
                params.push(verification);
            }
            if (hasUserActive && (active === '0' || active === '1')) {
                conditions.push('COALESCE(u.is_active, 1) = ?');
                params.push(Number(active));
            }
            if (dateFrom) {
                conditions.push('DATE(u.created_at) >= ?');
                params.push(dateFrom);
            }
            if (dateTo) {
                conditions.push('DATE(u.created_at) <= ?');
                params.push(dateTo);
            }

            const whereClause = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
            const activeSelect = hasUserActive ? 'COALESCE(u.is_active, 1) AS is_active' : '1 AS is_active';

            const countSql = `SELECT COUNT(*) AS total FROM users u ${whereClause}`;
            const [countRows] = await pool.query(countSql, params);
            const total = Number(countRows[0]?.total || 0);

            const listSql = `
                SELECT u.id, u.full_name, u.email, u.phone, u.role, u.verification_status, u.created_at,
                       ${activeSelect}
                FROM users u
                ${whereClause}
                ORDER BY u.created_at DESC
                LIMIT ? OFFSET ?
            `;
            const [rows] = await pool.query(listSql, [...params, limit, offset]);

            res.json({
                success: true,
                data: rows,
                pagination: {
                    page,
                    limit,
                    total,
                    totalPages: Math.max(1, Math.ceil(total / limit)),
                },
            });
        } catch (error) {
            console.error('[AdminController] browseUsers:', error);
            res.status(500).json({ success: false, message: 'خطأ في جلب المستخدمين' });
        }
    },

    /** لوحة الإدارة — قائمة شحنات مع تصفية وتصفح */
    browseShipments: async (req, res) => {
        try {
            const page = Math.max(1, parseInt(String(req.query.page), 10) || 1);
            const limit = Math.min(100, Math.max(1, parseInt(String(req.query.limit), 10) || 20));
            const offset = (page - 1) * limit;

            const q = String(req.query.q || '').trim();
            const status = String(req.query.status || '').trim();
            const dateFrom = String(req.query.dateFrom || '').trim();
            const dateTo = String(req.query.dateTo || '').trim();

            const conditions = [];
            const params = [];

            if (q) {
                conditions.push(
                    '(CAST(s.id AS CHAR) LIKE ? OR s.pickup_address LIKE ? OR s.dropoff_address LIKE ? OR us.full_name LIKE ? OR ud.full_name LIKE ?)'
                );
                const like = `%${q}%`;
                params.push(like, like, like, like, like);
            }
            if (
                status &&
                ['pending', 'bidding', 'assigned', 'at_pickup', 'en_route', 'at_dropoff', 'delivered', 'cancelled'].includes(
                    status
                )
            ) {
                conditions.push('s.status = ?');
                params.push(status);
            }
            if (dateFrom) {
                conditions.push('DATE(s.created_at) >= ?');
                params.push(dateFrom);
            }
            if (dateTo) {
                conditions.push('DATE(s.created_at) <= ?');
                params.push(dateTo);
            }

            const whereClause = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';

            const countSql = `
                SELECT COUNT(*) AS total
                FROM shipments s
                LEFT JOIN users us ON s.shipper_id = us.id
                LEFT JOIN users ud ON s.driver_id = ud.id
                ${whereClause}
            `;
            const [countRows2] = await pool.query(countSql, params);
            const total = Number(countRows2[0]?.total || 0);

            const listSql = `
                SELECT s.id, s.status, s.base_price, s.final_price, s.created_at,
                       us.full_name AS shipper_name,
                       ud.full_name AS driver_name
                FROM shipments s
                LEFT JOIN users us ON s.shipper_id = us.id
                LEFT JOIN users ud ON s.driver_id = ud.id
                ${whereClause}
                ORDER BY s.created_at DESC
                LIMIT ? OFFSET ?
            `;
            const [rows] = await pool.query(listSql, [...params, limit, offset]);

            res.json({
                success: true,
                data: rows,
                pagination: {
                    page,
                    limit,
                    total,
                    totalPages: Math.max(1, Math.ceil(total / limit)),
                },
            });
        } catch (error) {
            console.error('[AdminController] browseShipments:', error);
            res.status(500).json({ success: false, message: 'خطأ في جلب الشحنات' });
        }
    },

    getUserDetail: async (req, res) => {
        try {
            const id = req.params.id;
            const [userRows] = await pool.execute(
                'SELECT id, full_name, email, phone, role, verification_status, created_at FROM users WHERE id = ? LIMIT 1',
                [id]
            );
            if (!userRows.length) {
                return res.status(404).json({ success: false, message: 'غير موجود' });
            }
            const u = userRows[0];
            let trucks = [];
            if (u.role === 'driver') {
                const [tr] = await pool.execute(
                    `SELECT plate_number, truck_type, verification_status, is_active,
                            category, axle_count, body_type, payload_capacity, max_weight_tons
                     FROM trucks WHERE user_id = ? ORDER BY is_active DESC, created_at DESC`,
                    [id]
                );
                trucks = tr;

                const [cards] = await pool.execute(
                    `SELECT id, file_key, file_url, file_type, expiry_date, verification_status,
                            rejection_reason, created_at
                     FROM driver_operating_cards WHERE driver_id = ? ORDER BY created_at DESC LIMIT 1`,
                    [id]
                );
                u.operating_card = cards[0] || null;
            }
            let hasActive = false;
            try {
                const [c] = await pool.execute("SHOW COLUMNS FROM users LIKE 'is_active'");
                hasActive = c.length > 0;
            } catch (_) {
                /* ignore */
            }
            let isActive = 1;
            if (hasActive) {
                const [r2] = await pool.execute('SELECT is_active FROM users WHERE id = ?', [id]);
                if (r2.length) isActive = r2[0].is_active === 0 || r2[0].is_active === false ? 0 : 1;
            }
            res.json({ success: true, data: { ...u, trucks, is_active: isActive } });
        } catch (error) {
            console.error('[AdminController] getUserDetail:', error);
            res.status(500).json({ success: false, message: 'خطأ في جلب التفاصيل' });
        }
    },

    patchUserActive: async (req, res) => {
        try {
            const { id } = req.params;
            const next = req.body && req.body.is_active;
            const val = next === true || next === 1 || next === '1' ? 1 : 0;
            const [c] = await pool.execute("SHOW COLUMNS FROM users LIKE 'is_active'");
            if (!c.length) {
                return res.status(400).json({
                    success: false,
                    message: 'عمود is_active غير موجود — شغّل migration الإدارة',
                });
            }

            const [targetRows] = await pool.execute('SELECT id, role FROM users WHERE id = ? LIMIT 1', [id]);
            if (!targetRows.length) {
                return res.status(404).json({ success: false, message: 'المستخدم غير موجود' });
            }
            if (targetRows[0].role === 'admin') {
                return res.status(400).json({ success: false, message: 'لا يمكن تعطيل أو تفعيل حساب مدير من هنا' });
            }
            if (req.user && Number(req.user.id) === Number(id) && val === 0) {
                return res.status(400).json({ success: false, message: 'لا يمكنك تعطيل حسابك أثناء الجلسة' });
            }

            await pool.execute('UPDATE users SET is_active = ? WHERE id = ?', [val, id]);
            emitAdminDashboard(req, 'admin.user_active', { userId: id, is_active: val });
            res.json({ success: true });
        } catch (error) {
            console.error('[AdminController] patchUserActive:', error);
            res.status(500).json({ success: false, message: 'فشل التحديث' });
        }
    },

    /** إنشاء مستخدم (سائق / شركة) — FR-6 */
    createUser: async (req, res) => {
        let connection;
        try {
            const body = req.body || {};
            const fullName = String(body.full_name || '').trim();
            const email = String(body.email || '').trim().toLowerCase();
            const phone = String(body.phone || '').trim();
            const password = String(body.password || '');
            const role = String(body.role || 'driver').trim();

            if (!fullName || !email || !phone || password.length < 6) {
                return res.status(400).json({
                    success: false,
                    message: 'الاسم والبريد والجوال وكلمة مرور (6 أحرف على الأقل) مطلوبة',
                });
            }
            if (!['driver', 'shipper'].includes(role)) {
                return res.status(400).json({ success: false, message: 'الدور يجب أن يكون سائق أو شركة نقل' });
            }

            const [phoneUsed, emailUsed] = await Promise.all([
                User.existsByPhone(phone),
                User.existsByEmail(email),
            ]);
            if (phoneUsed || emailUsed) {
                return res.status(400).json({ success: false, message: 'البريد أو الجوال مستخدم مسبقاً' });
            }

            const hashed = await bcrypt.hash(password, 10);
            const expiry = '2099-12-31';

            let hasUserActive = false;
            try {
                const [col] = await pool.execute("SHOW COLUMNS FROM users LIKE 'is_active'");
                hasUserActive = col.length > 0;
            } catch (_) {
                /* ignore */
            }

            connection = await pool.getConnection();
            await connection.beginTransaction();

            let insertSql;
            let insertParams;
            if (hasUserActive) {
                insertSql =
                    'INSERT INTO users (full_name, email, phone, password, role, license_no, commercial_no, document_path, issue_date, expiry_date, is_active) VALUES (?, ?, ?, ?, ?, NULL, NULL, NULL, NULL, ?, ?)';
                insertParams = [fullName, email, phone, hashed, role, expiry, 1];
            } else {
                insertSql =
                    'INSERT INTO users (full_name, email, phone, password, role, license_no, commercial_no, document_path, issue_date, expiry_date) VALUES (?, ?, ?, ?, ?, NULL, NULL, NULL, NULL, ?)';
                insertParams = [fullName, email, phone, hashed, role, expiry];
            }

            const [userInsert] = await connection.execute(insertSql, insertParams);
            const userId = userInsert.insertId;

            await connection.execute('INSERT INTO wallets (user_id, current_balance) VALUES (?, ?)', [userId, 0]);

            await connection.commit();

            emitAdminDashboard(req, 'admin.user_created', { userId });
            res.status(201).json({
                success: true,
                data: { id: userId, full_name: fullName, email, phone, role },
            });
        } catch (error) {
            if (connection) await connection.rollback();
            console.error('[AdminController] createUser:', error);
            res.status(500).json({ success: false, message: error.message || 'فشل إنشاء المستخدم' });
        } finally {
            if (connection) connection.release();
        }
    },

    /** تعديل بيانات مستخدم — FR-6 */
    patchUser: async (req, res) => {
        try {
            const { id } = req.params;
            const body = req.body || {};

            const [existingRows] = await pool.execute(
                'SELECT id, role, email, phone FROM users WHERE id = ? LIMIT 1',
                [id]
            );
            if (!existingRows.length) {
                return res.status(404).json({ success: false, message: 'المستخدم غير موجود' });
            }
            const existing = existingRows[0];

            const fullName = body.full_name !== undefined ? String(body.full_name).trim() : null;
            const email = body.email !== undefined ? String(body.email).trim().toLowerCase() : null;
            const phone = body.phone !== undefined ? String(body.phone).trim() : null;
            const password = body.password !== undefined ? String(body.password) : null;
            const role = body.role !== undefined ? String(body.role).trim() : null;
            const verificationStatus =
                body.verification_status !== undefined ? String(body.verification_status).trim() : null;

            if (fullName !== null && !fullName) {
                return res.status(400).json({ success: false, message: 'الاسم غير صالح' });
            }
            if (email !== null && !email) {
                return res.status(400).json({ success: false, message: 'البريد غير صالح' });
            }
            if (phone !== null && !phone) {
                return res.status(400).json({ success: false, message: 'الجوال غير صالح' });
            }
            if (password !== null && password.length > 0 && password.length < 6) {
                return res.status(400).json({ success: false, message: 'كلمة المرور يجب أن تكون 6 أحرف على الأقل' });
            }
            if (role !== null && !['driver', 'shipper', 'admin'].includes(role)) {
                return res.status(400).json({ success: false, message: 'دور غير صالح' });
            }
            if (
                verificationStatus !== null &&
                !['pending', 'verified', 'rejected'].includes(verificationStatus)
            ) {
                return res.status(400).json({ success: false, message: 'حالة توثيق غير صالحة' });
            }

            if (existing.role === 'admin') {
                if (role !== null && role !== 'admin') {
                    return res.status(400).json({ success: false, message: 'لا يمكن تغيير دور مدير' });
                }
                if (verificationStatus !== null) {
                    return res.status(400).json({ success: false, message: 'لا يمكن تعديل حالة توثيق مدير' });
                }
            }

            if (role !== null && role === 'admin' && existing.role !== 'admin') {
                return res.status(400).json({ success: false, message: 'لا يمكن ترقية الحساب إلى مدير من هذه الشاشة' });
            }

            const nextEmail = email !== null ? email : existing.email;
            const nextPhone = phone !== null ? phone : existing.phone;

            if (email !== null && nextEmail !== existing.email) {
                const taken = await User.existsByEmail(nextEmail);
                if (taken) {
                    return res.status(400).json({ success: false, message: 'البريد مستخدم مسبقاً' });
                }
            }
            if (phone !== null && nextPhone !== existing.phone) {
                const takenPhone = await User.existsByPhone(nextPhone);
                if (takenPhone) {
                    return res.status(400).json({ success: false, message: 'الجوال مستخدم مسبقاً' });
                }
            }

            const sets = [];
            const params = [];

            if (fullName !== null) {
                sets.push('full_name = ?');
                params.push(fullName);
            }
            if (email !== null) {
                sets.push('email = ?');
                params.push(nextEmail);
            }
            if (phone !== null) {
                sets.push('phone = ?');
                params.push(nextPhone);
            }
            if (role !== null) {
                sets.push('role = ?');
                params.push(role);
            }
            if (verificationStatus !== null) {
                sets.push('verification_status = ?');
                params.push(verificationStatus);
            }
            if (password !== null && password.length > 0) {
                sets.push('password = ?');
                params.push(await bcrypt.hash(password, 10));
            }

            if (!sets.length) {
                return res.status(400).json({ success: false, message: 'لا توجد حقول للتحديث' });
            }

            params.push(id);
            await pool.execute(`UPDATE users SET ${sets.join(', ')} WHERE id = ?`, params);

            emitAdminDashboard(req, 'admin.user_updated', { userId: id });
            res.json({ success: true });
        } catch (error) {
            console.error('[AdminController] patchUser:', error);
            res.status(500).json({ success: false, message: 'فشل تحديث المستخدم' });
        }
    },

    /** عدم وجود جداول تظلمات بعد — نرجع قائمة فارغة حتى لا يتعطل الواجه */
    listDisputes: async (req, res) => {
        const page = Math.max(1, parseInt(String(req.query.page), 10) || 1);
        const limit = Math.min(50, Math.max(1, parseInt(String(req.query.limit), 10) || 12));
        res.json({
            success: true,
            data: [],
            pagination: { page, limit, total: 0, totalPages: 1 },
        });
    },

    resolveDisputeStub: async (req, res) => {
        res.json({ success: true, message: 'لا توجد تظلمات في هذا الإصدار' });
    },

    activityFeed: async (req, res) => {
        res.json({ success: true, data: [] });
    },

    notificationsList: async (req, res) => {
        res.json({ success: true, data: { unreadCount: 0, items: [] } });
    },

    notificationsRead: async (req, res) => {
        res.json({ success: true });
    },

    getPendingUsers: async (req, res) => {
        try {
            const page = Math.max(1, parseInt(String(req.query.page), 10) || 1);
            const limit = Math.min(50, Math.max(1, parseInt(String(req.query.limit), 10) || 8));
            const offset = (page - 1) * limit;

            const [countRowsPending] = await pool.execute(
                `
                SELECT (
                  (SELECT COUNT(*) FROM compliance_documents cd WHERE cd.is_verified = 0)
                  +
                  (SELECT COUNT(*) FROM driver_operating_cards oc WHERE oc.verification_status = 'pending')
                ) AS total
                `
            );
            const total = Number(countRowsPending[0]?.total || 0);

            const collate = 'utf8mb4_unicode_ci';
            const [rows] = await pool.execute(
                `
                SELECT * FROM (
                  SELECT
                    u.id AS user_id,
                    u.full_name COLLATE ${collate} AS full_name,
                    u.phone COLLATE ${collate} AS phone,
                    u.role COLLATE ${collate} AS role,
                    cd.document_id AS item_id,
                    cd.document_type COLLATE ${collate} AS document_type,
                    cd.document_url COLLATE ${collate} AS document_url,
                    cd.uploaded_at,
                    CAST('compliance' AS CHAR CHARACTER SET utf8mb4) COLLATE ${collate} AS source_kind
                  FROM users u
                  JOIN compliance_documents cd ON u.id = cd.user_id
                  WHERE cd.is_verified = 0
                  UNION ALL
                  SELECT
                    u.id AS user_id,
                    u.full_name COLLATE ${collate} AS full_name,
                    u.phone COLLATE ${collate} AS phone,
                    u.role COLLATE ${collate} AS role,
                    oc.id AS item_id,
                    CAST('operating_card' AS CHAR CHARACTER SET utf8mb4) COLLATE ${collate} AS document_type,
                    CAST(COALESCE(oc.file_key, oc.file_url) AS CHAR CHARACTER SET utf8mb4) COLLATE ${collate} AS document_url,
                    oc.created_at AS uploaded_at,
                    CAST('operating_card' AS CHAR CHARACTER SET utf8mb4) COLLATE ${collate} AS source_kind
                  FROM users u
                  JOIN driver_operating_cards oc ON u.id = oc.driver_id
                  WHERE oc.verification_status = 'pending'
                ) pending_items
                ORDER BY uploaded_at ASC
                LIMIT ? OFFSET ?
            `,
                [limit, offset]
            );

            res.json({
                success: true,
                data: rows,
                pagination: {
                    page,
                    limit,
                    total,
                    totalPages: Math.max(1, Math.ceil(total / limit)),
                },
            });
        } catch (error) {
            console.error('[AdminController] Error in getPendingUsers:', error);
            res.status(500).json({ success: false, message: 'خطأ في جلب طلبات التوثيق' });
        }
    },

    verifyDocument: async (req, res) => {
        try {
            const docId = req.params.docId || req.params.id || null;
            const status = req.body.status || null;
            const notes = req.body.notes === undefined ? null : req.body.notes;

            let adminId = null;
            if (req.user && req.user.id) {
                adminId = req.user.id;
            }

            console.log('[AdminController] Verifying Document:', { docId, status, adminId });

            if (!docId || docId === 'undefined') {
                return res.status(400).json({ success: false, message: 'معرف المستند مفقود' });
            }

            // الحالة: 1 = مقبول، 2 = مرفوض، 0 = معلق
            const finalStatus = status === 'verified' ? 1 : (status === 'rejected' ? 2 : 0);

            await pool.execute(
                'UPDATE compliance_documents SET is_verified = ?, verified_by = ?, verified_at = CURRENT_TIMESTAMP, verification_notes = ? WHERE document_id = ?',
                [finalStatus, adminId, notes, docId]
            );

            if (status === 'verified') {
                const [docRows] = await pool.execute('SELECT user_id FROM compliance_documents WHERE document_id = ?', [docId]);
                if (docRows.length > 0) {
                    await pool.execute('UPDATE users SET verification_status = "verified" WHERE id = ?', [docRows[0].user_id]);
                }
            } else if (status === 'rejected') {
                const [docRows] = await pool.execute('SELECT user_id FROM compliance_documents WHERE document_id = ?', [docId]);
                if (docRows.length > 0) {
                    await pool.execute('UPDATE users SET verification_status = "rejected" WHERE id = ?', [docRows[0].user_id]);
                }
            }

            emitAdminDashboard(req, 'document.verified', { docId, status });
            res.json({ success: true, message: 'تم تحديث الحالة بنجاح' });
        } catch (error) {
            console.error('[AdminController] Error in verifyDocument:', error);
            res.status(500).json({ success: false, message: 'فشل التحديث: ' + error.message });
        }
    },

    getSignedUrl: async (req, res) => {
        try {
            let source = req.query.url;
            const docId = req.query.docId;

            const cardId = req.query.cardId || req.query.operatingCardId;
            if (cardId && !source) {
                const [rows] = await pool.execute(
                    'SELECT file_key, file_url FROM driver_operating_cards WHERE id = ? LIMIT 1',
                    [cardId]
                );
                if (!rows.length) {
                    return res.status(404).json({ success: false, message: 'بطاقة التشغيل غير موجودة' });
                }
                source = rows[0].file_key || rows[0].file_url;
            }

            if (docId && !source) {
                const [rows] = await pool.execute(
                    'SELECT document_url FROM compliance_documents WHERE document_id = ? LIMIT 1',
                    [docId]
                );
                if (!rows.length || !rows[0].document_url) {
                    return res.status(404).json({ success: false, message: 'المستند غير موجود' });
                }
                source = rows[0].document_url;
            }

            if (!source) {
                return res.status(400).json({ success: false, message: 'الرابط مفقود' });
            }

            const signedUrl = await generatePresignedUrl(source);
            const keyHint = resolveS3ObjectKey(String(source)).toLowerCase();
            const lowerHint = keyHint || String(source).toLowerCase();
            const fileType = lowerHint.endsWith('.pdf') ? 'pdf' : 'image';

            if (
                !signedUrl ||
                (!String(signedUrl).startsWith('http://') && !String(signedUrl).startsWith('https://'))
            ) {
                return res.status(502).json({ success: false, message: 'فشل إنشاء رابط المعاينة' });
            }

            console.log(`[AdminController] Signing URL for ${fileType}:`, source);
            res.json({ success: true, signedUrl, fileType });
        } catch (error) {
            console.error('[AdminController] Error signing URL:', error);
            res.status(500).json({ success: false, message: 'فشل توقيع الرابط' });
        }
    },

    /** معاينة عبر السيرفر (نفس المنشأ) — احتياطي عند فشل الرابط الموقّع أو حظر iframe */
    previewDocumentById: async (req, res) => {
        try {
            const id = req.params.id;
            const kind = String(req.query.kind || 'compliance');
            let key = null;

            if (kind === 'operating_card') {
                const [rows] = await pool.execute(
                    'SELECT file_key, file_url FROM driver_operating_cards WHERE id = ? LIMIT 1',
                    [id]
                );
                if (!rows.length) {
                    return res.status(404).json({ success: false, message: 'بطاقة التشغيل غير موجودة' });
                }
                key = resolveS3ObjectKey(rows[0].file_key || rows[0].file_url);
            } else {
                const [rows] = await pool.execute(
                    'SELECT document_url FROM compliance_documents WHERE document_id = ? LIMIT 1',
                    [id]
                );
                if (!rows.length || !rows[0].document_url) {
                    return res.status(404).json({ success: false, message: 'المستند غير موجود' });
                }
                key = resolveS3ObjectKey(rows[0].document_url);
            }

            if (!key) return res.status(400).json({ success: false, message: 'مسار الملف غير صالح' });
            await streamS3KeyToResponse(res, key);
        } catch (error) {
            console.error('[AdminController] previewDocumentById:', error);
            if (!res.headersSent) res.status(500).json({ success: false, message: 'فشل المعاينة' });
        }
    },

    verifyOperatingCard: async (req, res) => {
        try {
            const cardId = req.params.cardId;
            const status = req.body.status || null;
            const notes = req.body.notes || req.body.rejection_reason || null;

            if (!cardId) {
                return res.status(400).json({ success: false, message: 'معرف بطاقة التشغيل مفقود' });
            }
            if (!['verified', 'rejected'].includes(status)) {
                return res.status(400).json({ success: false, message: 'حالة غير صالحة' });
            }

            const OperatingCard = require('../models/OperatingCard');
            const updated = await OperatingCard.updateStatus(cardId, {
                status,
                rejection_reason: status === 'rejected' ? notes : null,
            });
            if (!updated) {
                return res.status(404).json({ success: false, message: 'بطاقة التشغيل غير موجودة' });
            }

            emitAdminDashboard(req, 'operating_card.verified', { cardId, status });
            res.json({
                success: true,
                message: `تم ${status === 'verified' ? 'اعتماد' : 'رفض'} بطاقة التشغيل بنجاح`,
            });
        } catch (error) {
            console.error('[AdminController] verifyOperatingCard:', error);
            res.status(500).json({ success: false, message: 'فشل تحديث بطاقة التشغيل' });
        }
    },

    previewDocumentByQuery: async (req, res) => {
        try {
            let url = req.query.url;
            if (!url) return res.status(400).json({ success: false, message: 'الرابط مفقود' });
            url = decodeURIComponent(String(url));
            const key = resolveS3ObjectKey(url);
            if (!key) return res.status(400).json({ success: false, message: 'مسار الملف غير صالح' });
            await streamS3KeyToResponse(res, key);
        } catch (error) {
            console.error('[AdminController] previewDocumentByQuery:', error);
            if (!res.headersSent) res.status(500).json({ success: false, message: 'فشل المعاينة' });
        }
    },

    verifyUser: async (req, res) => {
        try {
            const { id } = req.params;
            await pool.execute('UPDATE users SET verification_status = "verified" WHERE id = ?', [id]);
            emitAdminDashboard(req, 'admin.user_verified', { userId: id });
            res.json({ success: true, message: 'تم توثيق المستخدم بنجاح' });
        } catch (error) {
            res.status(500).json({ success: false, message: 'خطأ في توثيق المستخدم' });
        }
    },

    getPriceFloors: async (req, res) => {
        try {
            const [rows] = await pool.execute('SELECT * FROM price_floors ORDER BY created_at DESC');
            res.json({ success: true, data: rows });
        } catch (error) {
            res.status(500).json({ success: false, message: 'خطأ في جلب حدود الأسعار' });
        }
    },

    createPriceFloor: async (req, res) => {
        try {
            const { origin, destination, min_price } = req.body;
            await pool.execute(
                'INSERT INTO price_floors (origin, destination, min_price) VALUES (?, ?, ?)',
                [origin, destination, min_price]
            );
            res.json({ success: true, message: 'تمت الإضافة بنجاح' });
        } catch (error) {
            res.status(500).json({ success: false, message: 'خطأ في إضافة حد السعر' });
        }
    },

    deletePriceFloor: async (req, res) => {
        try {
            const { id } = req.params;
            await pool.execute('DELETE FROM price_floors WHERE id = ?', [id]);
            res.json({ success: true, message: 'تم الحذف بنجاح' });
        } catch (error) {
            res.status(500).json({ success: false, message: 'خطأ في الحذف' });
        }
    },

    exportReport: async (req, res) => {
        try {
            const [users] = await pool.execute('SELECT * FROM users');
            const [shipments] = await pool.execute('SELECT * FROM shipments');
            res.json({ success: true, data: { users, shipments } });
        } catch (error) {
            res.status(500).json({ success: false, message: 'خطأ في تصدير التقرير' });
        }
    },

    /** آخر 7 أيام — شحنات جديدة مقابل عروض أسعار (للوحة التحكم) */
    overviewCharts: async (req, res) => {
        try {
            const days = 7;
            const [shipRows] = await pool.execute(
                `SELECT DATE(created_at) AS d, COUNT(*) AS c
                 FROM shipments
                 WHERE created_at >= DATE_SUB(CURDATE(), INTERVAL ? DAY)
                 GROUP BY DATE(created_at)`,
                [days - 1],
            );
            const [bidRows] = await pool.execute(
                `SELECT DATE(created_at) AS d, COUNT(*) AS c
                 FROM bids
                 WHERE created_at >= DATE_SUB(CURDATE(), INTERVAL ? DAY)
                 GROUP BY DATE(created_at)`,
                [days - 1],
            );

            const toKey = (d) => {
                if (d == null) return '';
                if (d instanceof Date) return d.toISOString().slice(0, 10);
                const s = String(d);
                return s.length >= 10 ? s.slice(0, 10) : s;
            };

            const map = {};
            const bump = (key, field, n) => {
                if (!key) return;
                if (!map[key]) map[key] = { date: key, shipments: 0, bids: 0 };
                map[key][field] += n;
            };

            for (const r of shipRows || []) bump(toKey(r.d), 'shipments', Number(r.c) || 0);
            for (const r of bidRows || []) bump(toKey(r.d), 'bids', Number(r.c) || 0);

            for (let i = days - 1; i >= 0; i -= 1) {
                const dt = new Date();
                dt.setHours(0, 0, 0, 0);
                dt.setDate(dt.getDate() - i);
                const key = dt.toISOString().slice(0, 10);
                if (!map[key]) map[key] = { date: key, shipments: 0, bids: 0 };
            }

            const series = Object.keys(map)
                .sort()
                .slice(-days)
                .map((k) => map[k]);

            res.json({ success: true, data: { series } });
        } catch (error) {
            console.error('[AdminController] overviewCharts:', error);
            res.status(500).json({ success: false, message: 'خطأ في بيانات الرسوم' });
        }
    },
};

module.exports = AdminController;
