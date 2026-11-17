import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/vpn_config.dart';

enum VpnConnectionState { disconnected, connecting, connected, disconnecting }

class VpnEngineService extends ChangeNotifier {
  static const String adminUsername = 'admin';
  static const String adminPassword = 'Sopr@2026!Dragon';

  static const _prefsConfigsKey = 'vpn_sopr_configs';
  static const _prefsSubsKey = 'vpn_sopr_subs';
  static const _prefsPanelsKey = 'vpn_sopr_panels';
  static const _prefsPlansKey = 'vpn_sopr_plans';
  static const _prefsOrdersKey = 'vpn_sopr_orders';
  static const _prefsTicketsKey = 'vpn_sopr_tickets';
  static const _prefsOutboundsKey = 'vpn_sopr_outbounds';
  static const _prefsGatewayKey = 'vpn_sopr_gateway';
  static const _prefsSelectedIdKey = 'vpn_sopr_selected_id';
  static const _prefsModeKey = 'vpn_sopr_routing_mode';
  static const _prefsDnsKey = 'vpn_sopr_custom_dns';
  static const _prefsSecondaryDnsKey = 'vpn_sopr_secondary_dns';
  static const _prefsBypassLanKey = 'vpn_sopr_bypass_lan';
  static const _prefsUserKey = 'vpn_sopr_auth_user';
  static const _prefsBackendUrlKey = 'vpn_sopr_backend_url';
  static const _prefsWebTunnelUrlKey = 'vpn_sopr_web_tunnel_url';

  Process? _xrayProcess;
  String _backendUrl = 'https://morningg.ir/api.php';
  String _webTunnelUrl = '';

  bool _isAuthenticated = false;
  bool _isAdmin = false;
  String _loggedInUser = 'Guest';

  VpnConnectionState _connectionState = VpnConnectionState.disconnected;
  RoutingMode _routingMode = RoutingMode.gaming;
  List<VpnConfig> _configs = [];
  List<SubscriptionItem> _subscriptions = [];
  List<PanelProfile> _panels = [];
  List<PaymentOrder> _orders = [];
  List<OutboundPool> _outbounds = [];
  List<VpnConfig> _freeConfigs = [];
  List<SupportTicket> _tickets = [];
  bool _isDnsChangerActive = false;
  List<VpnPlan> _plans = [
    VpnPlan(id: 'p10', title: 'پکیج گیمینگ ۱۰ گیگ', volumeGb: 10, durationDays: 30, priceTomans: 40000),
    VpnPlan(id: 'p30', title: 'پکیج توربو ۳۰ گیگ', volumeGb: 30, durationDays: 30, priceTomans: 120000),
    VpnPlan(id: 'p100', title: 'پکیج اژدها ۱۰۰ گیگ', volumeGb: 100, durationDays: 30, priceTomans: 400000),
  ];
  PaymentGatewayConfig _gatewayConfig = PaymentGatewayConfig();

  String? _selectedConfigId;
  String _customDns = '1.1.1.1';
  String _secondaryDns = '1.0.0.1';
  bool _bypassLan = true;
  bool _proxyOnlyMode = false;

  bool _isUpdatingSubs = false;
  String _subUpdateStatus = 'Idle';
  DateTime? _lastSubSync;

  bool _isLivePingEnabled = false;
  Timer? _livePingTimer;
  final List<int> _pingHistory = [];

  String _uploadSpeed = '0 KB/s';
  String _downloadSpeed = '0 KB/s';
  String _duration = '00:00:00';
  String? _quotaWarning;
  String? _connectedCountry;
  String? _connectedCountryCode;
  String? _connectedCity;
  String? _connectedExitIp;
  bool _isDetectingCountry = false;
  final List<String> _logs = [];

  Timer? _durationTimer;
  DateTime? _connectedAt;
  bool _initialized = false;

  bool get isAuthenticated => _isAuthenticated;
  bool get isAdmin => _isAdmin;
  String get loggedInUser => _loggedInUser;
  String get backendUrl => _backendUrl;
  String get webTunnelUrl => _webTunnelUrl;

  VpnConnectionState get connectionState => _connectionState;
  RoutingMode get routingMode => _routingMode;
  List<VpnConfig> get configs => List.unmodifiable(_configs);
  List<SubscriptionItem> get subscriptions => List.unmodifiable(_subscriptions);
  List<PanelProfile> get panels => List.unmodifiable(_panels);
  List<VpnPlan> get plans => List.unmodifiable(_plans);
  List<PaymentOrder> get orders => List.unmodifiable(_orders);
  List<OutboundPool> get outbounds => List.unmodifiable(_outbounds);
  List<VpnConfig> get freeConfigs => List.unmodifiable(_freeConfigs);
  List<SupportTicket> get tickets => List.unmodifiable(_tickets);
  bool get isDnsChangerActive => _isDnsChangerActive;
  double get totalOutboundRemainingGb =>
      _outbounds.fold(0.0, (sum, o) => sum + o.remainingGb);
  PaymentGatewayConfig get gatewayConfig => _gatewayConfig;

  String? get selectedConfigId => _selectedConfigId;
  String get customDns => _customDns;
  String get secondaryDns => _secondaryDns;
  bool get bypassLan => _bypassLan;
  bool get proxyOnlyMode => _proxyOnlyMode;
  bool get isUpdatingSubs => _isUpdatingSubs;
  String get subUpdateStatus => _subUpdateStatus;
  DateTime? get lastSubSync => _lastSubSync;

