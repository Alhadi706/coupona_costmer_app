class InvoiceParseResult {
  final double? total;
  final String? invoiceNumber;
  final String? orderNumber;
  final String? storeName;
  final List<String> storeCandidates;
  final double storeConfidence;
  final String? invoiceDate;
  final String category;
  final List<InvoiceLineItem> items;

  const InvoiceParseResult({
    required this.total,
    required this.invoiceNumber,
    required this.orderNumber,
    required this.storeName,
    this.storeCandidates = const <String>[],
    this.storeConfidence = 0.0,
    required this.invoiceDate,
    required this.category,
    this.items = const <InvoiceLineItem>[],
  });
}

class InvoiceLineItem {
  final String name;
  final int? quantity;
  final double? unitPrice;
  final double? lineTotal;

  const InvoiceLineItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });
}

class _FieldCandidate<T> {
  final T value;
  final int score;

  const _FieldCandidate(this.value, this.score);
}

class _InvoiceTextContext {
  final String rawText;
  final List<String> lines;

  const _InvoiceTextContext({
    required this.rawText,
    required this.lines,
  });
}

class _MerchantAlias {
  final String canonicalName;
  final List<String> hints;

  const _MerchantAlias({
    required this.canonicalName,
    required this.hints,
  });
}

class _MerchantNameCandidate {
  final String value;
  final int score;

  const _MerchantNameCandidate({
    required this.value,
    required this.score,
  });
}

class InvoiceTextParser {
  static const bool merchantNameOnlyMode = false;

  static const List<_MerchantAlias> _merchantAliases = <_MerchantAlias>[
    _MerchantAlias(
      canonicalName: 'سندوتشات نسيم',
      hints: <String>[
        'سندوتشات نسيم',
        'نسيم',
        'naseem',
        'nassem',
        'قصر بن غشير',
        'بن غشير',
      ],
    ),
    _MerchantAlias(
      canonicalName: 'شنابو',
      hints: <String>[
        'شنابو',
        'شنابو',
        'شنابو',
        'شنابو',
        'سنسايو',
        'سنسايو',
        'سنسيايو',
        'سنسيايو',
        'سنابو',
        'شنابو',
        'شنيبو',
        'شناب',
        'شنـابو',
      ],
    ),
  ];

  static bool get isMerchantNameOnlyMode => merchantNameOnlyMode;

  static InvoiceParseResult parse(String text) {
    final normalized = _normalizeForParsing(text);
    final lines = _toLines(normalized);
    final ctx = _InvoiceTextContext(rawText: normalized, lines: lines);

    final storeCandidates = _extractStoreCandidates(ctx);
    final store = storeCandidates.isNotEmpty ? storeCandidates.first : null;
    final storeConfidence = _merchantConfidence(storeCandidates);

    if (merchantNameOnlyMode) {
      return InvoiceParseResult(
        total: null,
        invoiceNumber: null,
        orderNumber: null,
        storeName: store,
        storeCandidates: storeCandidates,
        storeConfidence: storeConfidence,
        invoiceDate: null,
        category: _classifyInvoice(normalized, store, const <InvoiceLineItem>[]),
        items: const <InvoiceLineItem>[],
      );
    }

    final date = _extractInvoiceDate(ctx);
    final orderNumber = _extractOrderNumber(ctx, date);
    final invoiceNumber = _extractInvoiceNumber(ctx, date, orderNumber);
    final items = _extractLineItems(ctx);
    final total = _extractTotal(ctx, items);

    return InvoiceParseResult(
      total: total,
      invoiceNumber: invoiceNumber,
      orderNumber: orderNumber,
      storeName: store,
      storeCandidates: storeCandidates,
      storeConfidence: storeConfidence,
      invoiceDate: date,
      category: _classifyInvoice(normalized, store, items),
      items: items,
    );
  }

  static String _normalizeForParsing(String text) {
    final digitMap = <String, String>{
      '٠': '0',
      '١': '1',
      '٢': '2',
      '٣': '3',
      '٤': '4',
      '٥': '5',
      '٦': '6',
      '٧': '7',
      '٨': '8',
      '٩': '9',
    };
    var out = text;
    digitMap.forEach((k, v) {
      out = out.replaceAll(k, v);
    });
    out = out.replaceAll('٫', '.').replaceAll('٬', ',');
    out = out.replaceAll(RegExp(r'[ \t]+'), ' ');
    return out.trim();
  }

