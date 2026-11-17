import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/vpn_config.dart';
import '../services/vpn_engine_service.dart';
import '../theme/dragon_theme.dart';
import '../widgets/ping_chart.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<VpnEngineService>();
    final state = engine.connectionState;
    final isConnected = state == VpnConnectionState.connected;
    final isBusy = state == VpnConnectionState.connecting ||
        state == VpnConnectionState.disconnecting;
    final active = engine.activeConfig;

    final coreColor = isConnected
        ? DragonColors.electricBlue
        : isBusy
            ? DragonColors.neonPurple
            : DragonColors.crimsonRed;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CustomPaint(
                  size: const Size(38, 38),
                  painter: DragonLogoPainter(
                    primary: DragonColors.electricBlue,
                    secondary: coreColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'VPNSOPR Turbo',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                      Text(
                        'User: ${engine.loggedInUser}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: DragonColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: engine.isUpdatingSubs
                      ? null
                      : engine.refreshAllSubscriptions,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: DragonColors.cardSurface,
                      border: Border.all(
                        color: engine.isUpdatingSubs
                            ? DragonColors.electricBlue
                            : DragonColors.neonPurple.withOpacity(0.6),
                        width: 1.8,
                      ),
                    ),
                    child: Center(
                      child: engine.isUpdatingSubs
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: DragonColors.electricBlue,
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.sync_rounded,
                                    size: 15, color: DragonColors.electricBlue),
                                Text(
                                  '${engine.subscriptions.length}',
                                  style: const TextStyle(
                                      fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Logout',
                  icon: const Icon(Icons.logout_rounded,
                      color: DragonColors.crimsonRed, size: 20),
                  onPressed: engine.logout,
                ),
              ],
            ),

            if (engine.quotaWarning != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: DragonColors.crimsonRed.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: DragonColors.crimsonRed),
                ),
                child: Text(
                  engine.quotaWarning!,
                  style: const TextStyle(
                      fontSize: 12, color: DragonColors.textPrimary),
                ),
              ),
            ],

            const SizedBox(height: 16),

            Center(
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final glow = 16 + (_pulseController.value * 18);
                  return CustomPaint(
                    painter: DragonWingAuraPainter(
                      color: coreColor,
                      pulse: _pulseController.value,
                    ),
                    child: GestureDetector(
                      onTap: engine.toggleConnection,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        width: 176,
                        height: 176,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              coreColor.withOpacity(0.28),
                              DragonColors.charcoal,
                            ],
                          ),
                          border: Border.all(color: coreColor, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: coreColor.withOpacity(0.55),
                              blurRadius: glow,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isConnected
                                  ? Icons.shield_rounded
                                  : Icons.power_settings_new_rounded,
                              size: 48,
                              color: coreColor,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              state.name.toUpperCase(),
                              style: TextStyle(
                                color: coreColor,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.4,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              engine.duration,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 14,
                                color: DragonColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),


            if (engine.isAdmin && engine.connectionState == VpnConnectionState.connected) ...[
              const SizedBox(height: 10),
              _buildAdminCountryBadge(engine),
            ],

            const SizedBox(height: 14),

            PingChartWidget(
              samples: engine.pingHistory,
              avgPing: engine.avgPingMs,
              jitterMs: engine.jitterMs,
              isLiveMonitoring: engine.isLivePingEnabled,
              onToggleMonitor: engine.toggleLivePingMonitor,
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DragonColors.cardSurface,
                      foregroundColor: DragonColors.electricBlue,
                      side: BorderSide(
                          color: DragonColors.electricBlue.withOpacity(0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.flash_auto_rounded, size: 18),
                    label: const Text('Auto Best Ping',
                        style: TextStyle(fontSize: 12)),
                    onPressed: () async {
                      final best =
                          await engine.autoSelectBestPing(connectAfter: false);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(best != null
                                ? 'Selected ${best.name} (${best.pingMs} ms)'
                                : 'No reachable config found'),
                          ),
                        );
                      }
                    },
                  ),
                ),
                if (engine.gatewayConfig.enabled) ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DragonColors.crimsonRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                    icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                    label: const Text('خرید حجم', style: TextStyle(fontSize: 12)),
                    onPressed: () => _showPurchaseSheet(context, engine),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 10),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.bolt_rounded, color: coreColor, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            active != null
                                ? '${active.name} (${active.protocolLabel})'
                                : 'No config imported — add one in Configs',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    if (active != null &&
                        (active.hasQuotaLimit || active.hasTimeLimit)) ...[
                      const SizedBox(height: 8),
                      if (active.hasQuotaLimit) ...[
                        LinearProgressIndicator(
                          value: active.quotaProgress,
                          color: DragonColors.electricBlue,
                          backgroundColor: Colors.white12,
                        ),
                        const SizedBox(height: 3),
                        Text(active.remainingQuotaLabel,
                            style: const TextStyle(
                                fontSize: 11,
                                color: DragonColors.textSecondary)),
                      ],
                      if (active.hasTimeLimit) ...[
                        const SizedBox(height: 5),
                        LinearProgressIndicator(
                          value: active.timeProgress,
                          color: DragonColors.crimsonRed,
                          backgroundColor: Colors.white12,
                        ),
                        const SizedBox(height: 3),
                        Text(active.remainingTimeLabel,
                            style: const TextStyle(
                                fontSize: 11,
                                color: DragonColors.textSecondary)),
                      ],
                    ],
                    const Divider(height: 18, color: Colors.white12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _statItem('UPLOAD', engine.uploadSpeed,
                            DragonColors.crimsonRed, Icons.arrow_upward),
                        _statItem('DOWNLOAD', engine.downloadSpeed,
                            DragonColors.electricBlue, Icons.arrow_downward),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),
            Row(
              children: [
                _modeCard(
                  engine,
                  RoutingMode.gaming,
                  'Smart Gaming',
                  'Low Ping / UDP',
                  Icons.sports_esports_rounded,
                  DragonColors.crimsonRed,
                ),
                const SizedBox(width: 8),
                _modeCard(
                  engine,
                  RoutingMode.web,
                  'Web / Stream',
                  'High Speed',
                  Icons.public_rounded,
                  DragonColors.electricBlue,
                ),
                const SizedBox(width: 8),
                _modeCard(
                  engine,
                  RoutingMode.manual,
                  'Manual',
                  'Selected',
                  Icons.tune_rounded,
                  DragonColors.neonPurple,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showPurchaseSheet(BuildContext context, VpnEngineService engine) {
    final gw = engine.gatewayConfig;
    final plans = engine.plans;
    showModalBottomSheet(
      context: context,
      backgroundColor: DragonColors.charcoal,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('خرید اشتراک از درگاه ${gw.label}',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('مرچنت / شماره کارت: ${gw.merchantOrCard}',
                style: const TextStyle(
                    fontSize: 12, color: DragonColors.textSecondary)),
            const SizedBox(height: 12),
            if (plans.isEmpty)
              const Text('ادمین هنوز پکیجی تعریف نکرده است.')
            else
              ...plans.map((pl) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${pl.title} (${pl.volumeGb} GB)'),
                    subtitle: Text('${pl.durationDays} روز اعتبار'),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DragonColors.electricBlue,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final msg = await engine.processPaymentAndActivate(pl);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text(msg)));
                        }
                      },
                      child: Text('${pl.priceTomans} تومان'),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, Color color, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: DragonColors.textSecondary)),
            Text(value,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Widget _modeCard(
    VpnEngineService engine,
    RoutingMode mode,
    String title,
    String subtitle,
    IconData icon,
    Color accent,
  ) {
    final selected = engine.routingMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => engine.setRoutingMode(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            color:
                selected ? accent.withOpacity(0.16) : DragonColors.cardSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? accent : Colors.white12,
              width: selected ? 1.8 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? accent : DragonColors.textSecondary),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: selected
                      ? DragonColors.textPrimary
                      : DragonColors.textSecondary,
                ),
              ),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 9, color: DragonColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _countryCodeToEmoji(String code) {
    final upper = code.toUpperCase();
    if (upper.length != 2) return '🌍';
    return String.fromCharCode(0x1F1E6 + upper.codeUnitAt(0) - 65) +
        String.fromCharCode(0x1F1E6 + upper.codeUnitAt(1) - 65);
  }

  Widget _buildAdminCountryBadge(VpnEngineService engine) {
    final code = engine.connectedCountryCode;
    final country = engine.connectedCountry;
    final city = engine.connectedCity;
    final ip = engine.connectedExitIp;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: DragonColors.cardSurface.withOpacity(0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DragonColors.electricBlue.withOpacity(0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (engine.isDetectingCountry)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: DragonColors.electricBlue),
            )
          else if (code != null && code.length == 2)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                'https://flagcdn.com/w80/${code.toLowerCase()}.png',
                width: 34,
                height: 24,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Text(
                  _countryCodeToEmoji(code),
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            )
          else
            const Icon(Icons.public_rounded,
                color: DragonColors.electricBlue, size: 22),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                engine.isDetectingCountry
                    ? 'در حال تشخیص کشور متصل...'
                    : (country != null
                        ? '$country${city != null && city.isNotEmpty ? ' • $city' : ''}'
                        : 'کشور نامشخص'),
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: DragonColors.textPrimary),
              ),
              if (ip != null && ip.isNotEmpty)
                Text(
                  'IP: $ip',
                  style: const TextStyle(
                      fontSize: 10, color: DragonColors.electricBlue),
                ),
            ],
          ),
        ],
      ),
    );
  }

}
