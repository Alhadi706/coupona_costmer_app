// Thin entrypoint: wires together the modules under src/ and starts the HTTP server.
// See src/INDEX.md for a map of what lives where.
const { app, ...appConsts } = require('./src/app');
const { pool, CANONICAL_ROLES } = require('./src/db');
const helpers = require('./src/helpers');
const accessControl = require('./src/access-control');
const servicesSocial = require('./src/services-social');
const servicesMatching = require('./src/services-matching');
const createCoreTables = require('./src/schema-core');
const createExtraTables = require('./src/schema-extra');
const createCoalitionTables = require('./src/schema-coalition');
const createCampaignTables = require('./src/schema-campaigns');
const pendingPointsService = require('./src/pending-points-service');
const rewardClaimService = require('./src/reward-claim-service');

const deps = {
  pool,
  CANONICAL_ROLES,
  ...appConsts,
  ...helpers,
  ...accessControl,
  ...servicesSocial,
  ...servicesMatching,
  ...pendingPointsService,
};

const { AI_ONLY_MODE, DEV_OWNER_BYPASS, PORT } = deps;
const { runSubscriptionTransitions, insertNotification } = servicesSocial;
const { getIntSetting } = accessControl;

[
  './src/routes/auth',
  './src/routes/roles-subscriptions',
  './src/routes/merchant',
  './src/routes/merchant-team',
  './src/routes/brand-team',
  './src/routes/wallet-actions',
  './src/routes/invoices',
  './src/routes/reports',
  './src/routes/exchange-rewards',
  './src/routes/reward-funding',
  './src/routes/peerads-sourcing-admin',
  './src/routes/notifications-community',
  './src/routes/offers-billboard',
  './src/routes/legacy-groups-chat',
  './src/routes/users',
  './src/routes/rewards',
  './src/routes/invoices-legacy-scan',
  './src/routes/analytics',
  './src/routes/wallet-core',
  './src/routes/offers-lifecycle-stats',
  './src/routes/merchant-token-wallet',
  './src/routes/brand-token-wallet',
  './src/routes/public-coalition-membership',
  './src/routes/coalition',
  './src/routes/campaigns',
].forEach((modulePath) => require(modulePath)(app, deps));

async function initSchema() {
  await createCoreTables();
  await createExtraTables();
  await createCoalitionTables(pool);
  await createCampaignTables();
}

if (AI_ONLY_MODE) {
  app.listen(PORT, DEV_OWNER_BYPASS ? '127.0.0.1' : undefined, () => {
    console.log(`Kupuna AI-only API listening on ${PORT}`);
  });
} else {
  initSchema()
    .then(() => {
      app.listen(PORT, DEV_OWNER_BYPASS ? '127.0.0.1' : undefined, () => {
        console.log(`Kupuna company API listening on ${PORT}`);
      });
      setInterval(() => {
        runSubscriptionTransitions().catch((e) => {
          console.error('Subscription transition runner failed', e);
        });
        pool.connect().then(async (client) => {
          try {
            await client.query('BEGIN');
            await pendingPointsService.convertExpiredPendingPoints(client, insertNotification);
            await rewardClaimService.processExpiredRewardClaims(client, helpers.id);
            await client.query('COMMIT');
          } catch (e) {
            await client.query('ROLLBACK');
            console.error('Pending points expiry job failed', e);
          } finally {
            client.release();
          }
        }).catch((e) => console.error('Pending points job connection failed', e));
      }, 60 * 60 * 1000);
    })
    .catch((e) => {
      console.error('Failed to initialize schema', e);
      process.exit(1);
    });
}
