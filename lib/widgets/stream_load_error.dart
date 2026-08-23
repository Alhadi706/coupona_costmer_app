import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Small inline placeholder shown when a polling [StreamBuilder] receives an
/// error and has no cached data yet. Without this, screens fed by
/// `Stream.periodic(...).asyncMap(...)` show a [CircularProgressIndicator]
/// forever on failure, because the builder only checks `snapshot.hasData`
/// and never `snapshot.hasError`. The underlying stream keeps ticking on its
/// own interval, so no manual retry action is needed here.
class StreamLoadError extends StatelessWidget {
  const StreamLoadError({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              color: Theme.of(context).colorScheme.error,
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              message ?? 'stream_load_retry_message'.tr(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