  bool get isLivePingEnabled => _isLivePingEnabled;
  List<int> get pingHistory => List.unmodifiable(_pingHistory);

  int get avgPingMs {
    final valid = _pingHistory.where((p) => p > 0).toList();
    if (valid.isEmpty) return 0;
    return (valid.reduce((a, b) => a + b) / valid.length).round();
  }

  int get jitterMs {
    final valid = _pingHistory.where((p) => p > 0).toList();
    if (valid.length < 2) return 0;
    int totalDiff = 0;
    for (int i = 1; i < valid.length; i++) {
      totalDiff += (valid[i] - valid[i - 1]).abs();
    }
    return (totalDiff / (valid.length - 1)).round();
  }

  String get uploadSpeed => _uploadSpeed;
  String get downloadSpeed => _downloadSpeed;
  String get duration => _duration;
  String? get quotaWarning => _quotaWarning;
  String? get connectedCountry => _connectedCountry;
  String? get connectedCountryCode => _connectedCountryCode;
  String? get connectedCity => _connectedCity;
  String? get connectedExitIp => _connectedExitIp;
  bool get isDetectingCountry => _isDetectingCountry;
  List<String> get logs => List.unmodifiable(_logs);

  VpnConfig? get activeConfig {
    if (_configs.isEmpty) return null;
    if (_selectedConfigId != null) {
      final found = _configs.where((c) => c.id == _selectedConfigId);
      if (found.isNotEmpty) return found.first;
    }
    return _configs.first;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await _loadPreferences();
    unawaited(syncOrdersFromServer());
    unawaited(syncTicketsFromServer());
    _addLog('VPNSOPR Turbo Windows Desktop v4.0 initialized.');
    if (_subscriptions.isNotEmpty) {
      unawaited(refreshAllSubscriptions());
    }
  }

