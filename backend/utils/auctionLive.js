/**
 * True only while auction_end_time is strictly in the future (valid timestamp).
 * Missing or invalid deadline → false (do not lock driver actions on "lowest bid").
 */
const isShipmentAuctionStillLive = (shipment) => {
  if (!shipment) return false;
  const raw = shipment.auction_end_time;
  if (raw == null || raw === '') return false;
  const t = new Date(raw).getTime();
  if (Number.isNaN(t)) return false;
  return t > Date.now();
};

module.exports = { isShipmentAuctionStillLive };
