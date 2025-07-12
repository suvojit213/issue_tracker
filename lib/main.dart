import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:issue_tracker_app/initial_setup_screen.dart';
import 'package:issue_tracker_app/issue_tracker_screen.dart';
import 'package:issue_tracker_app/history_screen.dart';
import 'package:issue_tracker_app/splash_screen.dart'; // New import for splash screen
import 'package:issue_tracker_app/onboarding_tour.dart'; // Import the new onboarding tour

import 'package:issue_tracker_app/edit_profile_screen.dart';
import 'package:issue_tracker_app/notification_history_screen.dart';

import 'package:issue_tracker_app/settings_screen.dart';
import 'package:issue_tracker_app/developer_info_screen.dart';
import 'package:issue_tracker_app/theme.dart';
import 'package:issue_tracker_app/utils/issue_parser.dart'; // New import for issue parsing utility

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    const platform = MethodChannel('com.suvojeet.issue_tracker_app/notifications');
    try {
      await platform.invokeMethod('scheduleNotification');
    } on PlatformException catch (e) {
      print("Failed to schedule notifications: '${e.message}'.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Issue Tracker App',
      debugShowCheckedModeBanner: false,
      theme: AppThemes.lightTheme,
      home: const SplashScreen(), // Set SplashScreen as the initial home
      routes: {
        '/home': (context) => const MainAppScreen(),
        '/issue_tracker': (context) => const IssueTrackerScreen(),
        '/history': (context) => const HistoryScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/edit_profile': (context) => const EditProfileScreen(),
      },
    );
  }
}



class MainAppScreen extends StatefulWidget {
  const MainAppScreen({super.key});

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  int _selectedIndex = 0;

  // GlobalKeys for onboarding tour
  final GlobalKey _homeTabKey = GlobalKey();
  final GlobalKey _trackerTabKey = GlobalKey();
  final GlobalKey _historyTabKey = GlobalKey();
  final GlobalKey _settingsTabKey = GlobalKey();
  final GlobalKey _fillIssueButtonKey = GlobalKey();


  List<Widget> get _widgetOptions => <Widget>[
        DashboardScreen(fillIssueButtonKey: _fillIssueButtonKey), // Pass the key to DashboardScreen
        const IssueTrackerScreen(),
        const HistoryScreen(),
        const SettingsScreen(), // Settings screen is now part of bottom nav
      ];

  @override
  void initState() {
    super.initState();
    _checkAndShowOnboardingTour();
  }