  Future<bool> login(String username, String password) async {
    final u = username.trim();
    final p = password.trim();
    if (u.isEmpty || p.isEmpty) return false;
    if (u == adminUsername && p == adminPassword) {
      _isAdmin = true;
      _isAuthenticated = true;
      _loggedInUser = 'Admin';
    } else {
      _isAdmin = false;
      _isAuthenticated = true;
      _loggedInUser = u;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsUserKey, '$_loggedInUser|$_isAdmin');
    _addLog('Authenticated: $_loggedInUser (Admin: $_isAdmin)');
    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    _isAuthenticated = false;
    _isAdmin = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsUserKey);
    notifyListeners();
  }

  void toggleLivePingMonitor() {
    _isLivePingEnabled = !_isLivePingEnabled;
    _livePingTimer?.cancel();
    if (_isLivePingEnabled) {
      _livePingTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
        final cfg = activeConfig;
        if (cfg == null) return;
        final ms = await _quickTcpPing(cfg);
        _pingHistory.add(ms ?? -1);
        if (_pingHistory.length > 30) _pingHistory.removeAt(0);
        if (ms != null && ms > 0) cfg.pingMs = ms;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  Future<int?> _quickTcpPing(VpnConfig config) async {
    try {
      final sw = Stopwatch()..start();
      final socket = await Socket.connect(
        config.serverAddress,
        config.port,
        timeout: const Duration(milliseconds: 900),
      );
      sw.stop();
      socket.destroy();
      return math.max(1, sw.elapsedMilliseconds);
    } catch (_) {
      return -1;
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final savedAuth = prefs.getString(_prefsUserKey);
    if (savedAuth != null && savedAuth.contains('|')) {
      final parts = savedAuth.split('|');
      _loggedInUser = parts[0];
      _isAdmin = parts[1] == 'true';
      _isAuthenticated = true;
    }
    final rawList = prefs.getString(_prefsConfigsKey);
    if (rawList != null && rawList.isNotEmpty) {
      _configs = VpnConfig.decodeList(rawList);
    }
    final rawSubs = prefs.getString(_prefsSubsKey);
    if (rawSubs != null && rawSubs.isNotEmpty) {
      _subscriptions = SubscriptionItem.decodeList(rawSubs);
    }
    final rawPanels = prefs.getString(_prefsPanelsKey);
    if (rawPanels != null && rawPanels.isNotEmpty) {
      _panels = PanelProfile.decodeList(rawPanels);
    }
    final rawPlans = prefs.getString(_prefsPlansKey);
    if (rawPlans != null && rawPlans.isNotEmpty) {
      _plans = VpnPlan.decodeList(rawPlans);
    }
    final rawOutbounds = prefs.getString(_prefsOutboundsKey);
    if (rawOutbounds != null && rawOutbounds.isNotEmpty) {
      _outbounds = OutboundPool.decodeList(rawOutbounds);
    }
    final rawTickets = prefs.getString(_prefsTicketsKey);
    if (rawTickets != null && rawTickets.isNotEmpty) {
      _tickets = SupportTicket.decodeList(rawTickets);
    }
    final rawOrders = prefs.getString(_prefsOrdersKey);
    if (rawOrders != null && rawOrders.isNotEmpty) {
      _orders = PaymentOrder.decodeList(rawOrders);
    }
    final rawGw = prefs.getString(_prefsGatewayKey);
    if (rawGw != null && rawGw.isNotEmpty) {
      _gatewayConfig = PaymentGatewayConfig.fromJson(
          jsonDecode(rawGw) as Map<String, dynamic>);
    }
    _selectedConfigId = prefs.getString(_prefsSelectedIdKey);
    final savedMode = prefs.getString(_prefsModeKey);
    if (savedMode != null) {
      _routingMode = RoutingMode.values.firstWhere(
        (m) => m.name == savedMode,
        orElse: () => RoutingMode.gaming,
      );
    }
    _customDns = prefs.getString(_prefsDnsKey) ?? '1.1.1.1';
    _secondaryDns = prefs.getString(_prefsSecondaryDnsKey) ?? '1.0.0.1';
    _bypassLan = prefs.getBool(_prefsBypassLanKey) ?? true;
    _backendUrl = prefs.getString(_prefsBackendUrlKey) ?? _backendUrl;
    _webTunnelUrl = prefs.getString(_prefsWebTunnelUrlKey) ?? '';
    notifyListeners();
  }

  Future<void> _saveConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsConfigsKey, VpnConfig.encodeList(_configs));
    if (_selectedConfigId != null) {
      await prefs.setString(_prefsSelectedIdKey, _selectedConfigId!);
    }
  }

  Future<void> _saveSubs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsSubsKey, SubscriptionItem.encodeList(_subscriptions));
  }

  Future<void> _savePanels() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsPanelsKey, PanelProfile.encodeList(_panels));
  }

  Future<void> _savePlans() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsPlansKey, VpnPlan.encodeList(_plans));
  }

  Future<void> _saveOutbounds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsOutboundsKey, OutboundPool.encodeList(_outbounds));
  }

  Future<void> _saveOrders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsOrdersKey, PaymentOrder.encodeList(_orders));
  }

  Future<bool> addOutboundPool({
    required String name,
    required String rawInput,
    required double totalGb,
  }) async {
    final parsed = _parseShareLinkToXray(rawInput.trim());
    if (parsed == null || totalGb <= 0) return false;
    _outbounds.add(OutboundPool(
      id: 'ob_${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim().isEmpty ? parsed.$1 : name.trim(),
      protocol: VpnProtocol.v2ray,
      rawConfig: parsed.$4,
      serverAddress: parsed.$2,
      port: parsed.$3,
      totalGb: totalGb,
      reservedGb: 0,
    ));
    await _saveOutbounds();
    await pushStoreToServer();
    notifyListeners();
    return true;
  }

  Future<void> deleteOutboundPool(String id) async {
    _outbounds.removeWhere((o) => o.id == id);
    await _saveOutbounds();
    await pushStoreToServer();
    notifyListeners();
  }

  bool canFulfillVolume(double requestedGb) {
    if (_outbounds.isEmpty) return true;
    return _outbounds.any((o) => o.canReserve(requestedGb));
  }

  Future<void> addPlan(VpnPlan plan) async {
    _plans.add(plan);
    await _savePlans();
    await pushStoreToServer();
    notifyListeners();
  }

  Future<void> deletePlan(String id) async {
    _plans.removeWhere((p) => p.id == id);
    await _savePlans();
    await pushStoreToServer();
    notifyListeners();
  }

  Future<bool> addFreeConfig({required String name, required String rawLink}) async {
    final link = rawLink.trim();
    if (link.isEmpty) return false;
    final parsed = _parseShareLinkToXray(link);
    final cfg = VpnConfig(
      id: 'free_${DateTime.now().microsecondsSinceEpoch}',
      name: '[رایگان] ${name.trim().isEmpty ? (parsed?.$1 ?? 'Free Server') : name.trim()}',
      protocol: VpnProtocol.v2ray,
      rawConfig: parsed?.$4 ?? link,
      serverAddress: parsed?.$2 ?? '',
      port: parsed?.$3 ?? 443,
    );
    _freeConfigs.insert(0, cfg);
    _configs.removeWhere((c) => c.id == cfg.id);
    _configs.insert(0, cfg);
    await _saveConfigs();
    await pushStoreToServer();
    notifyListeners();
    return true;
  }

  Future<void> deleteFreeConfig(String id) async {
    _freeConfigs.removeWhere((c) => c.id == id);
    _configs.removeWhere((c) => c.id == id);
    await _saveConfigs();
    await pushStoreToServer();
    notifyListeners();
  }


  Future<void> toggleDnsChanger() async {
    if (_isDnsChangerActive) {
      try {
        await Process.run('powershell', [
          '-NoProfile',
          '-Command',
          'Get-NetAdapter | Where-Object {\$_.Status -eq "Up"} | ForEach-Object { Set-DnsClientServerAddress -InterfaceIndex \$_.ifIndex -ResetServerAddresses }'
        ]);
      } catch (_) {}
      _isDnsChangerActive = false;
      _addLog('Windows DNS Changer reset to DHCP.');
      notifyListeners();
      return;
    }
    try {
      await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        'Get-NetAdapter | Where-Object {\$_.Status -eq "Up"} | ForEach-Object { Set-DnsClientServerAddress -InterfaceIndex \$_.ifIndex -ServerAddresses ("$_customDns","$_secondaryDns") }'
      ]);
      _isDnsChangerActive = true;
      _addLog('Windows DNS Changer active: $_customDns / $_secondaryDns');
    } catch (e) {
      _addLog('Windows DNS Changer error: $e');
    }
    notifyListeners();
  }

  Future<void> _saveTickets() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsTicketsKey, SupportTicket.encodeList(_tickets));
  }

  Future<void> syncTicketsFromServer() async {
    if (_backendUrl.isEmpty) return;
    try {
      final url = _isAdmin
          ? '$_backendUrl?action=get_tickets'
          : '$_backendUrl?action=get_user_tickets&username=${Uri.encodeComponent(_loggedInUser)}';
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body) as List<dynamic>;
        _tickets = decoded
            .map((e) => SupportTicket.fromJson(e as Map<String, dynamic>))
            .toList();
        await _saveTickets();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> submitTicket({required String subject, required String message}) async {
    final t = SupportTicket(
      id: 'tkt_${DateTime.now().microsecondsSinceEpoch}',
      username: _loggedInUser,
      subject: subject.trim(),
      message: message.trim(),
    );
    _tickets.insert(0, t);
    await _saveTickets();
    if (_backendUrl.isNotEmpty) {
      try {
        await http.post(
          Uri.parse('$_backendUrl?action=create_ticket'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(t.toJson()),
        ).timeout(const Duration(seconds: 12));
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> replyTicket(SupportTicket ticket, String reply) async {
    ticket.adminReply = reply.trim();
    ticket.status = 'answered';
    await _saveTickets();
    if (_backendUrl.isNotEmpty) {
      try {
        await http.post(
          Uri.parse('$_backendUrl?action=reply_ticket'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'id': ticket.id, 'adminReply': ticket.adminReply}),
        ).timeout(const Duration(seconds: 10));
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> setWebTunnelUrl(String url) async {
    _webTunnelUrl = url.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsWebTunnelUrlKey, _webTunnelUrl);
    notifyListeners();
  }

  Future<void> setBackendUrl(String url) async {
    _backendUrl = url.trim().replaceAll(RegExp(r'/$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsBackendUrlKey, _backendUrl);
    _addLog('Backend Server URL set to $_backendUrl');
    notifyListeners();
  }

  Future<void> pushStoreToServer() async {
    if (_backendUrl.isEmpty || !_isAdmin) return;
    try {
      await http.post(
        Uri.parse('$_backendUrl?action=save_store'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'plans': _plans.map((p) => p.toJson()).toList(),
          'gateway': _gatewayConfig.toJson(),
          'outbounds': _outbounds.map((o) => o.toJson()).toList(),
          'free_configs': _freeConfigs.map((c) => c.toJson()).toList(),
        }),
      ).timeout(const Duration(seconds: 12));
      _addLog('Synced plans & card settings to server.');
    } catch (e) {
      _addLog('Push store warning: $e');
    }
  }

  Future<void> syncStoreFromServer() async {
    if (_backendUrl.isEmpty) return;
    try {
      final res = await http
          .get(Uri.parse('$_backendUrl?action=get_store'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          if (decoded['plans'] is List) {
            _plans = (decoded['plans'] as List)
                .map((e) => VpnPlan.fromJson(e as Map<String, dynamic>))
                .toList();
            await _savePlans();
          }
          if (decoded['gateway'] is Map<String, dynamic>) {
            _gatewayConfig = PaymentGatewayConfig.fromJson(
                decoded['gateway'] as Map<String, dynamic>);
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_prefsGatewayKey, jsonEncode(_gatewayConfig.toJson()));
          }
          if (decoded['free_configs'] is List) {
            _freeConfigs = (decoded['free_configs'] as List)
                .map((e) => VpnConfig.fromJson(e as Map<String, dynamic>))
                .toList();
            _configs.removeWhere((c) => c.id.startsWith('free_'));
            for (final fc in _freeConfigs.reversed) {
              _configs.insert(0, fc);
            }
            await _saveConfigs();
          }
          if (decoded['outbounds'] is List) {
            _outbounds = (decoded['outbounds'] as List)
                .map((e) => OutboundPool.fromJson(e as Map<String, dynamic>))
                .toList();
            await _saveOutbounds();
          }
          notifyListeners();
        }
      }
    } catch (e) {
      _addLog('Store sync error: $e');
    }
  }

  Future<void> syncOrdersFromServer() async {
    if (_backendUrl.isEmpty) return;
    await syncStoreFromServer();
    try {
      final url = _isAdmin
          ? '$_backendUrl?action=get_orders'
          : '$_backendUrl?action=get_user_orders&username=${Uri.encodeComponent(_loggedInUser)}';
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body) as List<dynamic>;
        _orders = decoded
            .map((e) => PaymentOrder.fromJson(e as Map<String, dynamic>))
            .toList();
        await _saveOrders();

        if (!_isAdmin) {
          for (final ord in _orders) {
            if (ord.status == OrderStatus.approved &&
                ord.activatedConfigJson != null &&
                ord.activatedConfigJson!.isNotEmpty) {
              final already = _configs.any((c) => c.id == 'srv_${ord.id}');
              if (!already) {
                final cfgMap = jsonDecode(ord.activatedConfigJson!) as Map<String, dynamic>;
                cfgMap['id'] = 'srv_${ord.id}';
                final newCfg = VpnConfig.fromJson(cfgMap);
                _configs.insert(0, newCfg);
                _selectedConfigId = newCfg.id;
                await _saveConfigs();
                _addLog('Activated approved plan from server: ${newCfg.name}');
              }
            }
          }
        }
        notifyListeners();
      }
    } catch (e) {
      _addLog('Order sync error: $e');
    }
  }

  Future<void> saveGatewayConfig(PaymentGatewayConfig gw) async {
    _gatewayConfig = gw;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsGatewayKey, jsonEncode(gw.toJson()));
    await pushStoreToServer();
    _addLog('Updated Iranian Payment Gateway: ${gw.label}');
    notifyListeners();
  }

  Future<void> submitReceiptOrder({
    required VpnPlan plan,
    String? receiptImagePath,
    String trackingCode = '',
  }) async {
    String? b64;
    if (receiptImagePath != null && receiptImagePath.isNotEmpty) {
      try {
        final bytes = await File(receiptImagePath).readAsBytes();
        b64 = base64Encode(bytes);
      } catch (_) {}
    }
    final order = PaymentOrder(
      id: 'ord_${DateTime.now().microsecondsSinceEpoch}',
      username: _loggedInUser,
      planTitle: plan.title,
      volumeGb: plan.volumeGb,
      durationDays: plan.durationDays,
      priceTomans: plan.priceTomans,
      outboundIds: plan.outboundIds,
      receiptImagePath: receiptImagePath,
      receiptBase64: b64,
      trackingCode: trackingCode.trim(),
      status: OrderStatus.pending,
    );
    _orders.insert(0, order);
    await _saveOrders();

    if (_backendUrl.isNotEmpty) {
      try {
        await http.post(
          Uri.parse('$_backendUrl?action=create_order'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(order.toJson()),
        ).timeout(const Duration(seconds: 15));
        _addLog('Receipt uploaded to server $_backendUrl');
      } catch (e) {
        _addLog('Server upload warning: $e');
      }
    }
    notifyListeners();
  }

  Future<String?> _provisionUserOnPanel({
    required String username,
    required double volumeGb,
    required int durationDays,
  }) async {
    if (_panels.isEmpty) return null;
    final panel = _panels.first;
    final base = panel.baseUrl
        .replaceAll(RegExp(r'/dashboard/?$'), '')
        .replaceAll(RegExp(r'/$'), '');
    try {
      final tokenRes = await http.post(
        Uri.parse('$base/api/admin/token'),
        body: {'username': panel.username, 'password': panel.password},
      ).timeout(const Duration(seconds: 12));
      if (tokenRes.statusCode != 200) {
        _addLog('Panel token error: HTTP ${tokenRes.statusCode}');
        return null;
      }
      final tokenJson = jsonDecode(tokenRes.body) as Map<String, dynamic>;
      final token = tokenJson['access_token'] as String?;
      if (token == null || token.isEmpty) return null;

      final cleanUser = '${username.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '')}_${DateTime.now().millisecondsSinceEpoch % 100000}';
      final dataLimitBytes = (volumeGb * 1024 * 1024 * 1024).round();
      final expireUnix = (DateTime.now().millisecondsSinceEpoch ~/ 1000) +
          (durationDays * 86400);

      final userRes = await http.post(
        Uri.parse('$base/api/user'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'username': cleanUser,
          'proxies': {'vless': {}},
          'data_limit': dataLimitBytes,
          'expire': expireUnix,
        }),
      ).timeout(const Duration(seconds: 12));

      if (userRes.statusCode == 200 || userRes.statusCode == 201) {
        final userJson = jsonDecode(userRes.body) as Map<String, dynamic>;
        var subUrl = userJson['subscription_url'] as String?;
        if (subUrl != null && subUrl.isNotEmpty) {
          if (subUrl.startsWith('/')) subUrl = '$base$subUrl';
          _addLog('Created user "$cleanUser" in ${panel.typeLabel}!');
          return subUrl;
        }
      } else {
        _addLog('Panel create user HTTP ${userRes.statusCode}: ${userRes.body}');
      }
    } catch (e) {
      _addLog('Panel provision error: $e');
    }
    return null;
  }

  Future<String> approveOrder(PaymentOrder order) async {
    order.status = OrderStatus.approved;
    await _saveOrders();

    if (_outbounds.isNotEmpty) {
      final targets = order.outboundIds.isNotEmpty
          ? _outbounds.where((o) => order.outboundIds.contains(o.id) && o.canReserve(order.volumeGb)).toList()
          : _outbounds.where((o) => o.canReserve(order.volumeGb)).take(1).toList();

      if (targets.isEmpty) {
        order.status = OrderStatus.rejected;
        await _saveOrders();
        notifyListeners();
        return 'ظرفیت حجم اوتباند پر شده است! دیگر امکان ساخت کانفیگ نیست.';
      }

      final quotaBytes = (order.volumeGb * 1024 * 1024 * 1024).round();
      final timeMinutes = order.durationDays * 24 * 60;
      for (final ob in targets) {
        ob.reservedGb += order.volumeGb;
        final obCfg = VpnConfig(
          id: 'obcfg_${DateTime.now().microsecondsSinceEpoch}_${ob.id}',
          name: '${order.planTitle} - ${ob.name} (${order.volumeGb.toStringAsFixed(0)}GB)',
          protocol: ob.protocol,
          rawConfig: ob.rawConfig,
          serverAddress: ob.serverAddress,
          port: ob.port,
          quotaBytes: quotaBytes,
          usedBytes: 0,
          timeLimitMinutes: timeMinutes,
          usedSeconds: 0,
        );
        _configs.insert(0, obCfg);
        _selectedConfigId = obCfg.id;
      }
      await _saveOutbounds();
      await _saveConfigs();
      if (_backendUrl.isNotEmpty) {
        try {
          await http.post(
            Uri.parse('$_backendUrl?action=approve_order'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'id': order.id, 'activatedConfigJson': jsonEncode(_configs.first.toJson())}),
          ).timeout(const Duration(seconds: 10));
        } catch (_) {}
      }
      notifyListeners();
      return 'تعداد ${targets.length} کانفیگ اوتباند با حجم ${order.volumeGb.toStringAsFixed(0)} گیگ فعال شد!';
    }

    final subUrl = await _provisionUserOnPanel(
      username: order.username,
      volumeGb: order.volumeGb,
      durationDays: order.durationDays,
    );

    if (subUrl != null) {
      try {
        final count = await addAndFetchSubscription(subUrl, name: order.planTitle);
        notifyListeners();
        return 'کاربر در پنل ساخته شد و $count کانفیگ فعال گردید!';
      } catch (e) {
        _addLog('Sub fetch after provision failed: $e');
      }
    }

    final quotaBytes = (order.volumeGb * 1024 * 1024 * 1024).round();
    final timeMinutes = order.durationDays * 24 * 60;
    if (activeConfig != null) {
      final baseCfg = activeConfig!;
      final activated = VpnConfig(
        id: 'paid_${DateTime.now().microsecondsSinceEpoch}',
        name: '${order.planTitle} (${order.volumeGb.toStringAsFixed(0)}GB)',
        protocol: baseCfg.protocol,
        rawConfig: baseCfg.rawConfig,
        serverAddress: baseCfg.serverAddress,
        port: baseCfg.port,
        isUdpPreferred: baseCfg.isUdpPreferred,
        pingMs: baseCfg.pingMs,
        quotaBytes: quotaBytes,
        usedBytes: 0,
        timeLimitMinutes: timeMinutes,
        usedSeconds: 0,
      );
      _configs.insert(0, activated);
      _selectedConfigId = activated.id;
      await _saveConfigs();
      notifyListeners();
      return 'سفارش تایید و کانفیگ ${order.volumeGb.toStringAsFixed(0)} گیگ فعال شد!';
    }
    notifyListeners();
    return 'سفارش تایید شد، اما پنل متصل نیست یا کانفیگ پایه وجود ندارد.';
  }

  Future<void> rejectOrder(PaymentOrder order) async {
    order.status = OrderStatus.rejected;
    await _saveOrders();
    if (_backendUrl.isNotEmpty) {
      try {
        await http.post(Uri.parse('$_backendUrl?action=reject_order&id=${order.id}')).timeout(const Duration(seconds: 10));
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<String> processPaymentAndActivate(VpnPlan plan) async {
    await submitReceiptOrder(plan: plan, trackingCode: 'INSTANT');
    return approveOrder(_orders.first);
  }

  Future<void> addPanel(PanelProfile panel) async {
    _panels.add(panel);
    await _savePanels();
    notifyListeners();
  }

  Future<void> deletePanel(String id) async {
    _panels.removeWhere((p) => p.id == id);
    await _savePanels();
    notifyListeners();
  }

  Future<String> syncPanel(PanelProfile panel) async {
    final base = panel.baseUrl
        .replaceAll(RegExp(r'/dashboard/?$'), '')
        .replaceAll(RegExp(r'/$'), '');
    try {
      final isMarzban = panel.type == PanelType.marzban || panel.type == PanelType.pasargad;
      final res = await http.post(
        Uri.parse(isMarzban ? '$base/api/admin/token' : '$base/login'),
        body: {'username': panel.username, 'password': panel.password},
      ).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        panel.lastSynced = DateTime.now();
        await _savePanels();
        notifyListeners();
        return 'Connected to ${panel.typeLabel}!';
      }
      return '${panel.typeLabel} HTTP ${res.statusCode}';
    } catch (e) {
      return 'Panel error: $e';
    }
  }

  Future<String> testProtocolConfig(VpnConfig cfg) async {
    final ping = await testPing(cfg);
    if (ping == null || ping < 0) return 'Unreachable';
    _selectedConfigId = cfg.id;
    await connect();
    return 'Connected (${ping}ms)';
  }

  void setProxyOnlyMode(bool val) {
    _proxyOnlyMode = val;
    notifyListeners();
  }

  Future<void> setRoutingMode(RoutingMode mode) async {
    _routingMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsModeKey, mode.name);
    notifyListeners();
  }

  Future<void> updateSettings({
    required String dns,
    String? secondaryDns,
    required bool bypassLan,
  }) async {
    _customDns = dns.trim().isEmpty ? '1.1.1.1' : dns.trim();
    _secondaryDns = (secondaryDns ?? _secondaryDns).trim();
    _bypassLan = bypassLan;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsDnsKey, _customDns);
    await prefs.setString(_prefsSecondaryDnsKey, _secondaryDns);
    await prefs.setBool(_prefsBypassLanKey, _bypassLan);
    notifyListeners();
  }

  void selectConfig(String id) {
    _selectedConfigId = id;
    _quotaWarning = null;
    _saveConfigs();
    notifyListeners();
  }

  Future<void> deleteConfig(String id) async {
    _configs.removeWhere((c) => c.id == id);
    if (_selectedConfigId == id) {
      _selectedConfigId = _configs.isNotEmpty ? _configs.first.id : null;
    }
    await _saveConfigs();
    notifyListeners();
  }

  Future<void> updateConfig(VpnConfig updated) async {
    final idx = _configs.indexWhere((c) => c.id == updated.id);
    if (idx != -1) {
      _configs[idx] = updated;
      await _saveConfigs();
      notifyListeners();
    }
  }

  Future<int> splitConfigIntoParts(
    VpnConfig source, {
    required double totalGb,
    required int parts,
    int? timeLimitMinutesPerPart,
  }) async {
    if (parts <= 0 || totalGb <= 0) return 0;
    final perPartBytes = ((totalGb / parts) * 1024 * 1024 * 1024).round();
    final perPartGb = (totalGb / parts).toStringAsFixed(1);
    for (int i = 1; i <= parts; i++) {
      _configs.add(VpnConfig(
        id: '${DateTime.now().microsecondsSinceEpoch}_part_$i',
        name: '${source.name} #$i (${perPartGb}GB)',
        protocol: source.protocol,
        rawConfig: source.rawConfig,
        serverAddress: source.serverAddress,
        port: source.port,
        quotaBytes: perPartBytes,
        timeLimitMinutes: timeLimitMinutesPerPart,
      ));
    }
    await _saveConfigs();
    notifyListeners();
    return parts;
  }

  Future<VpnConfig?> autoSelectBestPing({bool connectAfter = false}) async {
    if (_configs.isEmpty) return null;
    await testAllPings();
    final reachable = _configs
        .where((c) => (c.pingMs ?? -1) > 0 && !c.isQuotaExceeded && c.serverAddress != '127.0.0.1')
        .toList();
    if (reachable.isEmpty) return null;
    reachable.sort((a, b) => a.pingMs!.compareTo(b.pingMs!));
    _selectedConfigId = reachable.first.id;
    await _saveConfigs();
    notifyListeners();
    if (connectAfter) await connect();
    return reachable.first;
  }

  Future<void> toggleConnection() async {
    if (_connectionState == VpnConnectionState.connected ||
        _connectionState == VpnConnectionState.connecting) {
      await disconnect();
    } else {
      await connect();
    }
  }

  Future<void> _setWindowsProxy(bool enable) async {
    if (!Platform.isWindows || _proxyOnlyMode) return;
    try {
      await Process.run('reg', [
        'add',
        r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
        '/v',
        'ProxyEnable',
        '/t',
        'REG_DWORD',
        '/d',
        enable ? '1' : '0',
        '/f',
      ]);
      if (enable) {
        await Process.run('reg', [
          'add',
          r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
          '/v',
          'ProxyServer',
          '/t',
          'REG_SZ',
          '/d',
          '127.0.0.1:10809',
          '/f',
        ]);
      }
    } catch (e) {
      _addLog('Windows proxy error: $e');
    }
  }

  Future<void> connect() async {
    final target = activeConfig;
    if (target == null) {
      _addLog('ERROR: No config selected.');
      return;
    }
    _connectionState = VpnConnectionState.connecting;
    notifyListeners();

    try {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      final xrayPath = '$exeDir${Platform.pathSeparator}xray.exe';
      final cfgFile = File('${Directory.systemTemp.path}${Platform.pathSeparator}vpnsopr_xray.json');
      await cfgFile.writeAsString(target.rawConfig);

      _xrayProcess?.kill();
      _xrayProcess = await Process.start(xrayPath, ['run', '-c', cfgFile.path]);
      _xrayProcess!.stdout.transform(utf8.decoder).listen((d) => _addLog(d.trim()));
      _xrayProcess!.stderr.transform(utf8.decoder).listen((d) => _addLog(d.trim()));

      await _setWindowsProxy(true);
      _connectionState = VpnConnectionState.connected;
    unawaited(_detectConnectedCountry());
      _connectedAt = DateTime.now();
      _durationTimer?.cancel();
    _connectedCountry = null;
    _connectedCountryCode = null;
    _connectedCity = null;
    _connectedExitIp = null;
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_connectedAt != null) {
          _duration = _formatDuration(DateTime.now().difference(_connectedAt!));
          notifyListeners();
        }
      });
      _addLog('Connected via xray.exe (SOCKS 10808 / HTTP 10809).');
    } catch (e) {
      _addLog('Desktop connect error: $e');
      _connectionState = VpnConnectionState.disconnected;
    }
    notifyListeners();
  }

  Future<void> _detectConnectedCountry() async {
    if (!_isAdmin) return;
    _isDetectingCountry = true;
    notifyListeners();
    try {
      http.Response? res;
      try {
        res = await http
            .get(Uri.parse('http://ip-api.com/json/?fields=status,country,countryCode,city,query'))
            .timeout(const Duration(seconds: 7));
      } catch (_) {}

      Map<String, dynamic>? data;
      if (res != null && res.statusCode == 200) {
        final j = jsonDecode(res.body) as Map<String, dynamic>;
        if (j['status'] == 'success') data = j;
      }
      if (data == null && activeConfig != null && activeConfig!.serverAddress.isNotEmpty) {
        final fb = await http
            .get(Uri.parse('http://ip-api.com/json/${activeConfig!.serverAddress}?fields=status,country,countryCode,city,query'))
            .timeout(const Duration(seconds: 7));
        if (fb.statusCode == 200) {
          final j = jsonDecode(fb.body) as Map<String, dynamic>;
          if (j['status'] == 'success') data = j;
        }
      }
      if (data != null) {
        _connectedCountry = data['country'] as String?;
        _connectedCountryCode = data['countryCode'] as String?;
        _connectedCity = data['city'] as String?;
        _connectedExitIp = data['query'] as String?;
        _addLog('Admin Country Check: $_connectedCountry ($_connectedCountryCode) - $_connectedExitIp');
      }
    } catch (e) {
      _addLog('Country detect note: $e');
    } finally {
      _isDetectingCountry = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    _xrayProcess?.kill();
    _xrayProcess = null;
    await _setWindowsProxy(false);
    _durationTimer?.cancel();
    _connectedCountry = null;
    _connectedCountryCode = null;
    _connectedCity = null;
    _connectedExitIp = null;
    _connectionState = VpnConnectionState.disconnected;
    _duration = '00:00:00';
    _addLog('Disconnected.');
    notifyListeners();
  }

  (String, String, int, String)? _parseShareLinkToXray(String input) {
    if (input.startsWith('{') && input.contains('outbounds')) {
      return ('Xray JSON', 'json.xray', 443, input);
    }
    try {
      final uri = Uri.parse(input);
      final host = uri.host;
      final port = uri.port == 0 ? 443 : uri.port;
      final remark = Uri.decodeComponent(uri.fragment.isEmpty ? host : uri.fragment);

      Map<String, dynamic> outbound;
      if (uri.scheme == 'vless') {
        outbound = {
          'tag': 'proxy',
          'protocol': 'vless',
          'settings': {
            'vnext': [
              {
                'address': host,
                'port': port,
                'users': [
                  {
                    'id': uri.userInfo,
                    'encryption': uri.queryParameters['encryption'] ?? 'none',
                    'flow': uri.queryParameters['flow'] ?? '',
                  }
                ]
              }
            ]
          },
          'streamSettings': {
            'network': uri.queryParameters['type'] ?? 'tcp',
            'security': uri.queryParameters['security'] ?? 'none',
          }
        };
      } else {
        return null;
      }

      final full = jsonEncode({
        'inbounds': [
          {
            'port': 10808,
            'listen': '127.0.0.1',
            'protocol': 'socks',
            'settings': {'udp': true},
            'sniffing': {'enabled': true, 'destOverride': ['http', 'tls', 'quic']}
          },
          {
            'port': 10809,
            'listen': '127.0.0.1',
            'protocol': 'http'
          }
        ],
        'outbounds': [
          outbound,
          {'protocol': 'freedom', 'tag': 'direct'}
        ]
      });
      return (remark, host, port, full);
    } catch (_) {
      return null;
    }
  }

  Future<int> importRawInput(String input,
      {String? customName, String? subscriptionId}) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return 0;
    if ((trimmed.startsWith('http://') || trimmed.startsWith('https://')) &&
        !trimmed.contains('\n')) {
      return addAndFetchSubscription(trimmed, name: customName);
    }

    int added = 0;
    for (final line in trimmed.split(RegExp(r'\r?\n'))) {
      final l = line.trim();
      if (l.isEmpty) continue;
      final parsed = _parseShareLinkToXray(l);
      if (parsed != null) {
        _configs.add(VpnConfig(
          id: '${DateTime.now().microsecondsSinceEpoch}_$added',
          name: customName ?? parsed.$1,
          protocol: VpnProtocol.v2ray,
          rawConfig: parsed.$4,
          serverAddress: parsed.$2,
          port: parsed.$3,
          subscriptionId: subscriptionId,
        ));
        added++;
      }
    }
    if (added > 0) {
      _selectedConfigId ??= _configs.first.id;
      await _saveConfigs();
      notifyListeners();
    }
    return added;
  }

  Future<int> addAndFetchSubscription(String url, {String? name}) async {
    final cleanUrl = url.trim();
    var existing = _subscriptions.where((s) => s.url == cleanUrl).toList();
    late SubscriptionItem sub;
    if (existing.isEmpty) {
      sub = SubscriptionItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: (name != null && name.trim().isNotEmpty)
            ? name.trim()
            : Uri.tryParse(cleanUrl)?.host ?? 'Subscription',
        url: cleanUrl,
      );
      _subscriptions.add(sub);
    } else {
      sub = existing.first;
    }
    await _saveSubs();
    return refreshSubscription(sub);
  }

  Future<int> refreshSubscription(SubscriptionItem sub) async {
    _isUpdatingSubs = true;
    notifyListeners();
    try {
      final res = await http.get(Uri.parse(sub.url)).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      var body = res.body.trim();
      if (!body.contains('://')) {
        try {
          body = utf8.decode(base64Decode(base64.normalize(body)));
        } catch (_) {}
      }
      _configs.removeWhere((c) => c.subscriptionId == sub.id);
      final count = await importRawInput(body, subscriptionId: sub.id);
      sub.lastUpdated = DateTime.now();
      sub.configCount = count;
      await _saveSubs();
      await _saveConfigs();
      return count;
    } finally {
      _isUpdatingSubs = false;
      notifyListeners();
    }
  }

  Future<void> refreshAllSubscriptions() async {
    for (final s in List<SubscriptionItem>.from(_subscriptions)) {
      try {
        await refreshSubscription(s);
      } catch (_) {}
    }
  }

  Future<void> deleteSubscription(String id) async {
    _subscriptions.removeWhere((s) => s.id == id);
    _configs.removeWhere((c) => c.subscriptionId == id);
    await _saveSubs();
    await _saveConfigs();
    notifyListeners();
  }

  Future<int?> testPing(VpnConfig config) async {
    config.pingMs = await _quickTcpPing(config);
    await _saveConfigs();
    notifyListeners();
    return config.pingMs;
  }

  Future<void> testAllPings() async {
    for (final c in _configs) {
      await testPing(c);
    }
  }

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  void _addLog(String msg) {
    if (msg.isEmpty) return;
    final ts = DateTime.now().toIso8601String().substring(11, 19);
    _logs.insert(0, '[$ts] $msg');
    if (_logs.length > 250) _logs.removeLast();
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
  }
}
