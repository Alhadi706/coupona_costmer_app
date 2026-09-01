// Dynamic Point Valuation & Marketing Multiplier Service
// Implements pro_rata_coalition_engine_v3 point economics

/**
 * Platform standard: 1 Point = 0.10 Local Currency Unit
 * This creates fast-moving counters for better psychological reward perception
 * 
 * Examples:
 * - 10 Points = 1.00 LYD/USD/EGP/SAR
 * - 100 Points = 10.00 currency units
 */
const POINT_TO_CURRENCY_RATIO = 0.10;

/**
 * Calculate points earned from a purchase amount
 * @param {number} purchaseAmount - Amount spent in local currency
 * @param {number} merchantEarningRate - Merchant's custom earning rate (0-100)
 * @returns {number} Points earned
 * 
 * Example: 100 LYD purchase at 10% earning rate = 100 points (10 LYD value)
 */
function calculatePointsEarned(purchaseAmount, merchantEarningRate = 10) {
  if (!purchaseAmount || purchaseAmount <= 0) return 0;
  if (!merchantEarningRate || merchantEarningRate <= 0) return 0;
  
  const earnedValue = purchaseAmount * (merchantEarningRate / 100);
  const points = Math.floor(earnedValue / POINT_TO_CURRENCY_RATIO);
  return points;
}

/**
 * Calculate monetary value of points
 * @param {number} points - Number of points
 * @returns {number} Monetary value in local currency
 */
function pointsToMonetary(points) {
  if (!points || points <= 0) return 0;
  return points * POINT_TO_CURRENCY_RATIO;
}

/**
 * Calculate points needed for a monetary value
 * @param {number} monetaryValue - Value in local currency
 * @returns {number} Required points
 */
function monetaryToPoints(monetaryValue) {
  if (!monetaryValue || monetaryValue <= 0) return 0;
  return Math.ceil(monetaryValue / POINT_TO_CURRENCY_RATIO);
}

/**
 * Apply campaign discount to point threshold
 * @param {number} basePoints - Original point requirement
 * @param {number} discountPercentage - Discount % (0-100)
 * @returns {number} Discounted point requirement
 */
function applyDiscountToPoints(basePoints, discountPercentage) {
  if (!discountPercentage || discountPercentage <= 0) return basePoints;
  const discount = Math.min(100, Math.max(0, discountPercentage));
  return Math.floor(basePoints * (1 - discount / 100));
}

/**
 * Check if customer qualifies for campaign-specific pricing
 * @param {object} customer - Customer record with purchase history
 * @param {object} targeting - Campaign targeting rules
 * @returns {boolean} Whether customer qualifies
 */
function qualifiesForCampaign(customer, targeting) {
  if (!targeting) return false;
  
  // New acquisition campaign: no previous purchases at this merchant
  if (targeting.target_new_customers && customer.purchase_count > 0) {
    return false;
  }
  
  // VIP campaign: meets minimum purchase frequency
  if (targeting.target_vip_customers && targeting.min_purchase_frequency) {
    if (customer.purchase_count < targeting.min_purchase_frequency) {
      return false;
    }
  }
  
  // Recency check
  if (targeting.max_days_since_last_visit && customer.days_since_last_visit) {
    if (customer.days_since_last_visit > targeting.max_days_since_last_visit) {
      return false;
    }
  }
  
  return true;
}

/**
 * Calculate pro-rata split for multi-merchant redemption
 * @param {Array} pointBalances - Array of {merchantId, points} objects
 * @param {number} totalPointsNeeded - Total points required for gift
 * @returns {Array} Array of {merchantId, pointsUsed, percentage} objects
 */
function calculateProRataSplit(pointBalances, totalPointsNeeded) {
  // Filter merchants with available points
  const available = pointBalances.filter(b => b.points > 0);
  
  if (available.length === 0) {
    throw new Error('No available points for redemption');
  }
  
  const totalAvailable = available.reduce((sum, b) => sum + b.points, 0);
  
  if (totalAvailable < totalPointsNeeded) {
    throw new Error(`Insufficient points: need ${totalPointsNeeded}, have ${totalAvailable}`);
  }
  
  const splits = [];
  let remaining = totalPointsNeeded;
  
  // Sort by contribution (largest first) for fair distribution
  const sorted = [...available].sort((a, b) => b.points - a.points);
  
  for (let i = 0; i < sorted.length; i++) {
    const balance = sorted[i];
    const isLast = i === sorted.length - 1;
    
    if (remaining <= 0) break;
    
    // Last merchant gets exactly the remaining amount
    const pointsUsed = isLast ? remaining : Math.min(balance.points, remaining);
    const percentage = (pointsUsed / totalPointsNeeded) * 100;
    
    splits.push({
      merchantId: balance.merchantId,
      merchantName: balance.merchantName,
      pointsUsed,
      percentage: Math.round(percentage * 100) / 100, // 2 decimal precision
    });
    
    remaining -= pointsUsed;
  }
  
  return splits;
}

/**
 * Format co-branded message for customer
 * @param {Array} sponsors - Array of {merchantName, percentage} objects
 * @returns {string} Formatted gratitude message
 */
function formatCoBrandedMessage(sponsors) {
  if (!sponsors || sponsors.length === 0) return '';
  
  if (sponsors.length === 1) {
    return `This gift is brought to you by ${sponsors[0].merchantName} in appreciation of your loyalty.`;
  }
  
  const sponsorList = sponsors
    .map(s => `${s.merchantName} (${s.percentage}%)`)
    .join(', ');
  
  return `This gift was co-sponsored by: ${sponsorList} in appreciation of your combined loyalty across our coalition partners.`;
}

module.exports = {
  POINT_TO_CURRENCY_RATIO,
  calculatePointsEarned,
  pointsToMonetary,
  monetaryToPoints,
  applyDiscountToPoints,
  qualifiesForCampaign,
  calculateProRataSplit,
  formatCoBrandedMessage,
};
