const fs = require('fs');
const path = require('path');
const { GetObjectCommand } = require('@aws-sdk/client-s3');
const pool = require('../config/db');
const User = require('../models/User');
const {
    generatePresignedUrl,
    parseStorageKey,
    guessContentTypeFromKey,
    s3,
} = require('../utils/s3Config');

/** لواجهة المعاينة: pdf | image | other */
function inferPreviewKindFromRef(ref) {
    const raw = String(ref || '');
    const key = parseStorageKey(raw);
    let mime = guessContentTypeFromKey(key);
    if (mime === 'application/octet-stream') {
        const m = raw.toLowerCase().match(/\.(pdf|jpe?g|png|gif|webp|bmp|svg)(?:\?|#|$)/);
        if (m) mime = guessContentTypeFromKey(`x.${m[1] === 'jpeg' ? 'jpg' : m[1]}`);
    }
    if (mime === 'application/pdf') return 'pdf';
    if (mime.startsWith('image/')) return 'image';
    return 'other';
}

/** نوع الملف من أول بايتات (ملفات بلا امتداد أو Content-Type خاطئ) */
function sniffBufferPreview(buf) {
    if (!buf || buf.length < 12) return null;
    if (buf[0] === 0x25 && buf[1] === 0x50 && buf[2] === 0x44 && buf[3] === 0x46) {
        return { mime: 'application/pdf', kind: 'pdf' };
    }
    if (buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) {
        return { mime: 'image/jpeg', kind: 'image' };
    }
    if (buf[0] === 0x89 && buf[1] === 0x50 && buf[2] === 0x4e && buf[3] === 0x47) {
        return { mime: 'image/png', kind: 'image' };
    }
    const head = buf.slice(0, 6).toString('ascii');
    if (head.startsWith('GIF87') || head.startsWith('GIF89')) {
        return { mime: 'image/gif', kind: 'image' };
    }
    if (buf[0] === 0x52 && buf[1] === 0x49 && buf[2] === 0x46 && buf[3] === 0x46 && buf.length >= 12) {
        if (buf.slice(8, 12).toString('ascii') === 'WEBP') return { mime: 'image/webp', kind: 'image' };
    }
    return null;
}
const { decryptText } = require('../utils/encryption');

let cachedUsersCols = null;
let cachedDisputesTable = null;

/** MinIO / S3 GetObject Body — SDK v3 may omit .pipe(); always buffer for small admin docs (≤10MB). */
async function bufferFromS3GetObjectBody(body) {
    if (!body) return null;
    if (typeof body.transformToByteArray === 'function') {
        const u8 = await body.transformToByteArray();
        return Buffer.from(u8);
    }
    if (typeof body.pipe === 'function') {
        return await new Promise((resolve, reject) => {
            const chunks = [];
            body.on('data', (c) => chunks.push(Buffer.isBuffer(c) ? c : Buffer.from(c)));
            body.on('end', () => resolve(Buffer.concat(chunks)));
            body.on('error', reject);
        });
    }
    const chunks = [];
    for await (const chunk of body) {
        chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
    }
    return Buffer.concat(chunks);
}

async function getUsersColumnSet() {
    if (cachedUsersCols) return cachedUsersCols;
    try {
        const [rows] = await pool.execute(
            `SELECT COLUMN_NAME AS c FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users'`
        );
        cachedUsersCols = new Set(rows.map((r) => r.c));
    } catch {
        cachedUsersCols = new Set();
    }
    return cachedUsersCols;
}

async function disputesTableReady() {
    if (cachedDisputesTable !== null) return cachedDisputesTable;
    try {
        const [rows] = await pool.execute(
            `SELECT 1 AS ok FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'disputes' LIMIT 1`
        );
        cachedDisputesTable = rows.length > 0;
    } catch {
        cachedDisputesTable = false;
    }
    return cachedDisputesTable;
}

async function notificationReadsReady() {
    try {
        const [rows] = await pool.execute(
            `SELECT 1 AS ok FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'admin_notification_reads' LIMIT 1`
        );
        return rows.length > 0;
    } catch {
        return false;
    }
}

function pagination(req, maxLimit = 100) {
    const page = Math.max(1, parseInt(req.query.page, 10) || 1);
    const limit = Math.min(maxLimit, Math.max(1, parseInt(req.query.limit, 10) || 20));
    const offset = (page - 1) * limit;
    return { page, limit, offset };
}

/** Unified activity rows for feed + notifications */
async function fetchUnifiedActivities(limit, offset) {
    /** UNION requires identical collation on string columns across branches (mixed utf8mb4_general_ci / unicode_ci + ENUM). */
    const U = 'utf8mb4_unicode_ci';
    const cs = (expr) =>
        `CAST(${expr} AS CHAR(3072) CHARACTER SET utf8mb4) COLLATE ${U}`;

    const disputesUnion = (await disputesTableReady())
        ? `
    UNION ALL
    (
      SELECT
        ${cs("'dispute_opened'")} AS type,
        ${cs("CONCAT('', d.id)")} AS ref_id,
        ${cs('du.full_name')} AS actor,
        ${cs(
            "CONCAT('تظلم مالي قيمته ', CAST(d.amount AS CHAR CHARACTER SET utf8mb4), ' ريال — شحنة #', CAST(d.shipment_id AS CHAR CHARACTER SET utf8mb4))"
        )} AS detail,
        d.created_at AS activity_date,
        ${cs("CONCAT('dispute_', d.id)")} AS notification_key
      FROM disputes d
      JOIN users du ON du.id = d.driver_id
      WHERE d.status = 'open'
    )
    `
        : '';

    const sql = `
    (
      SELECT
        ${cs("'registration'")} AS type,
        ${cs("CONCAT('', u.id)")} AS ref_id,
        ${cs('u.full_name')} AS actor,
        ${cs("CONCAT('تسجيل ', IF(u.role = 'driver', 'سائق جديد', 'شركة نقل'))")} AS detail,
        u.created_at AS activity_date,
        ${cs("CONCAT('reg_', u.id)")} AS notification_key
      FROM users u
      WHERE u.role IN ('driver', 'shipper')
    )
    UNION ALL
    (
      SELECT
        ${cs("'bid_submitted'")} AS type,
        ${cs("CONCAT('', b.id)")} AS ref_id,
        ${cs('dr.full_name')} AS actor,
        ${cs(
            "CONCAT('تقديم عرض سعر ', CAST(b.bid_amount AS CHAR CHARACTER SET utf8mb4), ' ريال للشحنة #', CAST(b.shipment_id AS CHAR CHARACTER SET utf8mb4))"
        )} AS detail,
        b.created_at AS activity_date,
        ${cs("CONCAT('bid_', b.id)")} AS notification_key
      FROM bids b
      JOIN users dr ON dr.id = b.driver_id
      WHERE b.bid_status = 'pending'
    )
    UNION ALL
    (
      SELECT
        ${cs("IF(b.bid_status = 'accepted', 'bid_accepted', 'bid_rejected')")} AS type,
        ${cs("CONCAT('', b.id)")} AS ref_id,
        ${cs('dr.full_name')} AS actor,
        ${cs(
            `IF(
          b.bid_status = 'accepted',
          CONCAT('قبول عرض بقيمة ', CAST(b.bid_amount AS CHAR CHARACTER SET utf8mb4), ' ريال للشحنة #', CAST(b.shipment_id AS CHAR CHARACTER SET utf8mb4)),
          CONCAT('رفض عرض للشحنة #', CAST(b.shipment_id AS CHAR CHARACTER SET utf8mb4))
        )`
        )} AS detail,
        b.created_at AS activity_date,
        ${cs(
            "CONCAT('bidstat_', b.id, '_', CAST(b.bid_status AS CHAR CHARACTER SET utf8mb4))"
        )} AS notification_key
      FROM bids b
      JOIN users dr ON dr.id = b.driver_id
      WHERE b.bid_status IN ('accepted', 'rejected')
    )
    UNION ALL
    (
      SELECT
        ${cs("'trip_completed'")} AS type,
        ${cs("CONCAT('', s.id)")} AS ref_id,
        ${cs("COALESCE(drv.full_name, 'السائق')")} AS actor,
        ${cs("CONCAT('اكتملت الرحلة للشحنة #', CAST(s.id AS CHAR CHARACTER SET utf8mb4))")} AS detail,
        COALESCE(s.actual_delivery_date, s.created_at) AS activity_date,
        ${cs("CONCAT('trip_done_', s.id)")} AS notification_key
      FROM shipments s
      LEFT JOIN users drv ON drv.id = s.driver_id
      WHERE s.status = 'delivered'
    )
    UNION ALL
    (
      SELECT
        ${cs("'rating_submitted'")} AS type,
        ${cs("CONCAT('', r.id)")} AS ref_id,
        ${cs('ur.full_name')} AS actor,
        ${cs("CONCAT('تقييم ', CAST(r.stars AS CHAR CHARACTER SET utf8mb4), ' نجوم')")} AS detail,
        r.created_at AS activity_date,
        ${cs("CONCAT('rating_', r.id)")} AS notification_key
      FROM ratings r
      JOIN users ur ON ur.id = r.rater_id
    )
    UNION ALL
    (
      SELECT
        ${cs("'document'")} AS type,
        ${cs("CONCAT('', cd.document_id)")} AS ref_id,
        ${cs('u.full_name')} AS actor,
        ${cs(
            "CONCAT('رفع مستند: ', CAST(cd.document_type AS CHAR CHARACTER SET utf8mb4))"
        )} AS detail,
        cd.uploaded_at AS activity_date,
        ${cs("CONCAT('doc_', cd.document_id)")} AS notification_key
      FROM compliance_documents cd
      JOIN users u ON cd.user_id = u.id
    )
    UNION ALL
    (
      SELECT
        ${cs("'verification_decided'")} AS type,
        ${cs("CONCAT('', cd.document_id)")} AS ref_id,
        ${cs('u.full_name')} AS actor,
        ${cs(`CASE
          WHEN cd.is_verified = 1 THEN CONCAT('اعتماد مستند (', CAST(cd.document_type AS CHAR CHARACTER SET utf8mb4), ')')
          WHEN cd.is_verified = 2 THEN CONCAT('رفض مستند (', CAST(cd.document_type AS CHAR CHARACTER SET utf8mb4), ')')
          ELSE CONCAT('تحديث حالة مستند (', CAST(cd.document_type AS CHAR CHARACTER SET utf8mb4), ')')
        END`)} AS detail,
        cd.verified_at AS activity_date,
        ${cs("CONCAT('ver_', cd.document_id, '_', UNIX_TIMESTAMP(cd.verified_at))")} AS notification_key
      FROM compliance_documents cd
      JOIN users u ON cd.user_id = u.id
      WHERE cd.verified_at IS NOT NULL
    )
    ${disputesUnion}
    ORDER BY activity_date DESC
    LIMIT ? OFFSET ?
  `;

    const [rows] = await pool.execute(sql, [limit, offset]);
    return rows;
}

/** بث ملف التوثيق (MinIO ثم القرص المحلي) — يُستدعى من ?url= أو من معرف المستند */
async function sendDocumentPreviewForRaw(rawInput, res) {
    try {
        const raw = String(rawInput || '').trim();
        if (!raw) {
            return res.status(400).json({ success: false, message: 'الرابط مفقود' });
        }

        const key = parseStorageKey(raw);
        if (!key) {
            return res.status(400).json({ success: false, message: 'مسار الملف غير صالح' });
        }

        const contentType = guessContentTypeFromKey(key);
        const safeSuffix = path.basename(key) || 'document';
        const maxPreview = 15 * 1024 * 1024;

        if (process.env.MINIO_BUCKET && process.env.MINIO_ENDPOINT) {
            try {
                const command = new GetObjectCommand({
                    Bucket: process.env.MINIO_BUCKET,
                    Key: key,
                });
                const out = await s3.send(command);
                const buf = await bufferFromS3GetObjectBody(out.Body);
                if (buf && buf.length > maxPreview) {
                    return res.status(413).json({
                        success: false,
                        message: 'حجم الملف يتجاوز حد المعاينة (15 ميجابايت)',
                    });
                }
                if (buf && buf.length) {
                    const sniffed = sniffBufferPreview(buf);
                    const guessed = guessContentTypeFromKey(key);
                    let ctype;
                    let previewKind;
                    if (sniffed) {
                        ctype = sniffed.mime;
                        previewKind = sniffed.kind;
                    } else {
                        ctype =
                            guessed !== 'application/octet-stream'
                                ? guessed
                                : out.ContentType || contentType;
                        previewKind = inferPreviewKindFromRef(raw);
                    }
                    res.setHeader('Content-Type', ctype);
                    res.setHeader('X-Preview-Kind', previewKind);
                    res.setHeader(
                        'Content-Disposition',
                        `inline; filename*=UTF-8''${encodeURIComponent(safeSuffix)}`
                    );
                    res.setHeader('Content-Length', buf.length);
                    return res.send(buf);
                }
            } catch (err) {
                console.warn('[AdminController] MinIO preview failed:', err.message);
            }
        }

        const uploadsRoot = path.resolve(path.join(__dirname, '..', 'uploads'));
        const localPath = path.resolve(path.join(uploadsRoot, key));
        if (!localPath.startsWith(uploadsRoot)) {
            return res.status(400).json({ success: false, message: 'مسار غير مسموح' });
        }
        if (!fs.existsSync(localPath)) {
            return res.status(404).json({
                success: false,
                message:
                    'المستند غير موجود. تأكد من إعدادات MinIO (MINIO_ENDPOINT، MINIO_BUCKET) وأن الملف ما يزال في التخزين.',
            });
        }

        const stat = fs.statSync(localPath);
        if (stat.size > maxPreview) {
            return res.status(413).json({
                success: false,
                message: 'حجم الملف يتجاوز حد المعاينة (15 ميجابايت)',
            });
        }
        const buf = fs.readFileSync(localPath);
        if (!buf.length) {
            return res.status(404).json({ success: false, message: 'الملف فارغ' });
        }
        const sniffed = sniffBufferPreview(buf);
        const guessed = guessContentTypeFromKey(key);
        const ctype = sniffed
            ? sniffed.mime
            : guessed !== 'application/octet-stream'
              ? guessed
              : contentType;
        const previewKind = sniffed ? sniffed.kind : inferPreviewKindFromRef(raw);
        res.setHeader('Content-Type', ctype);
        res.setHeader('X-Preview-Kind', previewKind);
        res.setHeader('Content-Disposition', `inline; filename*=UTF-8''${encodeURIComponent(safeSuffix)}`);
        res.setHeader('Content-Length', buf.length);
        return res.send(buf);
    } catch (error) {
        console.error('[AdminController] sendDocumentPreviewForRaw:', error);
        if (!res.headersSent) {
            res.status(500).json({ success: false, message: 'فشل جلب الملف' });
        }
    }
}

const AdminController = {
    getStats: async (req, res) => {
        try {
            console.log('[AdminController] Fetching dashboard stats...');

            const cols = await getUsersColumnSet();
            const activeExpr = cols.has('is_active') ? 'COALESCE(is_active, 1) = 1' : '1=1';

            const [userStats] = await pool.execute(
                `SELECT role, COUNT(*) AS total FROM users WHERE ${activeExpr} GROUP BY role`
            );

            const [docStats] = await pool.execute(
                'SELECT COUNT(*) AS pending FROM compliance_documents WHERE is_verified = 0'
            );

            const [shipmentStats] = await pool.execute(
                'SELECT status, COUNT(*) AS total FROM shipments GROUP BY status'
            );

            const [recentShipments] = await pool.execute(`
                SELECT s.id, u.full_name AS shipper, s.pickup_address, s.dropoff_address, s.status,
                       COALESCE(s.final_price, s.base_price) AS final_price
                FROM shipments s
                LEFT JOIN users u ON s.shipper_id = u.id
                ORDER BY s.created_at DESC LIMIT 15
            `);

            const activities = await fetchUnifiedActivities(15, 0);

            const [[roleRow]] = await pool.execute(`
                SELECT
                  SUM(role = 'driver') AS drivers,
                  SUM(role = 'shipper') AS companies,
                  SUM(role IN ('driver','shipper')) AS platform_users
                FROM users WHERE ${activeExpr}
            `);

            const [[tripRow]] = await pool.execute(`
                SELECT
                  SUM(status IN ('assigned','at_pickup','en_route','at_dropoff')) AS active_trips,
                  SUM(status = 'delivered') AS completed_trips
                FROM shipments
            `);

            const [[revRow]] = await pool.execute(`
                SELECT COALESCE(SUM(COALESCE(final_price, base_price)), 0) AS total_revenue
                FROM shipments WHERE status = 'delivered'
            `);

            let openDisputes = 0;
            if (await disputesTableReady()) {
                const [[d]] = await pool.execute(
                    `SELECT COUNT(*) AS c FROM disputes WHERE status = 'open'`
                );
                openDisputes = d.c || 0;
            }

            const pendingBidsRow = await pool.execute(
                `SELECT COUNT(*) AS c FROM bids WHERE bid_status = 'pending'`
            );
            const pendingBidsCount = pendingBidsRow[0][0].c || 0;

            const summary = {
                totalUsers: Number(roleRow.platform_users) || 0,
                driversCount: Number(roleRow.drivers) || 0,
                companiesCount: Number(roleRow.companies) || 0,
                activeTrips: Number(tripRow.active_trips) || 0,
                completedTrips: Number(tripRow.completed_trips) || 0,
                pendingVerifications: docStats[0].pending || 0,
                totalRevenue: Number(revRow.total_revenue) || 0,
                openDisputes,
                pendingBidsCount,
            };

            res.json({
                success: true,
                data: {
                    userStats: userStats || [],
                    shipmentStats: shipmentStats || [],
                    pendingUsersCount: docStats[0].pending || 0,
                    recentShipments: recentShipments || [],
                    activities: activities || [],
                    summary,
                },
            });
        } catch (error) {
            console.error('[AdminController] Stats Error:', error);
            res.status(500).json({ success: false, message: 'خطأ في جلب الإحصائيات' });
        }
    },

    /** Paginated unified activity */
    getActivityFeed: async (req, res) => {
        try {
            const limit = Math.min(50, Math.max(1, parseInt(req.query.limit, 10) || 30));
            const offset = Math.max(0, parseInt(req.query.offset, 10) || 0);
            const rows = await fetchUnifiedActivities(limit, offset);
            res.json({
                success: true,
                data: rows,
                pagination: { limit, offset, hasMore: rows.length === limit },
            });
        } catch (error) {
            console.error('[AdminController] Activity feed:', error);
            res.status(500).json({ success: false, message: 'خطأ في جلب النشاط' });
        }
    },

    getNotifications: async (req, res) => {
        try {
            const limit = Math.min(80, Math.max(1, parseInt(req.query.limit, 10) || 40));
            const rows = await fetchUnifiedActivities(limit, 0);
            const keys = rows.map((r) => r.notification_key).filter(Boolean);
            let readSet = new Set();
            if (keys.length && (await notificationReadsReady())) {
                const ph = keys.map(() => '?').join(',');
                const [reads] = await pool.execute(
                    `SELECT notification_key FROM admin_notification_reads WHERE notification_key IN (${ph})`,
                    keys
                );
                readSet = new Set(reads.map((x) => x.notification_key));
            }
            const items = rows.map((r) => ({
                key: r.notification_key,
                type: r.type,
                title: r.actor,
                body: r.detail,
                created_at: r.activity_date,
                read: readSet.has(r.notification_key),
            }));
            const unreadCount = items.filter((i) => !i.read).length;
            res.json({ success: true, data: { items, unreadCount } });
        } catch (error) {
            console.error('[AdminController] Notifications:', error);
            res.status(500).json({ success: false, message: 'خطأ في الإشعارات' });
        }
    },

    markNotificationsRead: async (req, res) => {
        try {
            if (!(await notificationReadsReady())) {
                return res.json({ success: true, message: 'لا يوجد جدول تخزين القراءة (شغّل migration)' });
            }
            const keys = req.body.keys;
            const single = req.body.key;
            const list = Array.isArray(keys) ? keys : single ? [single] : [];
            if (!list.length) {
                return res.status(400).json({ success: false, message: 'لا توجد مفاتيح' });
            }
            const trimmed = list.slice(0, 200).map((k) => String(k));
            for (const key of trimmed) {
                await pool.execute('INSERT IGNORE INTO admin_notification_reads (notification_key) VALUES (?)', [
                    key,
                ]);
            }
            res.json({ success: true });
        } catch (error) {
            console.error('[AdminController] markNotificationsRead:', error);
            res.status(500).json({ success: false, message: 'فشل التحديث' });
        }
    },

    browseUsers: async (req, res) => {
        try {
            const { q, role, verification, active, dateFrom, dateTo } = req.query;
            const { page, limit, offset } = pagination(req, 100);
            const cols = await getUsersColumnSet();

            const params = [];
            let where = 'WHERE 1=1';

            if (role && ['driver', 'shipper', 'admin'].includes(role)) {
                where += ' AND role = ?';
                params.push(role);
            }

            if (verification && ['pending', 'verified', 'rejected'].includes(verification)) {
                where += ' AND verification_status = ?';
                params.push(verification);
            }

            if (cols.has('is_active') && active !== undefined && active !== '') {
                where += ' AND COALESCE(is_active,1) = ?';
                params.push(active === '1' || active === 'true' ? 1 : 0);
            }

            if (q && String(q).trim()) {
                const like = `%${String(q).trim()}%`;
                where += ' AND (full_name LIKE ? OR email LIKE ? OR phone LIKE ?)';
                params.push(like, like, like);
            }

            if (dateFrom) {
                where += ' AND created_at >= ?';
                params.push(dateFrom);
            }
            if (dateTo) {
                where += ' AND created_at < DATE_ADD(?, INTERVAL 1 DAY)';
                params.push(dateTo);
            }

            const countSql = `SELECT COUNT(*) AS total FROM users ${where}`;
            const [[countRow]] = await pool.execute(countSql, params);

            const activeSel = cols.has('is_active') ? ', COALESCE(is_active,1) AS is_active' : '';
            const dataSql = `
              SELECT id, full_name, email, phone, role, verification_status, created_at ${activeSel}
              FROM users ${where}
              ORDER BY created_at DESC
              LIMIT ? OFFSET ?
            `;
            const [rows] = await pool.execute(dataSql, [...params, limit, offset]);

            res.json({
                success: true,
                data: rows,
                pagination: {
                    page,
                    limit,
                    total: countRow.total,
                    totalPages: Math.ceil(countRow.total / limit) || 1,
                },
            });
        } catch (error) {
            console.error('[AdminController] browseUsers:', error);
            res.status(500).json({ success: false, message: 'خطأ في جلب المستخدمين' });
        }
    },

    getUserDetail: async (req, res) => {
        try {
            const id = req.params.id;
            const cols = await getUsersColumnSet();
            const activeSel = cols.has('is_active') ? ', COALESCE(is_active,1) AS is_active' : '';
            const [users] = await pool.execute(
                `SELECT id, full_name, email, phone, role, verification_status, created_at,
                        license_no, commercial_no, document_path ${activeSel}
                 FROM users WHERE id = ? LIMIT 1`,
                [id]
            );
            if (!users.length) {
                return res.status(404).json({ success: false, message: 'غير موجود' });
            }
            const user = users[0];
            delete user.password;
            try {
                if (user.license_no) user.license_no = decryptText(user.license_no);
            } catch (_) {
                /* leave raw if not decryptable */
            }
            try {
                if (user.commercial_no) user.commercial_no = decryptText(user.commercial_no);
            } catch (_) {
                /* leave raw */
            }

            let trucks = [];
            if (user.role === 'driver') {
                const [t] = await pool.execute(
                    `SELECT id, plate_number, truck_type, verification_status, is_active, created_at FROM trucks WHERE user_id = ?`,
                    [id]
                );
                trucks = t;
            }

            res.json({ success: true, data: { ...user, trucks } });
        } catch (error) {
            console.error('[AdminController] getUserDetail:', error);
            res.status(500).json({ success: false, message: 'خطأ في التفاصيل' });
        }
    },

    setUserActive: async (req, res) => {
        try {
            const id = req.params.id;
            const { is_active } = req.body;
            const cols = await getUsersColumnSet();
            if (!cols.has('is_active')) {
                return res.status(400).json({
                    success: false,
                    message: 'عمود is_active غير متوفر — شغّل migrations_06_admin_dashboard.sql',
                });
            }
            const activeVal = is_active === false || is_active === 0 || is_active === '0' ? 0 : 1;
            const [u] = await pool.execute(`SELECT role FROM users WHERE id = ?`, [id]);
            if (!u.length) return res.status(404).json({ success: false, message: 'غير موجود' });
            if (u[0].role === 'admin') {
                return res.status(400).json({ success: false, message: 'لا يمكن تعطيل حساب مدير' });
            }
            await User.updateActiveFlag(id, activeVal === 1);
            res.json({ success: true, message: activeVal ? 'تم التفعيل' : 'تم التعطيل' });
        } catch (error) {
            console.error('[AdminController] setUserActive:', error);
            res.status(500).json({ success: false, message: 'خطأ في التحديث' });
        }
    },

    browseShipments: async (req, res) => {
        try {
            const { q, status, dateFrom, dateTo } = req.query;
            const { page, limit, offset } = pagination(req, 100);
            const params = [];
            let where = 'WHERE 1=1';

            if (status) {
                where += ' AND s.status = ?';
                params.push(status);
            }
            if (q && String(q).trim()) {
                const like = `%${String(q).trim()}%`;
                where += ` AND (CAST(s.id AS CHAR) LIKE ? OR s.pickup_address LIKE ? OR s.dropoff_address LIKE ?
                     OR ship.full_name LIKE ? OR drv.full_name LIKE ?)`;
                params.push(like, like, like, like, like);
            }
            if (dateFrom) {
                where += ' AND s.created_at >= ?';
                params.push(dateFrom);
            }
            if (dateTo) {
                where += ' AND s.created_at < DATE_ADD(?, INTERVAL 1 DAY)';
                params.push(dateTo);
            }

            const [[countRow]] = await pool.execute(
                `SELECT COUNT(*) AS total FROM shipments s
                 LEFT JOIN users ship ON ship.id = s.shipper_id
                 LEFT JOIN users drv ON drv.id = s.driver_id
                 ${where}`,
                params
            );

            const [rows] = await pool.execute(
                `SELECT s.*,
                        ship.full_name AS shipper_name,
                        drv.full_name AS driver_name,
                        COALESCE(s.final_price, s.base_price) AS final_price
                 FROM shipments s
                 LEFT JOIN users ship ON ship.id = s.shipper_id
                 LEFT JOIN users drv ON drv.id = s.driver_id
                 ${where}
                 ORDER BY s.created_at DESC
                 LIMIT ? OFFSET ?`,
                [...params, limit, offset]
            );

            res.json({
                success: true,
                data: rows,
                pagination: {
                    page,
                    limit,
                    total: countRow.total,
                    totalPages: Math.ceil(countRow.total / limit) || 1,
                },
            });
        } catch (error) {
            console.error('[AdminController] browseShipments:', error);
            res.status(500).json({ success: false, message: 'خطأ في جلب الشحنات' });
        }
    },

    listDisputes: async (req, res) => {
        try {
            if (!(await disputesTableReady())) {
                return res.json({
                    success: true,
                    data: [],
                    pagination: { page: 1, limit: 20, total: 0, totalPages: 1 },
                    message: 'جدول التظلمات غير مهيأ — شغّل migrations_06_admin_dashboard.sql',
                });
            }

            const { status, q } = req.query;
            const { page, limit, offset } = pagination(req, 100);
            const params = [];
            let where = 'WHERE 1=1';

            if (status && ['open', 'approved', 'rejected'].includes(status)) {
                where += ' AND d.status = ?';
                params.push(status);
            }
            if (q && String(q).trim()) {
                const like = `%${String(q).trim()}%`;
                where += ' AND (drv.full_name LIKE ? OR CAST(d.shipment_id AS CHAR) LIKE ? OR d.dispute_reason LIKE ?)';
                params.push(like, like, like);
            }

            const [[countRow]] = await pool.execute(
                `SELECT COUNT(*) AS total FROM disputes d
                 JOIN users drv ON drv.id = d.driver_id ${where}`,
                params
            );

            const [rows] = await pool.execute(
                `SELECT d.id, d.id AS transaction_id, d.shipment_id, d.driver_id, d.amount,
                        d.dispute_reason, d.status, d.created_at, d.resolved_at,
                        drv.full_name AS driver_name
                 FROM disputes d
                 JOIN users drv ON drv.id = d.driver_id
                 ${where}
                 ORDER BY d.created_at DESC
                 LIMIT ? OFFSET ?`,
                [...params, limit, offset]
            );

            res.json({
                success: true,
                data: rows,
                pagination: {
                    page,
                    limit,
                    total: countRow.total,
                    totalPages: Math.ceil(countRow.total / limit) || 1,
                },
            });
        } catch (error) {
            console.error('[AdminController] listDisputes:', error);
            res.status(500).json({ success: false, message: 'خطأ في التظلمات' });
        }
    },

    resolveDispute: async (req, res) => {
        try {
            if (!(await disputesTableReady())) {
                return res.status(400).json({ success: false, message: 'جدول التظلمات غير متوفر' });
            }
            const id = req.params.id || req.body.transactionId || req.body.disputeId;
            const status = req.body.status;
            if (!id) return res.status(400).json({ success: false, message: 'معرف التظلم مفقود' });
            if (!['approved', 'rejected'].includes(status)) {
                return res.status(400).json({ success: false, message: 'حالة غير صالحة' });
            }
            const newStatus = status === 'approved' ? 'approved' : 'rejected';
            await pool.execute(
                `UPDATE disputes SET status = ?, resolved_at = CURRENT_TIMESTAMP WHERE id = ? AND status = 'open'`,
                [newStatus, id]
            );
            res.json({ success: true, message: 'تم تحديث التظلم' });
        } catch (error) {
            console.error('[AdminController] resolveDispute:', error);
            res.status(500).json({ success: false, message: 'فشل التحديث' });
        }
    },

    getUsers: async (req, res) => {
        try {
            const cols = await getUsersColumnSet();
            const activeSel = cols.has('is_active') ? ', COALESCE(is_active,1) AS is_active' : '';
            const [rows] = await pool.execute(
                `SELECT id, full_name, email, phone, role, verification_status, created_at ${activeSel} FROM users ORDER BY created_at DESC`
            );
            res.json({ success: true, data: rows });
        } catch (error) {
            console.error('[AdminController] Error in getUsers:', error);
            res.status(500).json({ success: false, message: 'خطأ في جلب المستخدمين' });
        }
    },

    getShipments: async (req, res) => {
        try {
            const [rows] = await pool.execute(`
                SELECT s.*, u.full_name AS shipper_name,
                       COALESCE(s.final_price, s.base_price) AS final_price
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

    getPendingUsers: async (req, res) => {
        try {
            const wantPage = req.query.page !== undefined || req.query.limit !== undefined;
            const { page, limit, offset } = pagination(req, 200);

            const countSql = `
                SELECT COUNT(*) AS total FROM users u
                JOIN compliance_documents cd ON u.id = cd.user_id
                WHERE cd.is_verified = 0
            `;
            const [[countRow]] = await pool.execute(countSql);

            const dataSql = `
                SELECT
                    u.id AS user_id,
                    u.full_name,
                    u.phone,
                    u.role,
                    cd.document_id,
                    cd.document_type,
                    cd.document_url,
                    cd.uploaded_at
                FROM users u
                JOIN compliance_documents cd ON u.id = cd.user_id
                WHERE cd.is_verified = 0
                ORDER BY cd.uploaded_at ASC
                ${wantPage ? 'LIMIT ? OFFSET ?' : ''}
            `;
            const params = wantPage ? [limit, offset] : [];
            const [rows] = wantPage
                ? await pool.execute(dataSql, params)
                : await pool.execute(dataSql);

            if (wantPage) {
                return res.json({
                    success: true,
                    data: rows,
                    pagination: {
                        page,
                        limit,
                        total: countRow.total,
                        totalPages: Math.ceil(countRow.total / limit) || 1,
                    },
                });
            }
            res.json({ success: true, data: rows });
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

            const finalStatus = status === 'verified' ? 1 : status === 'rejected' ? 2 : 0;

            await pool.execute(
                'UPDATE compliance_documents SET is_verified = ?, verified_by = ?, verified_at = CURRENT_TIMESTAMP, verification_notes = ? WHERE document_id = ?',
                [finalStatus, adminId, notes, docId]
            );

            if (status === 'verified') {
                const [docRows] = await pool.execute(
                    'SELECT user_id FROM compliance_documents WHERE document_id = ?',
                    [docId]
                );
                if (docRows.length > 0) {
                    await pool.execute('UPDATE users SET verification_status = "verified" WHERE id = ?', [
                        docRows[0].user_id,
                    ]);
                }
            } else if (status === 'rejected') {
                const [docRows] = await pool.execute(
                    'SELECT user_id FROM compliance_documents WHERE document_id = ?',
                    [docId]
                );
                if (docRows.length > 0) {
                    await pool.execute('UPDATE users SET verification_status = "rejected" WHERE id = ?', [
                        docRows[0].user_id,
                    ]);
                }
            }

            res.json({ success: true, message: 'تم تحديث الحالة بنجاح' });
        } catch (error) {
            console.error('[AdminController] Error in verifyDocument:', error);
            res.status(500).json({ success: false, message: 'فشل التحديث: ' + error.message });
        }
    },

    /** Stream file through API (Bearer auth) — avoids broken presigned URLs & iframe/X-Frame blocks */
    streamDocumentPreview: async (req, res) => {
        const raw = req.query.url;
        if (!raw || typeof raw !== 'string') {
            return res.status(400).json({ success: false, message: 'الرابط مفقود' });
        }
        return sendDocumentPreviewForRaw(raw, res);
    },

    /** نفس البث لكن المسار يُجلب من قاعدة البيانات (أثبت من ?url= مع الروابط الطويلة/الترميز) */
    streamDocumentPreviewById: async (req, res) => {
        try {
            const docId = parseInt(String(req.params.docId || ''), 10);
            if (!docId) {
                return res.status(400).json({ success: false, message: 'معرف المستند غير صالح' });
            }
            const [rows] = await pool.execute(
                'SELECT document_url FROM compliance_documents WHERE document_id = ? LIMIT 1',
                [docId]
            );
            if (!rows?.length || !rows[0].document_url) {
                return res.status(404).json({ success: false, message: 'المستند غير موجود في قاعدة البيانات' });
            }
            return sendDocumentPreviewForRaw(String(rows[0].document_url).trim(), res);
        } catch (error) {
            console.error('[AdminController] streamDocumentPreviewById:', error);
            return res.status(500).json({ success: false, message: 'فشل جلب المستند' });
        }
    },

    getSignedUrl: async (req, res) => {
        try {
            let urlRef = req.query.url;
            if (!urlRef && req.query.docId) {
                const docId = parseInt(String(req.query.docId || ''), 10);
                if (!docId) {
                    return res.status(400).json({ success: false, message: 'معرف المستند غير صالح' });
                }
                const [rows] = await pool.execute(
                    'SELECT document_url FROM compliance_documents WHERE document_id = ? LIMIT 1',
                    [docId]
                );
                if (!rows?.length || !rows[0].document_url) {
                    return res.status(404).json({ success: false, message: 'المستند غير موجود' });
                }
                urlRef = rows[0].document_url;
            }
            if (!urlRef) return res.status(400).json({ success: false, message: 'الرابط مفقود' });

            const raw = String(urlRef || '').trim();
            let signedUrl = await generatePresignedUrl(raw);

            if (!signedUrl && (raw.startsWith('http://') || raw.startsWith('https://'))) {
                signedUrl = raw;
            }

            if (!signedUrl) {
                return res.status(503).json({
                    success: false,
                    message:
                        'تعذر توليد رابط مؤقت. تحقق من MinIO أو استخدم معاينة المستند من لوحة التحكم.',
                });
            }

            const fileType = inferPreviewKindFromRef(raw);

            console.log(`[AdminController] Signing URL for ${fileType}:`, raw);
            res.json({ success: true, signedUrl, fileType, previewKind: fileType });
        } catch (error) {
            console.error('[AdminController] Error signing URL:', error);
            res.status(500).json({ success: false, message: 'فشل توقيع الرابط' });
        }
    },

    verifyUser: async (req, res) => {
        try {
            const { id } = req.params;
            await pool.execute('UPDATE users SET verification_status = "verified" WHERE id = ?', [id]);
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
};

module.exports = AdminController;
