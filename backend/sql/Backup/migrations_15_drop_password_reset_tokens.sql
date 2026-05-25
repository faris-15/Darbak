-- Optional: إزالة جدول رموز إعادة التعيين المحلية بعد التحويل إلى Firebase Auth.
-- نفّذ يدوياً على قاعدة البيانات عندما تتأكد أن التطبيق لا يعتمد على المسارات القديمة.
DROP TABLE IF EXISTS password_reset_tokens;
