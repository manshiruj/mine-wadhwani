import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mine_wadhwani/core/routing/app_router.gr.dart';
import 'package:mine_wadhwani/presentation/bloc/auth_bloc/auth_bloc.dart';
import 'package:mine_wadhwani/presentation/bloc/auth_bloc/auth_event.dart';
import 'package:mine_wadhwani/presentation/bloc/auth_bloc/auth_state.dart';
import 'package:mine_wadhwani/presentation/bloc/draft_bloc/draft_bloc.dart';
import 'package:mine_wadhwani/presentation/bloc/draft_bloc/draft_state.dart';
import 'package:mine_wadhwani/presentation/screens/notifications/notification_screen.dart';
import 'package:mine_wadhwani/presentation/screens/pending_inspections/pending_inspections_screen.dart';
import 'package:mine_wadhwani/presentation/screens/profile/profile_screen.dart';
import 'package:mine_wadhwani/presentation/screens/risk_analysis/risk_analysis_screen.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
<<<<<<< HEAD
import 'package:mine_wadhwani/presentation/screens/home/emergency_contacts_sheet.dart';
=======
import 'package:mine_wadhwani/core/di/injection_container.dart';
import 'package:mine_wadhwani/core/l10n/app_language.dart';
import 'package:mine_wadhwani/core/network/outbox.dart';
import 'package:mine_wadhwani/presentation/screens/agent/actions_screen.dart';
import 'package:mine_wadhwani/presentation/screens/agent/agents_hub_screen.dart';
import 'package:mine_wadhwani/presentation/screens/agent/chat_screen.dart';
import 'package:mine_wadhwani/presentation/screens/agent/dashboard_screen.dart';
import 'package:mine_wadhwani/presentation/screens/agent/handover_screen.dart';

/// Current connection state first, then every change (onConnectivityChanged alone only fires on changes).
Stream<List<ConnectivityResult>> _connectivity() async* {
  yield await Connectivity().checkConnectivity();
  yield* Connectivity().onConnectivityChanged;
}
>>>>>>> 60bdb660e42d0e9da8d7df9dbc11d62bf5e4f9fa

