import 'package:flutter/foundation.dart';

/// Tab indices of the "Communities & Marketplace" hub screen.
class CommunityHubTabs {
  const CommunityHubTabs._();

  static const int groups = 0;
  static const int privateMessages = 1;
  static const int marketplace = 2;
}

/// Lets outside shortcuts ask the hub screen to switch tabs.
/// Notifies on every request, even when the index is unchanged, so repeated
/// taps on the same shortcut always re-select the target tab.
class CommunityTabRequest extends ChangeNotifier {
  int _index = CommunityHubTabs.groups;

  int get index => _index;

  void request(int index) {
    _index = index;
    notifyListeners();
  }
}
