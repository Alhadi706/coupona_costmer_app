BEGIN;

DELETE FROM promo_campaign_coupons
 WHERE campaign_id IN (
   SELECT id
     FROM promo_campaigns
    WHERE campaign_type = 'free_gift'
      AND gift_definition_id IS NULL
 );

DELETE FROM raffle_tickets
 WHERE campaign_id IN (
   SELECT id
     FROM promo_campaigns
    WHERE campaign_type = 'free_gift'
      AND gift_definition_id IS NULL
 );

DELETE FROM promo_campaigns
 WHERE campaign_type = 'free_gift'
   AND gift_definition_id IS NULL;

COMMIT;