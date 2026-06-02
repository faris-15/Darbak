'use strict';

const sendPushToUser = jest.fn(async () => ({ ok: true }));
const sendPushToTopic = jest.fn(async () => ({ ok: true }));

module.exports = {
  sendPushToUser,
  sendPushToTopic,
  __reset() {
    sendPushToUser.mockClear();
    sendPushToTopic.mockClear();
  },
};
