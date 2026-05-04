const pool = require('../config/db');

class ComplianceDocument {
    static async create(data) {
        let { user_id, document_type, document_url, expiry_date, issue_date } = data;

        // تنظيف الرابط لضمان تخزين المسار (Key) فقط
        if (document_url && document_url.includes('http')) {
            try {
                const urlParts = new URL(document_url);
                const pathSegments = urlParts.pathname.split('/');
                // تخطي أول جزئين (السلاش واسم الباكت) للحصول على المسار الفعلي
                document_url = pathSegments.slice(2).join('/');
            } catch (e) {
                console.error("Error parsing URL in Model:", e);
            }
        }

        const [result] = await pool.query(
            `INSERT INTO compliance_documents
            (user_id, document_type, document_url, expiry_date, issue_date)
            VALUES (?, ?, ?, ?, ?)`,
            [user_id, document_type, document_url, expiry_date, issue_date]
        );
        return result.insertId;
    }

    static async findByUserId(userId) {
        const [rows] = await pool.query(
            'SELECT * FROM compliance_documents WHERE user_id = ? ORDER BY created_at DESC',
            [userId]
        );
        return rows;
    }

    static async updateStatus(documentId, status, verifiedBy, notes = null) {
        const [result] = await pool.query(
            `UPDATE compliance_documents
            SET is_verified = ?, verified_by = ?, verified_at = CURRENT_TIMESTAMP, verification_notes = ?
            WHERE document_id = ?`,
            [status === 'verified' ? 1 : 0, verifiedBy, notes, documentId]
        );
        return result.affectedRows > 0;
    }

    static async getPending() {
        const [rows] = await pool.query(
            `SELECT cd.*, u.full_name, u.email
             FROM compliance_documents cd
             JOIN users u ON cd.user_id = u.id
             WHERE cd.is_verified = 0
             ORDER BY cd.uploaded_at ASC`
        );
        return rows;
    }
}

module.exports = ComplianceDocument;
