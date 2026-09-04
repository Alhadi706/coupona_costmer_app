const crypto = require('crypto');

module.exports = function registerCommunityMarketplaceRoutes(app, deps) {
  const {
    pool, auth, id, ensurePrivateChatBetweenUsers, getMerchantProfileIdByUser
  } = deps;

  // Helper to calculate points valuation: 10 Points = 1 LYD
  const VALUATION_POINTS_PER_LYD = 10;

  // 1. Create Customer Community Offer
  app.post('/api/customer/community-offers', auth, async (req, res) => {
    try {
      const customerId = req.user && req.user.id;
      if (!customerId) {
        return res.status(401).json({ ok: false, error: 'unauthorized' });
      }

      const {
        title,
        description,
        category,
        images,
        price_lyd,
        accepts_points_trade,
        visibility_scope,
      } = req.body || {};

      if (!title || !description || !category) {
        return res.status(400).json({ ok: false, error: 'missing_required_fields' });
      }

      const validCategories = ['FOOD', 'REAL_ESTATE', 'SERVICES', 'RENTALS'];
      const normalizedCat = String(category).toUpperCase();
      if (!validCategories.includes(normalizedCat)) {
        return res.status(400).json({ ok: false, error: 'invalid_category' });
      }

      const validScopes = ['PUBLIC_COMMUNITY', 'MY_MERCHANTS_ONLY'];
      const scope = validScopes.includes(visibility_scope) ? visibility_scope : 'PUBLIC_COMMUNITY';
      const price = Math.max(0, Number(price_lyd) || 0);
      const pointsTrade = Boolean(accepts_points_trade);
      const imagesArr = Array.isArray(images) ? images : [];

      const offerId = id();

      const result = await pool.query(
        `INSERT INTO community_offers (
          id, customer_id, title, description, category, images_json, price_lyd, accepts_points_trade, visibility_scope, status
        ) VALUES (
          $1, $2, $3, $4, $5, $6::jsonb, $7, $8, $9, 'ACTIVE'
        ) RETURNING *`,
        [
          offerId,
          customerId,
          title.trim(),
          description.trim(),
          normalizedCat,
          JSON.stringify(imagesArr),
          price,
          pointsTrade,
          scope,
        ]
      );

      const offer = result.rows[0];
      offer.points_required = Math.round(Number(offer.price_lyd) * VALUATION_POINTS_PER_LYD);

      return res.json({ ok: true, offer });
    } catch (err) {
      console.error('[CommunityMarketplace] Error creating offer:', err);
      return res.status(500).json({ ok: false, error: 'internal_server_error' });
    }
  });

  // 2. Get Customer Community Offers (Feed)
  app.get('/api/customer/community-offers', auth, async (req, res) => {
    try {
      const customerId = req.user ? req.user.id : null;
      const { category, visibility_scope, status, search, my_only } = req.query || {};

      let sql = `
        SELECT 
          o.*,
          u.email as seller_email,
          u.name as seller_name,
          u.phone as seller_phone
        FROM community_offers o
        LEFT JOIN users u ON u.id = o.customer_id
        WHERE 1=1
      `;
      const values = [];

      if (my_only === 'true' && customerId) {
        values.push(customerId);
        sql += ` AND o.customer_id = $${values.length}`;
      }

      if (category && category !== 'ALL') {
        values.push(String(category).toUpperCase());
        sql += ` AND o.category = $${values.length}`;
      }

      if (visibility_scope) {
        values.push(visibility_scope);
        sql += ` AND o.visibility_scope = $${values.length}`;
      }

      if (status && status !== 'ALL') {
        values.push(status);
        sql += ` AND o.status = $${values.length}`;
      } else if (!status) {
        sql += ` AND o.status = 'ACTIVE'`;
      }

      if (search && String(search).trim()) {
        values.push(`%${String(search).trim()}%`);
        sql += ` AND (o.title ILIKE $${values.length} OR o.description ILIKE $${values.length})`;
      }

      sql += ` ORDER BY o.created_at DESC LIMIT 100`;

      const { rows } = await pool.query(sql, values);

      const offers = rows.map((row) => ({
        ...row,
        price_lyd: Number(row.price_lyd),
        points_required: Math.round(Number(row.price_lyd) * VALUATION_POINTS_PER_LYD),
        images: Array.isArray(row.images_json) ? row.images_json : [],
        is_owner: customerId ? row.customer_id === customerId : false,
      }));

      return res.json({ ok: true, offers });
    } catch (err) {
      console.error('[CommunityMarketplace] Error fetching customer offers:', err);
      return res.status(500).json({ ok: false, error: 'internal_server_error' });
    }
  });

  // 3. Update Offer Status
  app.patch('/api/customer/community-offers/:id/status', auth, async (req, res) => {
    try {
      const customerId = req.user && req.user.id;
      const offerId = req.params.id;
      const { status } = req.body || {};

      if (!['ACTIVE', 'SOLD', 'ARCHIVED'].includes(status)) {
        return res.status(400).json({ ok: false, error: 'invalid_status' });
      }

      const result = await pool.query(
        `UPDATE community_offers 
         SET status = $1, updated_at = NOW()
         WHERE id = $2 AND customer_id = $3
         RETURNING *`,
        [status, offerId, customerId]
      );

      if (result.rowCount === 0) {
        return res.status(404).json({ ok: false, error: 'offer_not_found_or_forbidden' });
      }

      return res.json({ ok: true, offer: result.rows[0] });
    } catch (err) {
      console.error('[CommunityMarketplace] Error updating status:', err);
      return res.status(500).json({ ok: false, error: 'internal_server_error' });
    }
  });

  // 4. Contact Offer Seller (Chat CTA)
  app.post('/api/customer/community-offers/:id/contact', auth, async (req, res) => {
    try {
      const buyerId = req.user && req.user.id;
      const offerId = req.params.id;

      const offerRes = await pool.query('SELECT * FROM community_offers WHERE id = $1', [offerId]);
      if (offerRes.rows.length === 0) {
        return res.status(404).json({ ok: false, error: 'offer_not_found' });
      }

      const offer = offerRes.rows[0];
      const sellerId = offer.customer_id;

      if (buyerId === sellerId) {
        return res.status(400).json({ ok: false, error: 'cannot_contact_self' });
      }

      const chat = await ensurePrivateChatBetweenUsers(buyerId, sellerId, `استفسار حول: ${offer.title}`);
      return res.json({ ok: true, chatId: chat.id, sellerId, offerTitle: offer.title });
    } catch (err) {
      console.error('[CommunityMarketplace] Error contacting seller:', err);
      return res.status(500).json({ ok: false, error: 'internal_server_error' });
    }
  });

  // 5. Merchant Dashboard View: Customer Offers ("عروض وزبائنك")
  app.get('/api/merchant/customer-offers', auth, async (req, res) => {
    try {
      const userId = req.user && req.user.id;
      let merchantProfileId = null;

      if (typeof getMerchantProfileIdByUser === 'function') {
        merchantProfileId = await getMerchantProfileIdByUser(userId);
      }

      // If not directly found, lookup merchant_profiles where owner_user_id = userId
      if (!merchantProfileId) {
        const mpRes = await pool.query('SELECT id FROM merchant_profiles WHERE owner_user_id = $1 LIMIT 1', [userId]);
        if (mpRes.rows.length > 0) {
          merchantProfileId = mpRes.rows[0].id;
        }
      }

      if (!merchantProfileId) {
        return res.status(403).json({ ok: false, error: 'merchant_profile_required' });
      }

      // Query active offers where:
      // 1. PUBLIC_COMMUNITY OR
      // 2. MY_MERCHANTS_ONLY AND exists transaction history (scans or claims) between customer and this merchant.
      const querySql = `
        SELECT 
          o.*,
          u.name as seller_name,
          u.email as seller_email,
          u.phone as seller_phone,
          COALESCE((
            SELECT COUNT(*) FROM invoice_scans 
            WHERE owner_id = o.customer_id AND merchant_profile_id = $1
          ), 0) +
          COALESCE((
            SELECT COUNT(*) FROM reward_claims 
            WHERE owner_id = o.customer_id AND merchant_id = $1
          ), 0) as total_orders
        FROM community_offers o
        JOIN users u ON u.id = o.customer_id
        WHERE o.status = 'ACTIVE'
          AND (
            o.visibility_scope = 'PUBLIC_COMMUNITY'
            OR (
              o.visibility_scope = 'MY_MERCHANTS_ONLY'
              AND (
                EXISTS (SELECT 1 FROM invoice_scans WHERE owner_id = o.customer_id AND merchant_profile_id = $1)
                OR EXISTS (SELECT 1 FROM reward_claims WHERE owner_id = o.customer_id AND merchant_id = $1)
              )
            )
          )
        ORDER BY total_orders DESC, o.created_at DESC
        LIMIT 100
      `;

      const { rows } = await pool.query(querySql, [merchantProfileId]);

      const customerOffers = rows.map((row) => {
        const totalOrders = Number(row.total_orders || 0);
        let loyaltyBadge = 'زبون مجتمعي (عرض عام)';
        if (totalOrders > 0) {
          loyaltyBadge = `زبون دائم لدى متجرك - ${totalOrders} طلب سابق`;
        }

        return {
          ...row,
          price_lyd: Number(row.price_lyd),
          points_required: Math.round(Number(row.price_lyd) * VALUATION_POINTS_PER_LYD),
          images: Array.isArray(row.images_json) ? row.images_json : [],
          total_orders: totalOrders,
          loyalty_badge: loyaltyBadge,
          is_frequent_customer: totalOrders > 0,
        };
      });

      return res.json({ ok: true, offers: customerOffers, merchantProfileId });
    } catch (err) {
      console.error('[CommunityMarketplace] Error fetching merchant customer offers:', err);
      return res.status(500).json({ ok: false, error: 'internal_server_error' });
    }
  });
};
