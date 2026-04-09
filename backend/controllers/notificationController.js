const Notification = require('../models/Notification');
const User = require('../models/User');

const getNotifications = async (req, res) => {
  try {
    const { userId } = req.params;
    const { unreadOnly } = req.query;

    // Check if user exists
    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ message: 'المستخدم غير موجود' });
    }

    const notifications = await Notification.findByUserId(userId, unreadOnly === 'true');
    const unreadCount = await Notification.getUnreadCount(userId);

    res.json({
      user_id: userId,
      unread_count: unreadCount,
      notifications: notifications,
    });
  } catch (error) {
    console.error('Get notifications error:', error);
    res.status(500).json({ message: 'خطأ في جلب التنبيهات' });
  }
};

const markAsRead = async (req, res) => {
  try {
    const { notificationId } = req.params;

    const marked = await Notification.markAsRead(notificationId);
    if (!marked) {
      return res.status(404).json({ message: 'التنبيه غير موجود' });
    }

    res.json({ message: 'تم تحديث التنبيه' });
  } catch (error) {
    console.error('Mark notification as read error:', error);
    res.status(500).json({ message: 'خطأ في تحديث التنبيه' });
  }
};

const markAllAsRead = async (req, res) => {
  try {
    const { user_id } = req.params;

    await Notification.markAllAsRead(user_id);
    res.json({ message: 'تم تحديث جميع التنبيهات' });
  } catch (error) {
    console.error('Mark all notifications as read error:', error);
    res.status(500).json({ message: 'خطأ في تحديث التنبيهات' });
  }
};

const deleteNotification = async (req, res) => {
  try {
    const { notificationId } = req.params;

    const deleted = await Notification.delete(notificationId);
    if (!deleted) {
      return res.status(404).json({ message: 'التنبيه غير موجود' });
    }

    res.json({ message: 'تم حذف التنبيه بنجاح' });
  } catch (error) {
    console.error('Delete notification error:', error);
    res.status(500).json({ message: 'خطأ في حذف التنبيه' });
  }
};

const triggerNotification = async (user_id, title, message) => {
  try {
    const notification = await Notification.create({
      user_id,
      title,
      message,
      is_read: 0,
    });
    return notification;
  } catch (error) {
    console.error('Trigger notification error:', error);
  }
};

module.exports = {
  getNotifications,
  markAsRead,
  markAllAsRead,
  deleteNotification,
  triggerNotification,
};