  _checkAndShowOnboardingTour() async {
    final prefs = await SharedPreferences.getInstance();
    final bool onboardingComplete = prefs.getBool('interactive_onboarding_complete') ?? false;

    if (!onboardingComplete) {
      // Delay showing the tour until the UI is rendered
      WidgetsBinding.instance.addPostFrameCallback((_) {
        OnboardingTour onboardingTour = OnboardingTour(
          homeTabKey: _homeTabKey,
          trackerTabKey: _trackerTabKey,
          historyTabKey: _historyTabKey,
          settingsTabKey: _settingsTabKey,
          fillIssueButtonKey: _fillIssueButtonKey,
        );
        onboardingTour.show(context);
        prefs.setBool('interactive_onboarding_complete', true);
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            key: _homeTabKey, // Assign key
            icon: const Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            key: _trackerTabKey, // Assign key
            icon: const Icon(Icons.add_task_rounded),
            label: 'Tracker',
          ),
          BottomNavigationBarItem(
            key: _historyTabKey, // Assign key
            icon: const Icon(Icons.history_rounded),
            label: 'History',
          ),
          BottomNavigationBarItem(
            key: _settingsTabKey, // Assign key
            icon: const Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 10,
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  final Key? fillIssueButtonKey;
  const DashboardScreen({super.key, this.fillIssueButtonKey});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  String _crmId = "";
  String _tlName = "";
  String _advisorName = "";
  bool _isLoading = true; // Added loading state
  int _totalIssues = 0;
  Map<String, int> _issuesPerDay = {};
  Map<String, int> _issueTypeBreakdown = {};
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _slideAnimation;
  late ScrollController _scrollController; // Added ScrollController

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadAnalyticsData(); // Load analytics data
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _slideAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    _animationController.forward();

    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose(); // Dispose the scroll controller
    super.dispose();
  }

  _loadUserData() async {
    setState(() {
      _isLoading = true; // Set loading to true
    });
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _crmId = prefs.getString("crmId") ?? "";
      _tlName = prefs.getString("tlName") ?? "";
      if (_tlName == "Other") {
        _tlName = prefs.getString("otherTlName") ?? "";
      }
      _advisorName = prefs.getString("advisorName") ?? "";
      _isLoading = false; // Set loading to false after data is loaded
    });
  }

  _loadAnalyticsData() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> issueHistory = prefs.getStringList("issueHistory") ?? [];

    int total = issueHistory.length;
    Map<String, int> issuesPerDay = {};
    Map<String, int> issueTypeBreakdown = {};

    for (String entry in issueHistory) {
      Map<String, String> parsedEntry = parseHistoryEntry(entry);
      String? fillTime = parsedEntry['Fill Time'];
      String? issueType = parsedEntry['Issue Explanation'];

      if (fillTime != null) {
        DateTime date = DateTime.parse(fillTime);
        String formattedDate = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
        issuesPerDay.update(formattedDate, (value) => value + 1, ifAbsent: () => 1);
      }

      if (issueType != null) {
        issueTypeBreakdown.update(issueType, (value) => value + 1, ifAbsent: () => 1);
      }
    }

    setState(() {
      _totalIssues = total;
      _issuesPerDay = issuesPerDay;
      _issueTypeBreakdown = issueTypeBreakdown;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF1E3A8A),
                    Color(0xFF3B82F6),
                    Color(0xFFF8FAFC),
                  ],
                  stops: [0.0, 0.3, 1.0],
                ),
              ),
              child: SafeArea(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(_slideAnimation),
                    child: SingleChildScrollView(
                      controller: _scrollController, // Assign the scroll controller
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Custom App Bar
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Issue Tracker App',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.info_outline_rounded,
                                    color: Colors.white),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            const DeveloperInfoScreen()),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.notifications_active_outlined,
                                    color: Colors.white),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            const NotificationHistoryScreen()),
                                  );
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Hero Section
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withOpacity(0.95),
                                  Colors.white.withOpacity(0.85),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Welcome Back, ${_advisorName.split(" ").first}!',
                                  style: const TextStyle(
                                    color: Color(0xFF1E3A8A),
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Poppins',
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Track and manage your issues with precision',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'Poppins',
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Advisor Information Card with Enhanced Design
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF1E3A8A),
                                              Color(0xFF3B82F6)
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          Icons.person_outline,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'Advisor Profile',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1E3A8A),
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  _buildInfoRow(
                                      Icons.badge_outlined, 'CRM ID', _crmId),
                                  const SizedBox(height: 12),
                                  _buildInfoRow(
                                      Icons.supervisor_account_outlined,
                                      'Team Leader',
                                      _tlName),
                                  const SizedBox(height: 12),
                                  _buildInfoRow(Icons.person_outline,
                                      'Advisor Name', _advisorName),
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () async {
                                        final result = await Navigator.pushNamed(
                                            context, '/edit_profile');
                                        if (result == true) {
                                          _loadUserData(); // Reload data if profile was updated
                                        }
                                      },
                                      icon: const Icon(Icons.edit_rounded,
                                          color: Colors.white),
                                      label: const Text(
                                        'Edit Profile',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Poppins',
                                          color: Colors.white,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF3B82F6),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        elevation: 3,
                                        shadowColor: const Color(0xFF3B82F6)
                                            .withOpacity(0.2),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Analytics Section
                          if (_totalIssues > 0)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Your Activity',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E3A8A),
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildAnalyticsCard(
                                  title: 'Total Issues Recorded',
                                  value: '$_totalIssues',
                                  icon: Icons.task_alt_rounded,
                                  color: const Color(0xFF059669),
                                ),
                                const SizedBox(height: 16),
                                _buildAnalyticsCard(
                                  title: 'Issues Today',
                                  value: '${_issuesPerDay[DateTime.now().toString().substring(0, 10)] ?? 0}',
                                  icon: Icons.calendar_today_rounded,
                                  color: const Color(0xFF3B82F6),
                                ),
                                const SizedBox(height: 16),
                                if (_issueTypeBreakdown.isNotEmpty)
                                  _buildIssueTypeBreakdownCard(),
                                const SizedBox(height: 20),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
      floatingActionButton: _FabExtensionButton(
        scrollController: _scrollController,
        fillIssueButtonKey: widget.fillIssueButtonKey,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A8A).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF3B82F6),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isNotEmpty ? value : 'Not set',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E3A8A),
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard({required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A8A),
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIssueTypeBreakdownCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Issue Type Breakdown',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 16),
          ..._issueTypeBreakdown.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    entry.key,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[700],
                      fontFamily: 'Poppins',
                    ),
                  ),
                  Text(
                    '${entry.value}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}

class _FabExtensionButton extends StatefulWidget {
  final ScrollController scrollController;
  final Key? fillIssueButtonKey;

  const _FabExtensionButton({
    required this.scrollController,
    this.fillIssueButtonKey,
  });

  @override
  State<_FabExtensionButton> createState() => _FabExtensionButtonState();
}

class _FabExtensionButtonState extends State<_FabExtensionButton> {
  bool _isFabExtended = true;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(() {
      if (widget.scrollController.offset > 0 && _isFabExtended) {
        setState(() {
          _isFabExtended = false;
        });
      } else if (widget.scrollController.offset <= 0 && !_isFabExtended) {
        setState(() {
          _isFabExtended = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, right: 16.0),
      child: _isFabExtended
          ? FloatingActionButton.extended(
              key: widget.fillIssueButtonKey,
              onPressed: () {
                Navigator.pushNamed(context, '/issue_tracker');
              },
              label: const Text('Fill Issue Tracker'),
              icon: const Icon(Icons.add_task_rounded),
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
            )
          : FloatingActionButton(
              key: widget.fillIssueButtonKey,
              onPressed: () {
                Navigator.pushNamed(context, '/issue_tracker');
              },
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              elevation: 4,
              child: const Icon(Icons.add_task_rounded),
            ),
    );
  }
}