@RoutePage()
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const Color primary = Color(0xFF1F579C);
  static const Color blue = Color(0xFF2563EB);
  static const Color accentOrange = Color(0xFFE8450A);

  static List<_DashboardCard> get _cards => [
    _DashboardCard(
      icon: Icons.checklist_rounded,
      iconBgColor: primary,
      iconColor: Colors.white,
      accentColor: primary,
      title: tr('Start Inspection'),
      description:
          tr('Execute scheduled site audits and safety checklists for the current sector.'),
    ),
    _DashboardCard(
      icon: Icons.warning_amber_rounded,
      iconBgColor: Color(0xFFFFE5E5),
      iconColor: Color(0xFFD9534F),
      accentColor: Color(0xFFD9534F),
      title: tr('Report Issue'),
      description:
          tr('Immediate logging for critical risks, environmental hazards, or equipment failures.'),
    ),
    _DashboardCard(
      icon: Icons.engineering_rounded,
      iconBgColor: Color(0xFFE8F0FB),
      iconColor: blue,
      accentColor: blue,
      title: tr('actions'),
      description: tr('card_actions_desc'),
    ),
    _DashboardCard(
      icon: Icons.history_rounded,
      iconBgColor: Color(0xFFFFF0E5),
      iconColor: Color(0xFFD4A017),
      accentColor: Color(0xFFD4A017),
      title: tr('Pending Inspections'),
      description:
          tr('Resume draft inspections or review reports waiting for final submission data.'),
    ),
    _DashboardCard(
      icon: Icons.verified_rounded,
      iconBgColor: Color(0xFFE8F8F0),
      iconColor: Color(0xFF3DAA6E),
      accentColor: Color(0xFF3DAA6E),
      title: tr('handover'),
      description: tr('card_handover_desc'),
    ),
    _DashboardCard(
      icon: Icons.query_stats_rounded,
      iconBgColor: Color(0xFFF0F0F0),
      iconColor: Color(0xFF888888),
      accentColor: Color(0xFF888888),
      title: tr('Risk Analytics'),
      description:
          tr('Compute spontaneous heating risk index using sensor data — temperature, humidity, O₂, CO, and coal grade.'),
    ),
    _DashboardCard(
      icon: Icons.insights_rounded,
      iconBgColor: const Color(0xFFEDE9FE),
      iconColor: const Color(0xFF6D28D9),
      accentColor: const Color(0xFF6D28D9),
      title: tr('dashboard'),
      description: tr('dashboard_desc'),
    ),
  ];

  // ─── Navigation ───────────────────────────────────────────────────────────

  void _onCardTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.router.push(const MineSelectionRoute());
        break;
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PendingInspectionsScreen()),
        );
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ActionsScreen()),
        );
        break;
      case 4:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HandoverScreen()),
        );
        break;
      case 5:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RiskAnalysisScreen()),
        );
        break;
      case 6: // Mines Dashboard (admins only)
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
        break;
    }
  }

  // ─── Draft count ──────────────────────────────────────────────────────────

  int _draftCount(DraftState state) => switch (state) {
    DraftLoaded(drafts: final d) => d.length,
    DraftSaved(drafts: final d) => d.length,
    _ => 0,
  };

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final userName = authState is Authenticated
            ? authState.user.name
            : 'User';
        final userRole = authState is Authenticated ? authState.user.role : '';

        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.support_agent),
            label: Text(tr('assistant')),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const ChatScreen())),
          ),
          body: Column(
            children: [
              BlocBuilder<DraftBloc, DraftState>(
                builder: (context, draftState) => _buildTopBar(
                  context,
                  userName,
                  userRole,
                  _draftCount(draftState),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row (wraps on phones)
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.start,
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 4,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: primary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tr('Command Center'),
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: primary,
                                      height: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF5F7FA),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey.shade200,
                                          ),
                                        ),
                                        child: Text(
                                          tr('Operations Dashboard'),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFF3EE),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          border: Border.all(
                                            color: accentOrange.withValues(
                                              alpha: 0.3,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          _formattedDate(),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: accentOrange,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
<<<<<<< HEAD
                            onPressed: () => EmergencyContactsSheet.show(context),
                            icon: const Icon(Icons.phone_in_talk_rounded,
                                size: 15),
                            label: const Text(
                              'Emergency Contact',
=======
                            onPressed: () {},
                            icon: const Icon(
                              Icons.phone_in_talk_rounded,
                              size: 15,
                            ),
                            label: Text(
                              tr('Emergency Contact'),
>>>>>>> 60bdb660e42d0e9da8d7df9dbc11d62bf5e4f9fa
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD32F2F),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Grid with live draft badge on Pending Inspections
                      BlocBuilder<DraftBloc, DraftState>(
                        builder: (context, draftState) {
                          final count = _draftCount(draftState);
                          final w = MediaQuery.sizeOf(context).width;
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            // Mines Dashboard (last card) is for admins only.
                            itemCount: authState is Authenticated &&
                                    authState.user.isAdmin
                                ? _cards.length
                                : _cards.length - 1,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: w < 600
                                      ? 1
                                      : (w < 1000 ? 2 : 3),
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  mainAxisExtent: w < 600 ? 180 : 210,
                                ),
                            itemBuilder: (context, index) =>
                                _buildDashboardCard(
                                  _cards[index],
                                  badge: index == 3 && count > 0 ? count : null,
                                  onTap: () => _onCardTap(context, index),
                                ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Top bar ──────────────────────────────────────────────────────────────

  Widget _buildTopBar(
    BuildContext context,
    String userName,
    String userRole,
    int pendingCount,
  ) {
    // Phones: hide labels, keep icons (user name stays in the avatar menu).
    final narrow = MediaQuery.sizeOf(context).width < 900;
    return Container(
      color: primary,
      padding: EdgeInsets.symmetric(horizontal: narrow ? 12 : 20, vertical: 12),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Width cap (not Flexible) so the Spacer below pushes the icons to the far right.
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: narrow ? 78 : 220),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AIMSURE',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 19,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  tr('Mine Safety Solution'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ],
            ),
            ),
            if (!narrow) ...[
              const SizedBox(width: 16),
              Container(width: 1, height: 36, color: Colors.white24),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('Welcome,'),
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  Text(
                    userName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white,
                    ),
                  ),
                  if (userRole.isNotEmpty)
                    Text(
                      userRole,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ],
            const Spacer(),

<<<<<<< HEAD
            const _ConnectivityIndicator(),
            const SizedBox(width: 8),
            const _ToolsMenuButton(),
            const SizedBox(width: 12),
=======
            // Online badge — now reactive
            StreamBuilder<List<ConnectivityResult>>(
              stream: _connectivity(),
              initialData: const [ConnectivityResult.wifi], // optimistic until the real check returns
              builder: (context, snapshot) {
                final results = snapshot.data ?? [ConnectivityResult.none];
                final isOnline = !results.contains(ConnectivityResult.none);

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isOnline ? Icons.wifi : Icons.wifi_off,
                        color: isOnline ? Colors.greenAccent : Colors.redAccent,
                        size: 14,
                      ),
                      if (!narrow) const SizedBox(width: 5),
                      if (!narrow)
                        Text(
                          isOnline ? 'ONLINE' : 'OFFLINE',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            ValueListenableBuilder<int>(
              valueListenable: sl<Outbox>().pending,
              builder: (context, n, _) => n == 0
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Chip(
                        avatar: const Icon(
                          Icons.cloud_upload_outlined,
                          size: 16,
                        ),
                        label: Text(narrow ? '$n' : '$n ${tr('pending_sync')}'),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
            ),
            SizedBox(width: narrow ? 4 : 12),

            // AI agents status
            IconButton(
              tooltip: tr('ai_agents'),
              visualDensity: narrow ? VisualDensity.compact : null,
              icon: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 24),
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const AgentsHubScreen())),
            ),
>>>>>>> 60bdb660e42d0e9da8d7df9dbc11d62bf5e4f9fa

            // Notification bell
            const UnreadAlertsBell(),
            SizedBox(width: narrow ? 4 : 12),

            // CHECK PENDING — tappable, live count
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PendingInspectionsScreen(),
                ),
              ),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: narrow ? 8 : 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white38),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    if (narrow)
                      const Icon(
                        Icons.pending_actions,
                        color: Colors.white,
                        size: 18,
                      )
                    else
                      Text(
                        tr('CHECK PENDING'),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: pendingCount > 0
                            ? Colors.redAccent
                            : Colors.white24,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        '$pendingCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Avatar / profile / logout
            PopupMenuButton(
              offset: const Offset(0, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              color: Colors.white,
              itemBuilder: (context) => [
                PopupMenuItem(
                  enabled: false,
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: const Color(0xFFE8F0FB),
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      if (userRole.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          userRole,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      const Divider(height: 1),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_outline_rounded,
                        size: 17,
                        color: Colors.black54,
                      ),
                      SizedBox(width: 10),
                      Text(tr('My Profile'), style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(
                        Icons.logout_rounded,
                        size: 17,
                        color: Colors.redAccent,
                      ),
                      SizedBox(width: 10),
                      Text(
                        tr('Logout'),
                        style: TextStyle(fontSize: 13, color: Colors.redAccent),
                      ),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'logout') {
                  context.read<AuthBloc>().add(const AuthLogoutRequested());
                } else if (value == 'profile') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(
                        name: userName,
                        role: userRole,
                        email: 'user@email.com',
                        phone: '+91 9876543210',
                      ),
                    ),
                  );
                }
              },
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white24,
                child: Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Dashboard card ───────────────────────────────────────────────────────

  Widget _buildDashboardCard(
    _DashboardCard card, {
    VoidCallback? onTap,
    int? badge,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.07),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: card.accentColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(10),
                      bottomLeft: Radius.circular(10),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: card.iconBgColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(card.icon, color: card.iconColor, size: 26),
                    ),
                    const Spacer(),
                    Text(
                      card.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      card.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                        height: 1.5,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              if (badge != null)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withValues(alpha: 0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      badge > 99 ? '99+' : '$badge',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formattedDate() {
    final now = DateTime.now();
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }
}

class _DashboardCard {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final Color accentColor;
  final String title;
  final String description;

  const _DashboardCard({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.accentColor,
    required this.title,
    required this.description,
  });
}
<<<<<<< HEAD


class _ConnectivityIndicator extends StatefulWidget {
  const _ConnectivityIndicator();

  @override
  State<_ConnectivityIndicator> createState() => _ConnectivityIndicatorState();
}

class _ConnectivityIndicatorState extends State<_ConnectivityIndicator>
    with SingleTickerProviderStateMixin {
  bool _isOnline = true;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    Connectivity().checkConnectivity().then((result) {
      if (mounted) {
        setState(() => _isOnline = !result.contains(ConnectivityResult.none));
      }
    });

    Connectivity().onConnectivityChanged.listen((results) {
      if (mounted) {
        setState(() => _isOnline = !results.contains(ConnectivityResult.none));
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _isOnline ? 'Online' : 'Offline',
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final opacity = _isOnline ? 1.0 : 0.5 + (_pulseController.value * 0.5);
          return Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white12,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 0.8,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              _isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
              size: 16,
              color: (_isOnline ? Colors.greenAccent : Colors.redAccent)
                  .withValues(alpha: opacity),
            ),
          );
        },
      ),
    );
  }
}

class _ToolsMenuButton extends StatelessWidget {
  const _ToolsMenuButton();

  Future<void> _openShieldMine() async {
    final uri = Uri.parse('https://shield-mine.onrender.com');
    final canLaunch = await canLaunchUrl(uri);
    debugPrint('Can launch Shield Mine URL: $canLaunch');
    if (canLaunch) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Failed to launch — canLaunchUrl returned false');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'External tools',
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: Colors.white,
      icon: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white12,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 0.8,
          ),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.apps_rounded, size: 16, color: Colors.white),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'shield_mine',
          child: Row(
            children: const [
              Icon(Icons.analytics_outlined, size: 17, color: Colors.black54),
              SizedBox(width: 10),
              Expanded(
                child: Text('Shield Mine — Accident Analysis',
                    style: TextStyle(fontSize: 13)),
              ),
              Icon(Icons.open_in_new_rounded, size: 14, color: Colors.black38),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        if (value == 'shield_mine') _openShieldMine();
      },
    );
  }
}

=======
>>>>>>> 60bdb660e42d0e9da8d7df9dbc11d62bf5e4f9fa