  static List<String> _toLines(String text) {
    return text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  static bool _isPhoneLike(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    return RegExp(r'^09\d{8}$').hasMatch(digits);
  }

  static bool _isLikelyYear(String value) {
    if (!RegExp(r'^\d{4}$').hasMatch(value)) return false;
    final year = int.tryParse(value);
    if (year == null) return false;
    return year >= 1900 && year <= 2100;
  }

  static bool _isDateDigits(String value, String? invoiceDate) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 8) return false;
    if (invoiceDate != null) {
      final dateDigits = invoiceDate.replaceAll(RegExp(r'\D'), '');
      if (dateDigits.isNotEmpty && digits == dateDigits) {
        return true;
      }
    }
    final maybeYmd = RegExp(r'^(19|20)\d{2}(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])$');
    final maybeDmy = RegExp(r'^(0[1-9]|[12]\d|3[01])(0[1-9]|1[0-2])(19|20)\d{2}$');
    return maybeYmd.hasMatch(digits) || maybeDmy.hasMatch(digits);
  }

  static double? _extractTotal(_InvoiceTextContext ctx, List<InvoiceLineItem> items) {
    final lines = ctx.lines;
    final numberPattern = RegExp(r'(?<!\d)(\d{1,5}(?:[\.,]\d{1,2})?)(?!\d)');
    final totalKeyword = RegExp(
      r'المجموع|الاجمالي|الإجمالي|اجمالي|إجمالي|اجمالي\s*الفاتورة|إجمالي\s*الفاتورة|total|grand\s*total|amount\s*due',
      caseSensitive: false,
    );
    final currencyKeyword = RegExp(r'ريال|dl|sar|usd|lyd|دينار', caseSensitive: false);
    final lineItemKeyword = RegExp(r'الكمية|السعر|الصنف|qty|unit|item', caseSensitive: false);
    final refKeyword = RegExp(r'رقم\s*(?:الطلب|الفاتورة)|invoice\s*(?:no|number)|طلبية', caseSensitive: false);
    final phoneLike = RegExp(r'\b09\d{8}\b');

    _FieldCandidate<double>? best;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final matches = numberPattern.allMatches(line).toList();
      if (matches.isEmpty) continue;

      for (final match in matches) {
        final raw = (match.group(1) ?? '').replaceAll(',', '.');
        final value = double.tryParse(raw);
        if (value == null || value <= 0) continue;

        var score = 0;
        if (totalKeyword.hasMatch(line)) score += 80;
        if (currencyKeyword.hasMatch(line)) score += 20;
        if (lineItemKeyword.hasMatch(line)) score -= 30;
        if (refKeyword.hasMatch(line)) score -= 70;
        if (phoneLike.hasMatch(line)) score -= 120;
        if (i >= (lines.length / 2).floor()) score += 12;
        if (i >= (lines.length * 0.7).floor()) score += 10;
        if (value >= 2 && value <= 5000) score += 8;
        if (value > 10000) score -= 60;
        if (raw.contains('.')) score += 6;
        if (!raw.contains('.') && value >= 10 && value <= 500) score += 4;
        if (raw.contains('.') && raw.endsWith('.00')) score += 4;

        // Fallback: in noisy OCR, final total can be the largest plausible value
        // outside lines that look like invoice/order references.
        if (!totalKeyword.hasMatch(line) && !refKeyword.hasMatch(line) && !lineItemKeyword.hasMatch(line)) {
          score += 6;
        }

        final candidate = _FieldCandidate<double>(value, score);
        final currentBest = best;
        if (currentBest == null || candidate.score > currentBest.score || (candidate.score == currentBest.score && candidate.value > currentBest.value)) {
          best = candidate;
        }
      }
    }

    if (best != null && best.score >= 12) {
      return best.value;
    }

    // If keyword detection failed but line-items are reliable, fallback to sum.
    if (items.isNotEmpty) {
      var sum = 0.0;
      var itemCount = 0;
      for (final item in items) {
        final lineTotal = item.lineTotal;
        if (lineTotal == null) continue;
        sum += lineTotal;
        itemCount++;
      }
      if (itemCount >= 1 && sum > 0) {
        return double.parse(sum.toStringAsFixed(2));
      }
    }

    return null;
  }

  static String? _extractInvoiceNumber(_InvoiceTextContext ctx, String? invoiceDate, String? orderNumber) {
    final text = ctx.rawText;
    final lines = ctx.lines;
    final patterns = <RegExp>[
      RegExp(
        r'(?:رقم\s*الفاتورة|فاتورة\s*رقم|invoice\s*(?:no\.?|number)|inv\.?\s*#?)\s*[:\-\/]?\s*([A-Za-z0-9\-\/]{2,})',
        caseSensitive: false,
      ),
      RegExp(r'\b([A-Z]{2,}[\-]?[0-9]{2,}|[0-9]{5,})\b'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final value = (match.group(1) ?? '').replaceAll('/', '').trim();
        if (value.isEmpty) continue;
        if (_isLikelyYear(value)) continue;
        if (_isPhoneLike(value)) continue;
        if (_isDateDigits(value, invoiceDate)) continue;
        if (orderNumber != null && orderNumber.isNotEmpty && value == orderNumber) continue;
        return value;
      }
    }

    final linePattern = RegExp(r'(?:رقم\s*الفاتورة|invoice)', caseSensitive: false);
    for (final line in lines) {
      if (!linePattern.hasMatch(line)) continue;
      final numberMatch = RegExp(r'\b([A-Za-z0-9\-]{2,})\b').allMatches(line).toList();
      for (var i = numberMatch.length - 1; i >= 0; i--) {
        final candidate = (numberMatch[i].group(1) ?? '').trim();
        if (RegExp(r'\d').hasMatch(candidate) && candidate.length >= 2) {
          if (_isLikelyYear(candidate)) continue;
          if (_isPhoneLike(candidate)) continue;
          if (_isDateDigits(candidate, invoiceDate)) continue;
          if (orderNumber != null && orderNumber.isNotEmpty && candidate == orderNumber) continue;
          return candidate;
        }
      }
    }

    return null;
  }

  static String? _extractOrderNumber(_InvoiceTextContext ctx, String? invoiceDate) {
    final text = ctx.rawText;
    final lines = ctx.lines;
    final patterns = <RegExp>[
      RegExp(
        r'(?:رقم\s*الطلب|طلبية\s*رقم|order\s*(?:no\.?|number))\s*[:\-\/]?\s*([A-Za-z0-9\-\/]{1,})',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final value = (match.group(1) ?? '').replaceAll('/', '').trim();
        if (value.isEmpty) continue;
        if (_isPhoneLike(value)) continue;
        if (_isDateDigits(value, invoiceDate)) continue;
        if (_isLikelyYear(value)) continue;
        return value;
      }
    }

    final linePattern = RegExp(r'رقم\s*الطلب|order', caseSensitive: false);
    for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final line = lines[lineIndex];
      if (!linePattern.hasMatch(line)) continue;

      final neighborhood = <String>[line];
      if (lineIndex + 1 < lines.length) neighborhood.add(lines[lineIndex + 1]);
      if (lineIndex + 2 < lines.length) neighborhood.add(lines[lineIndex + 2]);
      if (lineIndex > 0) neighborhood.add(lines[lineIndex - 1]);

      String? best;
      var bestScore = -999;
      for (var n = 0; n < neighborhood.length; n++) {
        final candidateLine = neighborhood[n];
        final number = RegExp(r'\b(\d{1,8})\b').allMatches(candidateLine).toList();
        if (number.isEmpty) continue;

        for (final m in number) {
          final candidate = m.group(1);
          if (candidate == null || candidate.isEmpty) continue;
          if (_isPhoneLike(candidate)) continue;
          if (_isDateDigits(candidate, invoiceDate)) continue;
          if (_isLikelyYear(candidate)) continue;
          if (candidate.isEmpty || candidate.length > 6) continue;

          var score = 0;
          if (n == 0) score += 8;
          if (n == 1) score += 18;
          if (n == 2) score += 14;
          if (n == 3) score -= 4;
          if (candidate.length >= 2 && candidate.length <= 4) score += 7;
          if (RegExp(r'\b(\d{1,2}:\d{2}|am|pm)\b', caseSensitive: false).hasMatch(candidateLine)) score -= 18;
          if (RegExp(r'الكمية|الصنف|السعر|item|qty', caseSensitive: false).hasMatch(candidateLine)) score -= 12;

          if (score > bestScore) {
            bestScore = score;
            best = candidate;
          }
        }
      }

      if (best != null) {
        return best;
      }
    }
    return null;
  }

  static List<String> _extractStoreCandidates(_InvoiceTextContext ctx) {
    final lines = ctx.lines;
    if (lines.isEmpty) return const <String>[];

    final storeLabel = RegExp(
      r'^(?:اسم\s*المحل|المتجر|اسم\s*المتجر|store|merchant|seller|restaurant)\s*[:\-]?\s*(.+)$',
      caseSensitive: false,
    );
    for (final line in lines) {
      final m = storeLabel.firstMatch(line);
      if (m != null) {
        final name = (m.group(1) ?? '').trim();
        if (name.isNotEmpty) return <String>[_normalizeMerchantLabel(name)];
      }
    }

    final ignoreLine = RegExp(
      r'^(?:\d|[\*\-/,:.])+|thanks|thank\s*you|رقم\s*(?:الطلب|الفاتورة)|المجموع|الاجمالي|الإجمالي|date|time|طلب\s*خارجي|طلبية|qty|item|السعر|الكمية',
      caseSensitive: false,
    );
    final branchOrLocationHint = RegExp(
      r'فرع|tripoli|طرابلس|بن\s*غشير|قصر\s*بن\s*غشير|شارع|طريق|زاوية|هاتف|رقم\s*الهاتف|phone|location|عنوان',
      caseSensitive: false,
    );
    final brandHint = RegExp(
      r'مطعم|كافي|كوفي|سندوتش|burger|restaurant|cafe|shawarma|شاورما|بيتزا|grill|مشاوي',
      caseSensitive: false,
    );

    final ranked = <_MerchantNameCandidate>[];
    final topLimit = lines.length < 6 ? lines.length : 6;
    for (var i = 0; i < topLimit; i++) {
      final line = lines[i];
      if (line.length < 2 || line.length > 40) continue;
      if (ignoreLine.hasMatch(line)) continue;
      if (line.contains('=')) continue;
      if (RegExp(r'^[A-Za-z]\s*=?$').hasMatch(line)) continue;
      if (RegExp(r'^\d+$').hasMatch(line)) continue;
      if (RegExp(r'^(?:\d|[\*\-/,:.])+$', caseSensitive: false).hasMatch(line)) continue;

      var score = 0;
      if (RegExp(r'[\u0600-\u06FF]').hasMatch(line)) score += 8;
      if (RegExp(r'[A-Za-z]').hasMatch(line)) score += 4;
      if (!RegExp(r'\d').hasMatch(line)) score += 6;
      if (brandHint.hasMatch(line)) score += 12;
      if (branchOrLocationHint.hasMatch(line)) score -= 10;
      if (_looksLikeMerchantName(line)) score += 6;
      if (i == 0) score += 12;
      if (i == 1) score += 8;
      if (i == 2) score += 4;
      score += (topLimit - i);

      if (score > 0) {
        ranked.add(_MerchantNameCandidate(value: _normalizeMerchantLabel(line), score: score));
      }
    }

    ranked.sort((a, b) => b.score.compareTo(a.score));

    final result = <String>[];
    final seen = <String>{};

    void addCandidate(String? value) {
      if (value == null) return;
      final cleaned = _normalizeMerchantLabel(value);
      if (cleaned.isEmpty) return;
      final key = cleaned.toLowerCase();
      if (seen.contains(key)) return;
      if (_isLikelyNoisyMerchantCandidate(cleaned)) return;
      seen.add(key);
      result.add(cleaned);
    }

    if (ranked.isNotEmpty) {
      addCandidate(ranked.first.value);
    }

    addCandidate(_resolveCanonicalMerchant(ctx.rawText));

    for (final candidate in ranked.take(5)) {
      addCandidate(candidate.value);
    }

    final topLines = lines.take(4).toList();
    if (topLines.isNotEmpty) {
      final sentence = topLines
          .where((line) => !ignoreLine.hasMatch(line) && line.length >= 2 && line.length <= 40)
          .take(2)
          .join(' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (sentence.isNotEmpty && _looksLikeMerchantName(sentence) && !_isLikelyNoisyMerchantCandidate(sentence)) {
        addCandidate(sentence);
      }
    }

    for (final alias in _merchantAliases) {
      for (final hint in alias.hints) {
        if (ctx.rawText.toLowerCase().contains(hint.toLowerCase())) {
          addCandidate(alias.canonicalName);
          break;
        }
      }
    }

    return result;
  }

  static double _merchantConfidence(List<String> candidates) {
    if (candidates.isEmpty) return 0.0;
    if (candidates.length == 1) return 0.78;
    if (candidates.length == 2) return 0.62;
    if (candidates.length == 3) return 0.5;
    return 0.4;
  }

  static String? _resolveCanonicalMerchant(String text) {
    final lower = text.toLowerCase();
    _MerchantAlias? best;
    var bestScore = 0;

    for (final alias in _merchantAliases) {
      var score = 0;
      for (final hint in alias.hints) {
        if (hint.isEmpty) continue;
        if (lower.contains(hint.toLowerCase())) score += 2;
      }
      if (score > bestScore) {
        bestScore = score;
        best = alias;
      }
    }

    if (best != null && bestScore >= 2) {
      return best.canonicalName;
    }
    return null;
  }

  static bool _isLikelyNoisyMerchantCandidate(String line) {
    final hasArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(line);
    final hasLatin = RegExp(r'[A-Za-z]').hasMatch(line);
    final hasDigit = RegExp(r'\d').hasMatch(line);
    final cleaned = line.replaceAll(RegExp(r'[^A-Za-z\u0600-\u06FF\d\s]'), '').trim();

    if (cleaned.length <= 3) return true;
    if (!hasArabic && hasLatin && hasDigit) return true;
    if (!hasArabic && cleaned.length <= 6) return true;
    if (RegExp(r'^[A-Za-z]{1,3}\s*\d{1,2}$').hasMatch(cleaned)) return true;
    return false;
  }

  static bool _looksLikeMerchantName(String line) {
    final lower = line.toLowerCase();
    if (RegExp(r'\d{3,}').hasMatch(lower)) return false;
    if (RegExp(r'\b(09\d{8}|\+?2?1?\d{8,})\b').hasMatch(lower)) return false;
    if (RegExp(r'\b(202[0-9]|201[0-9])\b').hasMatch(lower)) return false;
    if (RegExp(r'\b(ط\.?|م\.?|ساعة|time|date|تاريخ|طلب|invoice|رقم)\b', caseSensitive: false).hasMatch(lower)) return false;
    return RegExp(r'[\u0600-\u06FF]|[A-Za-z]').hasMatch(line);
  }

  static String _normalizeMerchantLabel(String line) {
    var out = line.replaceAll(RegExp(r'[\|*_\u00A0]'), ' ');
    out = out.replaceAll(RegExp(r'\s+'), ' ').trim();
    out = out.replaceAll(RegExp(r'^(?:فرع\s*)+', caseSensitive: false), '').trim();
    out = out.replaceAll('سنسايو', 'شنابو');
    out = out.replaceAll('سنسايو', 'شنابو');
    out = out.replaceAll('سنسيايو', 'شنابو');
    out = out.replaceAll('سنسيايو', 'شنابو');
    if (RegExp(r'شنابو|سنابو|شناب|شنيبو', caseSensitive: false).hasMatch(out)) {
      return 'شنابو';
    }
    return out;
  }

  static String? _extractInvoiceDate(_InvoiceTextContext ctx) {
    final text = ctx.rawText;
    final patterns = <RegExp>[
      RegExp(r'(\d{4}[\-/]\d{1,2}[\-/]\d{1,2})'),
      RegExp(r'(\d{1,2}[\-/]\d{1,2}[\-/]\d{2,4})'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final value = (match.group(1) ?? '').trim();
        if (value.isNotEmpty) return value;
      }
    }
    return null;
  }

  static List<InvoiceLineItem> _extractLineItems(_InvoiceTextContext ctx) {
    final lines = ctx.lines;
    final numberPattern = RegExp(r'(?<!\d)(\d{1,5}(?:\.\d{1,2})?)(?!\d)');
    final ignore = RegExp(r'المجموع|الاجمالي|الإجمالي|اجمالي|total|invoice|order|رقم', caseSensitive: false);
    final results = <InvoiceLineItem>[];
    final seenKeys = <String>{};

    void addItem(InvoiceLineItem item) {
      final key = '${item.name}|${item.quantity}|${item.unitPrice}|${item.lineTotal}'.toLowerCase();
      if (seenKeys.contains(key)) return;
      seenKeys.add(key);
      results.add(item);
    }

    // Pass 1: same-line patterns, e.g. "مفروم قعود 3 21"
    for (final line in lines) {
      if (ignore.hasMatch(line)) continue;
      final nums = numberPattern
          .allMatches(line)
          .map((m) => double.tryParse((m.group(1) ?? '').replaceAll(',', '.')))
          .whereType<double>()
          .toList();
      if (nums.length < 2) continue;

      final name = line
          .replaceAll(RegExp(r'(?<!\d)\d{1,5}(?:[\.,]\d{1,2})?(?!\d)'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (name.isEmpty) continue;

      int? quantity;
      double? unitPrice;
      double? lineTotal;

      if (nums.length >= 3) {
        quantity = nums[0].round();
        unitPrice = nums[1];
        lineTotal = nums[2];
      } else {
        final left = nums[0];
        final right = nums[1];
        if (left <= 20 && right > left) {
          quantity = left.round();
          lineTotal = right;
          unitPrice = quantity > 0 ? (lineTotal / quantity) : null;
        }
      }

      if (quantity != null && quantity <= 0) quantity = null;
      if (unitPrice != null && unitPrice <= 0) unitPrice = null;
      if (lineTotal != null && lineTotal <= 0) lineTotal = null;

      if (lineTotal == null && quantity != null && unitPrice != null) {
        lineTotal = double.parse((quantity * unitPrice).toStringAsFixed(2));
      }
      if (unitPrice == null && quantity != null && lineTotal != null && quantity > 0) {
        unitPrice = double.parse((lineTotal / quantity).toStringAsFixed(2));
      }

      if (quantity == null && unitPrice == null && lineTotal == null) continue;
      addItem(InvoiceLineItem(
        name: name,
        quantity: quantity,
        unitPrice: unitPrice,
        lineTotal: lineTotal,
      ));
    }

    // Pass 2: table-like vertical pattern where name is on one line and numbers on next line.
    for (var i = 0; i < lines.length - 1; i++) {
      final titleLine = lines[i].trim();
      final valueLine = lines[i + 1].trim();

      if (titleLine.isEmpty || valueLine.isEmpty) continue;
      if (ignore.hasMatch(titleLine) || ignore.hasMatch(valueLine)) continue;
      if (RegExp(r'\d').hasMatch(titleLine)) continue;
      if (titleLine.length < 2 || titleLine.length > 60) continue;

      final nums = numberPattern
          .allMatches(valueLine)
          .map((m) => double.tryParse((m.group(1) ?? '').replaceAll(',', '.')))
          .whereType<double>()
          .toList();
      if (nums.length < 2) continue;

      int? quantity;
      double? unitPrice;
      double? lineTotal;

      if (nums.length >= 3) {
        quantity = nums[0].round();
        unitPrice = nums[1];
        lineTotal = nums[2];
      } else {
        final a = nums[0];
        final b = nums[1];
        if (a <= 30 && b > 0) {
          quantity = a.round();
          if (b >= a) {
            lineTotal = b;
            unitPrice = quantity > 0 ? double.parse((lineTotal / quantity).toStringAsFixed(2)) : null;
          } else {
            unitPrice = b;
            lineTotal = quantity > 0 ? double.parse((quantity * unitPrice).toStringAsFixed(2)) : null;
          }
        }
      }

      if (quantity != null && quantity <= 0) quantity = null;
      if (unitPrice != null && unitPrice <= 0) unitPrice = null;
      if (lineTotal != null && lineTotal <= 0) lineTotal = null;

      if (quantity == null && unitPrice == null && lineTotal == null) continue;
      addItem(InvoiceLineItem(
        name: titleLine,
        quantity: quantity,
        unitPrice: unitPrice,
        lineTotal: lineTotal,
      ));
    }

    return results;
  }

  static String _classifyInvoice(String text, String? storeName, List<InvoiceLineItem> items) {
    final lower = ([text, storeName ?? '', items.map((e) => e.name).join(' ')]).join(' ').toLowerCase();
    if (RegExp(r'pharmacy|صيدل|دواء|medicine').hasMatch(lower)) {
      return 'pharmacy';
    }
    if (RegExp(r'restaurant|مطعم|cafe|coffee|وجبة|سندوتش|شاورما|برغر|طلب\s*خارجي').hasMatch(lower)) {
      return 'food';
    }
    if (RegExp(r'super\s*market|grocery|بقال|سوبر').hasMatch(lower)) {
      return 'grocery';
    }
    if (RegExp(r'fuel|gas|station|وقود|بنزين').hasMatch(lower)) {
      return 'transport';
    }
    return 'general';
  }
}