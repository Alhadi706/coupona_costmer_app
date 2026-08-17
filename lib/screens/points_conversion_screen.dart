import 'package:flutter/material.dart';

import '../services/company_server_service.dart';
import '../theme/design_tokens.dart';

class PointsConversionScreen extends StatefulWidget {
  const PointsConversionScreen({super.key});

  @override
  State<PointsConversionScreen> createState() => _PointsConversionScreenState();
}

class _PointsConversionScreenState extends State<PointsConversionScreen> {
  final TextEditingController _sourcePointsController = TextEditingController();
  final TextEditingController _sourcePointValueController = TextEditingController();
  final TextEditingController _destinationPointValueController = TextEditingController();
  final TextEditingController _sourceIdController = TextEditingController();
  final TextEditingController _destinationIdController = TextEditingController();

  String _sourceType = 'merchant';
  String _destinationType = 'merchant';
  bool _submitting = false;
  bool _loadingSourceValue = false;
  bool _loadingDestinationValue = false;
  String? _result;

  @override
  void dispose() {
    _sourcePointsController.dispose();
    _sourcePointValueController.dispose();
    _destinationPointValueController.dispose();
    _sourceIdController.dispose();
    _destinationIdController.dispose();
    super.dispose();
  }

  Future<void> _convert() async {
    final sourcePoints = double.tryParse(_sourcePointsController.text.trim());
    final sourcePointValue = double.tryParse(_sourcePointValueController.text.trim());
    final destinationPointValue = double.tryParse(_destinationPointValueController.text.trim());
    if (sourcePoints == null || sourcePointValue == null || destinationPointValue == null) {
      setState(() {
        _result = 'Please enter valid numeric values.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _result = null;
    });

    try {
      final data = await CompanyServerService.exchangePoints(
        sourcePoints: sourcePoints,
        sourcePointValue: sourcePointValue,
        destinationPointValue: destinationPointValue,
        sourceType: _sourceType,
        sourceId: _sourceIdController.text.trim(),
        destinationType: _destinationType,
        destinationId: _destinationIdController.text.trim(),
      );
      setState(() {
        _result = 'Destination points: ${data['destinationPoints'] ?? 0}';
      });
    } catch (e) {
      setState(() {
        _result = e.toString();
      });
    } finally {
      setState(() {
        _submitting = false;
      });
    }
  }

  Future<double?> _fetchMyRolePointValue(String roleType) async {
    if (roleType == 'merchant') {
      final data = await CompanyServerService.getMerchantProfile();
      final value = data['pointValue'];
      return value == null ? null : double.tryParse(value.toString());
    }
    if (roleType == 'brand') {
      final data = await CompanyServerService.getBrandProfile();
      final value = data['pointValue'];
      return value == null ? null : double.tryParse(value.toString());
    }
    return null;
  }

  Future<void> _loadSourcePointValue() async {
    setState(() {
      _loadingSourceValue = true;
      _result = null;
    });
    try {
      final value = await _fetchMyRolePointValue(_sourceType);
      if (!mounted) return;
      if (value == null || value <= 0) {
        setState(() {
          _result = 'No saved point value found for source role ($_sourceType).';
        });
        return;
      }
      setState(() {
        _sourcePointValueController.text = value.toString();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _result = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingSourceValue = false;
        });
      }
    }
  }

  Future<void> _loadDestinationPointValue() async {
    setState(() {
      _loadingDestinationValue = true;
      _result = null;
    });
    try {
      final value = await _fetchMyRolePointValue(_destinationType);
      if (!mounted) return;
      if (value == null || value <= 0) {
        setState(() {
          _result = 'No saved point value found for destination role ($_destinationType).';
        });
        return;
      }
      setState(() {
        _destinationPointValueController.text = value.toString();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _result = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingDestinationValue = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kIndigo,
      appBar: AppBar(title: const Text('Points Conversion')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _sourcePointsController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Source Points'),
          ),
          TextField(
            controller: _sourcePointValueController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Source Point Value'),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _loadingSourceValue ? null : _loadSourcePointValue,
              child: Text(_loadingSourceValue ? 'Loading source value...' : 'Load my source role point value'),
            ),
          ),
          TextField(
            controller: _destinationPointValueController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Destination Point Value'),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _loadingDestinationValue ? null : _loadDestinationPointValue,
              child: Text(_loadingDestinationValue ? 'Loading destination value...' : 'Load my destination role point value'),
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _sourceType,
            decoration: const InputDecoration(labelText: 'Source Type'),
            items: const [
              DropdownMenuItem(value: 'merchant', child: Text('merchant')),
              DropdownMenuItem(value: 'brand', child: Text('brand')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _sourceType = value);
            },
          ),
          TextField(
            controller: _sourceIdController,
            decoration: const InputDecoration(labelText: 'Source ID'),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _destinationType,
            decoration: const InputDecoration(labelText: 'Destination Type'),
            items: const [
              DropdownMenuItem(value: 'merchant', child: Text('merchant')),
              DropdownMenuItem(value: 'brand', child: Text('brand')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _destinationType = value);
            },
          ),
          TextField(
            controller: _destinationIdController,
            decoration: const InputDecoration(labelText: 'Destination ID'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _submitting ? null : _convert,
            child: Text(_submitting ? 'Converting...' : 'Convert points'),
          ),
          if (_result != null) ...[
            const SizedBox(height: 12),
            Text(
              _result!,
              style: kBodyTextStyle(
                size: 13,
                weight: FontWeight.w600,
                color: kGold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
