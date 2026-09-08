part of 'package:coupona_app/screens/merchant_dashboard_screen.dart';

// ── Formatting & Conversion Helpers ──

class _MerchantDashboardHelpers {
  static double toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse((value ?? '').toString()) ?? 0;
  }

  static String tx(String key, String fallback) {
    final value = key.tr();
    return value == key ? fallback : value;
  }

  static String money(dynamic value) => toDouble(value).toStringAsFixed(2);

  static String numValue(dynamic value) => toDouble(value).toStringAsFixed(2);

  static int intValue(dynamic value) => 
    int.tryParse('${value ?? 0}') ?? toDouble(value).round();

  static String localizeSubscriptionStatus(String raw) {
    switch (raw.toLowerCase()) {
      case 'trial':
        return tx('subscription_status_trial', 'Trial');
      case 'active':
        return tx('subscription_status_active', 'Active');
      case 'grace_period':
        return tx('subscription_status_grace_period', 'Grace period');
      case 'suspended':
        return tx('subscription_status_suspended', 'Suspended');
      default:
        return localizeGenericStatus(raw);
    }
  }

  static String localizeGenericStatus(dynamic rawStatus) {
    final String status = (rawStatus ?? '').toString().trim().toLowerCase();
    switch (status) {
      case 'pending_admin_review':
        return tx('status_pending_admin_review', 'Pending admin review');
      case 'pending_review':
        return tx('status_pending_review', 'Pending review');
      case 'approved':
        return tx('status_approved', 'Approved');
      case 'active':
        return tx('status_active', 'Active');
      case 'trial':
        return tx('status_trial', 'Trial');
      case 'grace_period':
        return tx('status_grace_period', 'Grace period');
      case 'suspended':
        return tx('status_suspended', 'Suspended');
      case 'under_review':
        return tx('status_under_review', 'Under review');
      case 'pending':
        return tx('status_pending', 'Pending');
      case 'processing':
        return tx('status_processing', 'Processing');
      case 'rejected':
        return tx('status_rejected', 'Rejected');
      case 'redeemed':
        return tx('status_redeemed', 'Redeemed');
      case 'expired':
        return tx('status_expired', 'Expired');
      case 'archived':
        return tx('status_archived', 'Archived');
      case '':
        return '-';
      default:
        return tx('status_unknown', 'Unknown');
    }
  }

}
