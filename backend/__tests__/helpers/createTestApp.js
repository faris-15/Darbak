const express = require('express');

function createTestApp(basePath, router) {
  const app = express();
  app.use(express.json({ limit: '1mb' }));
  app.use(basePath, router);
  app.use((err, req, res, next) => {
    if (err && err.type === 'entity.parse.failed') {
      return res.status(400).json({
        success: false,
        message: 'Malformed JSON payload',
      });
    }
    return next(err);
  });
  return app;
}

module.exports = { createTestApp };
