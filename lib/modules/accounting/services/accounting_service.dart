import '../../../services/company_server_service.dart';
import '../models/ledger_entry.dart';
import '../models/point_account.dart';
import '../models/wallet_account.dart';

class AccountingService {
  Future<void> ensureAccountingDocuments() async {
    await CompanyServerService.ensureAccountingDocuments();
  }

  Stream<WalletAccount> watchWallet() {
    return Stream.periodic(const Duration(seconds: 5))
        .asyncMap((_) => CompanyServerService.getWallet())
        .startWithFuture(CompanyServerService.getWallet())
        .map((map) => WalletAccount.fromMap(map));
  }

  Stream<PointAccount> watchPointAccount() {
    return Stream.periodic(const Duration(seconds: 5))
        .asyncMap((_) => CompanyServerService.getPointAccount())
        .startWithFuture(CompanyServerService.getPointAccount())
        .map((map) => PointAccount.fromMap(map));
  }

  Stream<List<LedgerEntry>> watchLedgerEntries({int limit = 50}) {
    return Stream.periodic(const Duration(seconds: 5))
        .asyncMap((_) => CompanyServerService.getLedgerEntries(limit: limit))
        .startWithFuture(CompanyServerService.getLedgerEntries(limit: limit))
        .map((rows) => rows.map(LedgerEntry.fromMap).toList());
  }

  Future<void> applyCashbackFromPurchase({
    required double purchaseAmount,
    required String reference,
  }) async {
    await CompanyServerService.applyCashbackFromPurchase(
      purchaseAmount: purchaseAmount,
      reference: reference,
    );
  }

  Future<void> redeemPoints({
    required int points,
    required String reference,
  }) async {
    await CompanyServerService.redeemPoints(
      points: points,
      reference: reference,
    );
  }
}

extension _StreamInit<T> on Stream<T> {
  Stream<T> startWithFuture(Future<T> first) async* {
    yield await first;
    yield* this;
  }
}
