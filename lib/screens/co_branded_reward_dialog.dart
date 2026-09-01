import 'package:flutter/material.dart';

class CoBrandedRewardDialog extends StatelessWidget {
  final String rewardTitle;
  final List<String> sponsorNames;

  const CoBrandedRewardDialog({
    super.key,
    required this.rewardTitle,
    required this.sponsorNames,
  });

  static Future<void> show(
    BuildContext context, {
    required String rewardTitle,
    required List<String> sponsorNames,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => CoBrandedRewardDialog(
        rewardTitle: rewardTitle,
        sponsorNames: sponsorNames,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = sponsorNames.isEmpty ? const <String>['Your favorite stores'] : sponsorNames;
    final namesText = list.length == 1
        ? list.first
        : '${list.sublist(0, list.length - 1).join(', ')}, and ${list.last}';

    return AlertDialog(
      title: const Text('Congratulations!'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This reward was co-sponsored by $namesText in appreciation of your loyalty.',
            style: const TextStyle(fontSize: 15),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.emoji_events_outlined, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rewardTitle,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Nice!'),
        ),
      ],
    );
  }
}
