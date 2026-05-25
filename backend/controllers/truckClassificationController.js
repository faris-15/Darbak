const { exportCatalog } = require('../constants/truckClassification');

const getTruckClassificationCatalog = (_req, res) => {
  res.json(exportCatalog());
};

module.exports = { getTruckClassificationCatalog };
