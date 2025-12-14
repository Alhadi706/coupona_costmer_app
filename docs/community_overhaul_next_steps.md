# Community Overhaul: Next Steps

_Last updated: 3 Dec 2025_

## 1. Current Baseline
- `lib/screens/community_screen.dart` now exposes Discover, My Groups, Trending, and Notifications tabs with placeholder data wired to the most relevant Firestore collections.
- UI scaffolding is ready for progressive enhancement; each tab still needs production-ready data sources, state management, and error handling.
- Creation workflows (posts, groups, reports) currently surface snack bars or temporary sheets only.

## 2. Tab Roadmap
### Discover
- Replace placeholder streams with a dedicated feed service (e.g., `discover_feed_repository.dart`) that merges `community_posts`, merchant spotlights, and exclusive offers.
- Implement filter state (chips + query params) and persist the users last-selected filters.
- Add deep links into post detail, merchant profile, and offer redemption screens.
- Integrate a recommendation signal pipeline (location, categories, engagement) before hitting Firestore.

### My Groups
- Build full group discovery (not only member groups) with join/leave mutations and pending-request queues.
- Implement group creation UI, validation, and Firestore writes (`communities` + metadata subcollections).
- Surface role badges (owner/mod/member) and moderation shortcuts per group.
- Flesh out the merchant/customer DM section with unread counts, typing indicators, and attachments (images/receipts).

### Trending
- Move scoring logic into a Cloud Function or scheduled job so clients simply read a `community_trending` collection ordered by `score`.
- Backfill `likes`, `comments`, `shares` counts via aggregation documents to avoid full collection scans.
- Introduce time-bounded segments (Today, This Week, All Time) using composite indexes.

### Notifications
- Standardize the Firestore schema into `community_notifications/{userId}/items` to avoid querying the global `notifications` collection.
- Add action types (post_like, group_invite, reward_unlock, moderation_alert) with routing metadata.
- Set up read/unread tracking plus optional push notifications through FCM.

## 3. Backend & Data Services
- Design new collections: `community_posts`, `community_groups`, `group_messages`, `user_rewards`, `community_reports`, `recommendation_events`.
- Ensure composite indexes exist for queries introduced above (e.g., `community_posts` ordered by `createdAt` + `merchantId`).
- Add Cloud Functions for:
  - post moderation auto-flagging,
  - trending score calculation,
  - reward issuance & expiration,
  - notification fan-out.
- Introduce a recommendation microservice (Supabase Edge Function or Cloud Run) that curates Discover feed inputs.
- Expand `CommunityRepository` to handle membership/state changes atomically.

## 4. Rewards & Engagement
- Define reward tiers, point accrual rules (post, like, referral, redemption), and redemption catalog documents.
- Build `user_achievements` documents for badges and streaks; expose aggregated stats per user profile.

## 5. Moderation & Safety
- Implement report flows from `_PostCard` and chats, writing into `community_reports` with severity levels.
- Provide merchant/community admins a review dashboard (new screen) plus automated escalation (email/Slack hooks).
- Add profanity/image scanning via Cloud Functions before publishing content.

## 6. Analytics & QA
- Instrument tabs with `FirebaseAnalytics` events (view_tab, post_interaction, group_join, notification_action).
- Back QA plan with widget tests for tab switching, StreamBuilders, and chat input; add integration tests covering Firestore mocks.
- Verify firestore.rules updates alongside every new query path before release.

## 7. Launch Checklist
1. Update `docs/firestore.rules` to allow all new collections with proper role-based permissions.
2. Provide migration scripts for existing community data.
3. Prepare release notes + in-app coach marks to introduce the new tabs.
4. Monitor performance dashboards (Firestore reads, functions CPU) after rollout and tune caching where needed.
