import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'auth_service.dart';
import 'incident_report_screen.dart';
import 'user_management_screen.dart';
import 'login_screen.dart';
import 'admin_incident_analytics_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
late List<CameraDescription> cameras;
final GlobalKey<NavigatorState> navigatorKey =
    GlobalKey<NavigatorState>();
final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> initializeNotifications() async {
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings settings =
      InitializationSettings(android: androidSettings);

  await notificationsPlugin.initialize(
    settings: settings,
    onDidReceiveNotificationResponse:
        (NotificationResponse response) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => const IncidentHistoryScreen(),
        ),
      );
    },
  );

  final androidPlugin = notificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  await androidPlugin?.requestNotificationsPermission();
}

Future<void> showSafetyNotification(String message) async {
  const AndroidNotificationDetails androidDetails =
      AndroidNotificationDetails(
    'safety_alerts',
    'Safety Alerts',
    channelDescription: 'Notifications for detected PPE safety violations',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
  );

  const NotificationDetails details =
      NotificationDetails(android: androidDetails);

  await notificationsPlugin.show(
    id:0,
    title: 'Safety Violation Detected!',
    body: message,
    notificationDetails: details,
  );
}
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeNotifications();
  cameras = await availableCameras();

  runApp(const IndustrialSafetyApp());
}

class IndustrialSafetyApp extends StatelessWidget {
  const IndustrialSafetyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Industrial Safety Monitoring',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      home:  const AuthGate(),
    );
  }
}
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: AuthService.getRole(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final role = snapshot.data?.trim().toUpperCase();
        debugPrint('SAVED ROLE: $role');
        if (role == 'ADMIN') {
          return const AdminDashboardScreen();
        }

        if (role == 'USER') {
          return const DashboardScreen();
        }

        return const LoginScreen();
      },
    );
  }
}
// ============================================================
// DASHBOARD SCREEN
// ============================================================

// ============================================================
// DASHBOARD SCREEN
// ============================================================

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    this.adminOverview = false,
  });

  final bool adminOverview;
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // final String apiUrl = 'http://10.102.157.67:8000/stats';
final String apiUrl = 'http://10.29.216.67:8000/stats';
  bool loading = true;
  String errorMessage = '';

  int totalChecks = 0;
  int safeCount = 0;
  int violationCount = 0;
int registeredUsers = 0;
  int noHelmet = 0;
  int noVest = 0;
  int noGloves = 0;
  int noShoes = 0;
  List<Map<String, dynamic>> incidentTrends = [];
List<DateTime> incidentTrendDates = [];

bool trendsLoading = true;
String trendsError = '';

  @override
  void initState() {
    super.initState();
    fetchStats();
    fetchIncidentTrends();
  }

  // ==========================================================
  // FETCH DASHBOARD STATISTICS
  // ==========================================================
Future<void> logout() async {
  await AuthService.logout();

  if (!mounted) return;

  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(
      builder: (context) => const LoginScreen(),
    ),
    (route) => false,
  );
}

Future<void> fetchStats() async {
  try {
    // Get the saved login token
    final token = await AuthService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Please log in again.');
    }

    // Request statistics with authentication
    final response = await http.get(
      Uri.parse(apiUrl),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (!mounted) return;

      setState(() {
        totalChecks = data['total_checks'] ?? 0;
        safeCount = data['safe_count'] ?? 0;
        violationCount = data['violation_count'] ?? 0;
        registeredUsers = data['registered_users'] ?? 0;
        final violations = data['violations'] ?? {};

        noHelmet = violations['no_helmet'] ?? 0;
        noVest = violations['no_vest'] ?? 0;
        noGloves = violations['no_gloves'] ?? 0;
        noShoes = violations['no_shoes'] ?? 0;

        loading = false;
        errorMessage = '';
      });
    } else {
      if (!mounted) return;

      setState(() {
        loading = false;
        errorMessage =
            'Server error: ${response.statusCode} - ${response.body}';
      });
    }
  } catch (e) {
    if (!mounted) return;

    setState(() {
      loading = false;
      errorMessage = 'Connection error: $e';
    });
  }
}
Future<void> fetchIncidentTrends() async {
  try {
    final token = await AuthService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Please log in again.');
    }

    final response = await http.get(
      // Uri.parse(
      //   'http://10.102.157.67:8000/incident-trends',
      // ),
      Uri.parse(
        'http://10.29.216.67:8000/incident-trends',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Server error: ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body);
    final List<dynamic> apiTrends = data['trends'] ?? [];

    final Map<String, int> countsByDate = {};

    for (final item in apiTrends) {
      countsByDate[item['date'].toString()] =
          (item['count'] as num).toInt();
    }

    final today = DateTime.now();
    final List<DateTime> dates = [];
    final List<Map<String, dynamic>> filledTrends = [];

    for (int i = 6; i >= 0; i--) {
      final date = DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(Duration(days: i));

      final dateKey =
          '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';

      dates.add(date);

      filledTrends.add({
        'date': dateKey,
        'count': countsByDate[dateKey] ?? 0,
      });
    }

    if (!mounted) return;

    setState(() {
      incidentTrendDates = dates;
      incidentTrends = filledTrends;
      trendsLoading = false;
      trendsError = '';
    });
  } catch (e) {
    if (!mounted) return;

    setState(() {
      trendsLoading = false;
      trendsError = e.toString();
    });
  }
}

  // ==========================================================
  // STAT CARD
  // ==========================================================
Widget buildStatCard(
  String title,
  int value,
  IconData icon,
  Color color,
) {
  return Card(
    elevation: 2,
    child: SizedBox(
    width: double.infinity,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 32,
            color: color,
          ),
          const SizedBox(height: 8),
          Text(
            // value.toString(),
            title == 'Violation Rate'
    ? '$value%'
    : value.toString(),
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
    ),
  );
}
  // ==========================================================
  // VIOLATION ROW
  // ==========================================================

  Widget buildViolationRow(
    String title,
    int count,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 8,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.red,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              count.toString(),
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

Widget buildViolationBar(
  String title,
  int count,
  int maxCount,
) {
  final double progress = maxCount > 0
      ? (count / maxCount).clamp(0.0, 1.0)
      : 0.0;

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              count.toString(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 12,
            backgroundColor: Colors.red.shade50,
            valueColor: const AlwaysStoppedAnimation<Color>(
              Colors.red,
            ),
          ),
        ),
      ],
    ),
  );
}

  // ==========================================================
  // DASHBOARD UI
  // ==========================================================
  Widget buildIncidentTrendChart() {
  if (trendsLoading) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(30),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }

  if (trendsError.isNotEmpty) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Unable to load incident trends'),
            const SizedBox(height: 8),
            Text(
              trendsError,
              textAlign: TextAlign.center,
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  trendsLoading = true;
                  trendsError = '';
                });
                fetchIncidentTrends();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  final counts = incidentTrends
      .map((item) => (item['count'] as num).toDouble())
      .toList();

  final maxCount = counts.isEmpty
      ? 0.0
      : counts.reduce((a, b) => a > b ? a : b);

  final maxY = maxCount == 0 ? 1.0 : maxCount + 1;
  final interval = maxY <= 4
      ? 1.0
      : (maxY / 4).ceilToDouble();

  return Card(
    elevation: 2,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Date-wise Incident Trend',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Safety violations over the last 7 days',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 230,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: 6,
                minY: 0,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  handleBuiltInTouches: true,
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    axisNameWidget: const Text('Incidents'),
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 38,
                      interval: interval,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 11),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    axisNameWidget: const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('Date'),
                    ),
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();

                        if (index < 0 ||
                            index >= incidentTrendDates.length) {
                          return const SizedBox.shrink();
                        }

                        final date = incidentTrendDates[index];
                        final label =
                            '${date.day.toString().padLeft(2, '0')}/'
                            '${date.month.toString().padLeft(2, '0')}';

                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            label,
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (int i = 0; i < counts.length; i++)
                        FlSpot(i.toDouble(), counts[i]),
                    ],
                    isCurved: false,
                    barWidth: 3,
                    color: Colors.red,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.red.withValues(alpha: 0.12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
  @override
  Widget build(BuildContext context) {
    final bool hasViolations = violationCount > 0;
    final double violationRate = totalChecks > 0
    ? (violationCount / totalChecks) * 100
    : 0.0;
final int maxViolationCount = [
  noHelmet,
  noVest,
  noGloves,
  noShoes,
].reduce((a, b) => a > b ? a : b);
    return Scaffold(
      appBar: AppBar(
        title:  Text(
          widget.adminOverview
      ? 'Admin Safety Overview'
      : 'Industrial Safety Monitoring',
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: loading
                ? null
                : () {
                    setState(() {
                      loading = true;
                      errorMessage = '';
                    });

                    fetchStats();
                  },
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
      icon: const Icon(Icons.logout),
      tooltip: 'Logout',
      onPressed: logout,
    ),
        ],
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 60,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 15),
                        Text(
                          errorMessage,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 15),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              loading = true;
                              errorMessage = '';
                            });

                            fetchStats();
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: fetchStats,
                  child: SingleChildScrollView(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Safety Dashboard',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        
                        // CURRENT SAFETY STATUS
                        Card(
                          elevation: 2,
                          color: hasViolations
                              ? Colors.red.shade50
                              : Colors.green.shade50,
                          child: Padding(
                            padding:
                                const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                Icon(
                                  hasViolations
                                      ? Icons
                                          .warning_rounded
                                      : Icons
                                          .check_circle,
                                  size: 55,
                                  color: hasViolations
                                      ? Colors.red
                                      : Colors.green,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  hasViolations
                                      ? 'SAFETY VIOLATIONS DETECTED'
                                      : 'ALL SAFE',
                                  textAlign:
                                      TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight:
                                        FontWeight.bold,
                                    color: hasViolations
                                        ? Colors.red
                                        : Colors.green,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  hasViolations
                                      ? '$violationCount violation checks recorded'
                                      : 'No safety violations recorded',
                                  style:
                                      const TextStyle(
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // SUMMARY CARDS

                        // SUMMARY CARDS
                        Row(
                          
                          children: [
                            Expanded(
                              child: buildStatCard(
                                'Total Checks',
                                totalChecks,
                                Icons.analytics,
                                Colors.indigo,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: buildStatCard(
                                'Safe',
                                safeCount,
                                Icons.check_circle,
                                Colors.green,
                              ),
                            ),
                          ],
                        ),

                        // if (widget.adminOverview) ...[
                        //   const SizedBox(height: 10),
                        //   Row(
                        //     children: [
                        //       Expanded(
                        //         child: buildStatCard(
                        //           'Registered Users',
                        //           registeredUsers,
                        //           Icons.people,
                        //           Colors.blue,
                        //         ),
                        //       ),
                        //       const SizedBox(width: 10),
                        //       const Expanded(
                        //         child: SizedBox.shrink(),
                        //       ),
                        //     ],
                        //   ),
                        // ],

                        const SizedBox(height: 10),

                        Row(
                          children: [
                            Expanded(
                              child: buildStatCard(
                                'Violations',
                                violationCount,
                                Icons.warning,
                                Colors.red,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: buildStatCard(
                                'No Helmet',
                                noHelmet,
                                Icons.health_and_safety,
                                Colors.orange,
                              ),
                            ),
                          ],
                        ),

if (widget.adminOverview) ...[
  const SizedBox(height: 10),
  Row(
    children: [
      Expanded(
        child: buildStatCard(
          'Registered Users',
          registeredUsers,
          Icons.people,
          Colors.blue,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: buildStatCard(
          'Violation Rate',
          violationRate.round(),
          Icons.percent,
          Colors.deepOrange,
        ),
      ),
    ],
  ),
],

                        const SizedBox(height: 20),

                        // PPE VIOLATIONS
                        Card(
                          elevation: 2,
                          child: Padding(
                            padding:
                                const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'PPE Violation Summary',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(height: 12),

                                // buildViolationRow(
                                //   'No Helmet',
                                //   noHelmet,
                                //   Icons
                                //       .health_and_safety,
                                // ),

                                // buildViolationRow(
                                //   'No Vest',
                                //   noVest,
                                //   Icons
                                //       .accessibility,
                                // ),

                                // buildViolationRow(
                                //   'No Gloves',
                                //   noGloves,
                                //   Icons.back_hand,
                                // ),

                                // buildViolationRow(
                                //   'No Shoes',
                                //   noShoes,
                                //   Icons
                                //       .directions_walk,
                                // ),
                                
buildViolationBar(
  'No Helmet',
  noHelmet,
  maxViolationCount,
),

buildViolationBar(
  'No Vest',
  noVest,
  maxViolationCount,
),

buildViolationBar(
  'No Gloves',
  noGloves,
  maxViolationCount,
),

buildViolationBar(
  'No Shoes',
  noShoes,
  maxViolationCount,
),

                              ],
                            ),
                          ),
                        ),
// INCIDENT TREND - ADMIN ONLY
if (widget.adminOverview) ...[
  const SizedBox(height: 20),
  buildIncidentTrendChart(),
  const SizedBox(height: 20),
],
                        const SizedBox(height: 20),

                        
if (!widget.adminOverview) ...[
  // START MONITORING
  ElevatedButton.icon(
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              const MonitoringScreen(),
        ),
      ).then((_) {
        fetchStats();
      });
    },
    icon: const Icon(Icons.camera_alt),
    label: const Text('Start Monitoring'),
    style: ElevatedButton.styleFrom(
      padding: const EdgeInsets.all(16),
    ),
  ),

  const SizedBox(height: 12),

  // INCIDENT HISTORY
  OutlinedButton.icon(
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              const IncidentHistoryScreen(),
        ),
      ).then((_) {
        fetchStats();
      });
    },
    icon: const Icon(Icons.history),
    label: const Text('Incident History'),
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.all(16),
    ),
  ),
],

                      ],
                    ),
                  ),
                ),
    );
  }
}


class AdminOverviewScreen extends StatelessWidget {
  const AdminOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Safety Overview'),
        centerTitle: true,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.admin_panel_settings,
                size: 70,
                color: Colors.blue,
              ),
              SizedBox(height: 20),
              Text(
                'Admin Safety Overview',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12),
              Text(
                'Use the Admin Dashboard to manage users, '
                'start safety monitoring, and view all incidents.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ============================================================
// MONITORING SCREEN
// ============================================================

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key});

  @override
  State<MonitoringScreen> createState() =>
      _MonitoringScreenState();
}

class _MonitoringScreenState
    extends State<MonitoringScreen> {
  // final String apiUrl = 'http://10.102.157.67:8000/predict';
  final String apiUrl = 'http://10.29.216.67:8000/predict';
  late CameraController controller;
  late Future<void> initializeControllerFuture;

  bool analyzing = false;
final AudioPlayer alertPlayer = AudioPlayer();
  String status = 'READY';

  String resultMessage = '';

  @override
  void initState() {
    super.initState();

    controller = CameraController(
      cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    initializeControllerFuture =
        controller.initialize();
  }

  @override
  void dispose() {
    controller.dispose();
    alertPlayer.dispose();
    super.dispose();
  }
Future<void> playWarningSound() async {
  try {
    await alertPlayer.stop();
    await alertPlayer.play(
      AssetSource('sounds/warning sound.mp3'),
    );
  } catch (e) {
    debugPrint('Unable to play warning sound: $e');
  }
}
  // ==========================================================
  // CAPTURE USING CAMERA
  // ==========================================================

  Future<void> captureAndAnalyze() async {
    try {
      setState(() {
        analyzing = true;
        status = 'ANALYZING...';
        resultMessage = '';
      });

      await initializeControllerFuture;

      final image =
          await controller.takePicture();

      final request = http.MultipartRequest(
  'POST',
  Uri.parse(apiUrl),
);

// Get the saved login token
final token = await AuthService.getToken();

if (token == null || token.isEmpty) {
  throw Exception('Please log in again.');
}

// Send the token to the backend
request.headers['Authorization'] = 'Bearer $token';

// Attach the captured image
request.files.add(
  await http.MultipartFile.fromPath(
    'file',
    image.path,
  ),
);

      final response =
          await request.send();

      final responseBody =
          await response.stream.bytesToString();

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data =
            jsonDecode(responseBody);

        final String aiStatus =
            data['status'] ?? 'UNKNOWN';

        final List violations =
            data['violations'] ?? [];

        setState(() {
          analyzing = false;

          if (aiStatus ==
              'SAFETY VIOLATION') {
            status =
                'SAFETY VIOLATION';

            if (violations.isNotEmpty) {
              resultMessage =
                  violations.map((v) {
                final className =
                    v['class'] ?? 'Unknown';

                final confidence =
                    v['confidence'] ?? 0;

                return '${className.toString().toUpperCase()} '
                    '(${(confidence * 100).toStringAsFixed(0)}%)';
              }).join('\n');
            } else {
              resultMessage =
                  'Safety violation detected';
            }

          }
           else {
            status = 'SAFE';

            resultMessage =
                'No safety violations detected';
          }
        });
              if (aiStatus == 'SAFETY VIOLATION' && mounted) {
  await playWarningSound();
    await showSafetyNotification(
    resultMessage.isNotEmpty
        ? resultMessage
        : 'PPE safety violation detected.',
  );
}
      } else {
        setState(() {
          analyzing = false;
          status = 'ERROR';

          resultMessage =
              'Server error: ${response.statusCode}';
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        analyzing = false;
        status = 'ERROR';

        resultMessage =
            'Analysis error: $e';
      });
    }
  }

  // ==========================================================
  // ANALYZE IMAGE FROM GALLERY
  // ==========================================================

  Future<void> analyzeTestImage() async {
    try {
      final picker =
          ImagePicker();

      final XFile? image =
          await picker.pickImage(
        source: ImageSource.gallery,
      );

      if (image == null) return;

      setState(() {
        analyzing = true;
        status = 'ANALYZING...';
        resultMessage = '';
      });

      final request = http.MultipartRequest(
  'POST',
  Uri.parse(apiUrl),
);

// Get the saved login token
final token = await AuthService.getToken();

if (token == null || token.isEmpty) {
  throw Exception('Please log in again.');
}

// Send the token to the backend
request.headers['Authorization'] = 'Bearer $token';

// Attach the selected gallery image
request.files.add(
  await http.MultipartFile.fromPath(
    'file',
    image.path,
  ),
);

      final response =
          await request.send();

      final responseBody =
          await response.stream.bytesToString();

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data =
            jsonDecode(responseBody);

        final String aiStatus =
            data['status'] ?? 'UNKNOWN';

        final List violations =
            data['violations'] ?? [];

        setState(() {
          analyzing = false;

          if (aiStatus ==
              'SAFETY VIOLATION') {
            status =
                'SAFETY VIOLATION';

            if (violations.isNotEmpty) {
              resultMessage =
                  violations.map((v) {
                final className =
                    v['class'] ?? 'Unknown';

                final confidence =
                    v['confidence'] ?? 0;

                return '${className.toString().toUpperCase()} '
                    '(${(confidence * 100).toStringAsFixed(0)}%)';
              }).join('\n');
            } else {
              resultMessage =
                  'Safety violation detected';
            }
          } else {
            status = 'SAFE';

            resultMessage =
                'No safety violations detected';
          }
        });
      } else {
        setState(() {
          analyzing = false;
          status = 'ERROR';

          resultMessage =
              'Server error: ${response.statusCode}';
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        analyzing = false;
        status = 'ERROR';

        resultMessage =
            'Analysis error: $e';
      });
    }
  }

  // ==========================================================
  // MONITORING UI
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Live Safety Monitoring'),
      ),
      body: FutureBuilder<void>(
        future:
            initializeControllerFuture,
        builder:
            (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.done) {
            return Column(
              children: [

                // CAMERA
                Expanded(
                  child:
                      CameraPreview(controller),
                ),

                // RESULT + BUTTONS
                Padding(
                  padding:
                      const EdgeInsets.all(16),
                  child: Column(
                    children: [

                      // STATUS CARD
                      Container(
                        width:
                            double.infinity,
                        padding:
                            const EdgeInsets.all(16),
                        decoration:
                            BoxDecoration(
                          color: status ==
                                  'SAFETY VIOLATION'
                              ? Colors.red.shade50
                              : status == 'SAFE'
                                  ? Colors.green.shade50
                                  : Colors.grey.shade200,
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [

                            Icon(
                              status ==
                                      'SAFETY VIOLATION'
                                  ? Icons
                                      .warning_rounded
                                  : status ==
                                          'SAFE'
                                      ? Icons
                                          .check_circle
                                      : Icons.info,
                              size: 45,
                              color: status ==
                                      'SAFETY VIOLATION'
                                  ? Colors.red
                                  : status ==
                                          'SAFE'
                                      ? Colors.green
                                      : Colors.grey,
                            ),

                            const SizedBox(
                              height: 8,
                            ),

                            Text(
                              status,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight:
                                    FontWeight.bold,
                                color: status ==
                                        'SAFETY VIOLATION'
                                    ? Colors.red
                                    : status ==
                                            'SAFE'
                                        ? Colors.green
                                        : Colors.grey,
                              ),
                            ),

                            if (resultMessage
                                .isNotEmpty) ...[
                              const SizedBox(
                                height: 8,
                              ),

                              Text(
                                resultMessage,
                                textAlign:
                                    TextAlign.center,
                                style:
                                    const TextStyle(
                                  fontSize: 15,
                                  fontWeight:
                                      FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(
                        height: 10,
                      ),

                      // CAPTURE & ANALYZE
                      SizedBox(
                        width:
                            double.infinity,
                        child:
                            ElevatedButton.icon(
                          onPressed: analyzing
                              ? null
                              : captureAndAnalyze,
                          icon: analyzing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth:
                                        2,
                                  ),
                                )
                              : const Icon(
                                  Icons.camera,
                                ),
                          label: Text(
                            analyzing
                                ? 'Analyzing...'
                                : 'Capture & Analyze',
                          ),
                          style:
                              ElevatedButton.styleFrom(
                            padding:
                                const EdgeInsets.all(
                              16,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 10,
                      ),

                      // ANALYZE TEST IMAGE
                      SizedBox(
                        width:
                            double.infinity,
                        child:
                            OutlinedButton.icon(
                          onPressed: analyzing
                              ? null
                              : analyzeTestImage,
                          icon: const Icon(
                            Icons.image,
                          ),
                          label: const Text(
                            'Analyze Test Image',
                          ),
                        ),
                      ),

                      if (resultMessage
                          .isNotEmpty) ...[
                        const SizedBox(
                          height: 10,
                        ),
                      ],

                      const SizedBox(
                        height: 10,
                      ),

                      const Text(
                        'AI Monitoring Active',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                'Camera error: ${snapshot.error}',
              ),
            );
          } else {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }
        },
      ),
    );
  }
}

// ============================================================
// INCIDENT HISTORY SCREEN
// ============================================================
  // final String apiUrl =
  //     'http://10.102.157.67:8000/incidents';

class IncidentHistoryScreen extends StatefulWidget {
  const IncidentHistoryScreen({super.key});

  @override
  State<IncidentHistoryScreen> createState() =>
      _IncidentHistoryScreenState();
}

class _IncidentHistoryScreenState
    extends State<IncidentHistoryScreen> {
  final String apiUrl = 'http://10.29.216.67:8000/incidents';

  bool loading = true;
  String errorMessage = '';

  final TextEditingController searchController =
      TextEditingController();

  String selectedStatus = 'All';
  DateTime? selectedDate;

  List incidents = [];

  @override
  void initState() {
    super.initState();
    fetchIncidents();
  }

  // FETCH INCIDENTS
  Future<void> fetchIncidents() async {
    try {
      final token = await AuthService.getToken();

      if (token == null) {
        throw Exception('Please log in again.');
      }

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          incidents = data['incidents'] ?? [];
          loading = false;
          errorMessage = '';
        });
      } else {
        setState(() {
          loading = false;
          errorMessage =
              'Server error: ${response.statusCode} - ${response.body}';
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        errorMessage = 'Connection error: $e';
      });
    }
  }

  // SEARCH AND FILTER INCIDENTS
  List<dynamic> filterIncidents(List<dynamic> incidentList) {
    final query = searchController.text.trim().toLowerCase();

    return incidentList.where((incident) {
      final id = (incident['id'] ?? '').toString();
      final status =
          (incident['status'] ?? 'UNKNOWN').toString();

      final rawViolations = incident['violations'];
      String violationText = '';

      try {
        if (rawViolations is List) {
          violationText = rawViolations.map((item) {
            if (item is Map) {
              return (item['class'] ?? '').toString();
            }
            return item.toString();
          }).join(' ');
        } else if (rawViolations is String &&
            rawViolations.isNotEmpty) {
          final decoded = jsonDecode(rawViolations);

          if (decoded is List) {
            violationText = decoded.map((item) {
              if (item is Map) {
                return (item['class'] ?? '').toString();
              }
              return item.toString();
            }).join(' ');
          } else {
            violationText = rawViolations;
          }
        }
      } catch (_) {
        violationText = rawViolations?.toString() ?? '';
      }

      final matchesSearch =
          id.toLowerCase().contains(query) ||
          status.toLowerCase().contains(query) ||
          violationText.toLowerCase().contains(query);

      final normalizedStatus = status.toUpperCase();

      final matchesStatus =
          selectedStatus == 'All' ||
          (selectedStatus == 'Safe' &&
              normalizedStatus == 'SAFE') ||
          (selectedStatus == 'Safety Violations' &&
              normalizedStatus == 'SAFETY VIOLATION');

      final detectedAt = DateTime.tryParse(
        (incident['detected_at'] ?? '').toString(),
      );

      final matchesDate = selectedDate == null ||
          (detectedAt != null &&
              detectedAt.year == selectedDate!.year &&
              detectedAt.month == selectedDate!.month &&
              detectedAt.day == selectedDate!.day);

      return matchesSearch && matchesStatus && matchesDate;
    }).toList();
  }

  // INCIDENT HISTORY UI
  @override
  Widget build(BuildContext context) {
    final filteredIncidents = filterIncidents(incidents);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Incident History'),
        actions: [
          IconButton(
            tooltip: 'Refresh incidents',
            onPressed: () {
              setState(() {
                loading = true;
                errorMessage = '';
              });
              fetchIncidents();
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),

      body: loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      errorMessage,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Column(
                  children: [
                    // SEARCH BOX
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        12, 12, 12, 4,
                      ),
                      child: TextField(
                        controller: searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText:
                              'Search by incident ID or PPE...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              searchController.clear();
                              setState(() {});
                            },
                          ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),

                    // STATUS AND DATE FILTERS
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child:
                                DropdownButtonFormField<String>(
                              value: selectedStatus,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Safety Status',
                                border: OutlineInputBorder(),
                                contentPadding:
                                    EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 12,
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'All',
                                  child: Text('All'),
                                ),
                                DropdownMenuItem(
                                  value: 'Safe',
                                  child: Text('Safe'),
                                ),
                                DropdownMenuItem(
                                  value: 'Safety Violations',
                                  child: Text('Violations'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    selectedStatus = value;
                                  });
                                }
                              },
                            ),
                          ),

                          const SizedBox(width: 8),

                          IconButton(
                            tooltip: 'Filter by date',
                            icon: const Icon(
                              Icons.calendar_month,
                            ),
                            onPressed: () async {
                              final now = DateTime.now();

                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate ?? now,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(
                                  now.year,
                                  now.month,
                                  now.day,
                                ),
                              );

                              if (picked != null && mounted) {
                                setState(() {
                                  selectedDate = picked;
                                });
                              }
                            },
                          ),

                          IconButton(
                            tooltip: 'Clear all filters',
                            icon: const Icon(
                              Icons.filter_alt_off,
                            ),
                            onPressed: () {
                              searchController.clear();

                              setState(() {
                                selectedStatus = 'All';
                                selectedDate = null;
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    if (selectedDate != null)
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: 8,
                        ),
                        child: Text(
                          'Selected date: '
                          '${selectedDate!.day}/'
                          '${selectedDate!.month}/'
                          '${selectedDate!.year}',
                        ),
                      ),

                    // RESULT COUNT
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Incidents found: '
                          '${filteredIncidents.length}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    // FILTERED INCIDENT LIST
                    Expanded(
                      child: filteredIncidents.isEmpty
                          ? Center(
                              child: Text(
                                incidents.isEmpty
                                    ? 'No incidents recorded yet.'
                                    : 'No matching incidents found.',
                                style: const TextStyle(
                                  fontSize: 16,
                                ),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: fetchIncidents,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount:
                                    filteredIncidents.length,
                                itemBuilder: (context, index) {
                                  final incident =
                                      filteredIncidents[index];

                                  final status =
                                      (incident['status'] ??
                                              'UNKNOWN')
                                          .toString();

                                  final rawViolations =
                                      incident['violations'];

                                  List violationList = [];

                                  try {
                                    if (rawViolations is List) {
                                      violationList = rawViolations;
                                    } else if (rawViolations
                                            is String &&
                                        rawViolations.isNotEmpty) {
                                      final decoded =
                                          jsonDecode(rawViolations);

                                      if (decoded is List) {
                                        violationList = decoded;
                                      }
                                    }
                                  } catch (_) {
                                    violationList = [];
                                  }

                                  // REMOVE DUPLICATE PPE LABELS
                                  final Map<
                                      String,
                                      Map<String, dynamic>
                                  > uniqueViolations = {};

                                  for (final item
                                      in violationList) {
                                    if (item is! Map) continue;

                                    final className =
                                        (item['class'] ??
                                                'Unknown')
                                            .toString();

                                    final confidence =
                                        (item['confidence']
                                                    as num?)
                                                ?.toDouble() ??
                                            0.0;

                                    final key =
                                        className.toLowerCase();

                                    if (!uniqueViolations
                                            .containsKey(key) ||
                                        confidence >
                                            ((uniqueViolations[key]![
                                                        'confidence']
                                                    as num)
                                                .toDouble())) {
                                      uniqueViolations[key] = {
                                        'class': className,
                                        'confidence': confidence,
                                      };
                                    }
                                  }

                                  final displayViolations =
                                      uniqueViolations.values.toList();

                                  final detectedAt =
                                      (incident['detected_at'] ??
                                              'Unknown time')
                                          .toString();

                                  final isViolation =
                                      status.toUpperCase() ==
                                          'SAFETY VIOLATION';

                                  return Card(
                                    margin: const EdgeInsets.only(
                                      bottom: 12,
                                    ),
                                    child: ListTile(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                IncidentReportScreen(
                                              incident:
                                                  Map<String,
                                                      dynamic>.from(
                                                incident,
                                              ),
                                            ),
                                          ),
                                        );
                                      },

                                      leading: CircleAvatar(
                                        backgroundColor: isViolation
                                            ? Colors.red.shade100
                                            : Colors.green.shade100,
                                        child: Icon(
                                          isViolation
                                              ? Icons.warning
                                              : Icons.check,
                                          color: isViolation
                                              ? Colors.red
                                              : Colors.green,
                                        ),
                                      ),

                                      title: Text(
                                        status,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isViolation
                                              ? Colors.red
                                              : Colors.green,
                                        ),
                                      ),

                                      subtitle: Padding(
                                        padding:
                                            const EdgeInsets.only(
                                          top: 6,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (displayViolations
                                                .isEmpty)
                                              const Text(
                                                'No safety violations detected',
                                              )
                                            else
                                              ...displayViolations.map(
                                                (violation) {
                                                  final className =
                                                      (violation[
                                                                  'class'] ??
                                                              'Unknown')
                                                          .toString();

                                                  final confidence =
                                                      (violation[
                                                                  'confidence']
                                                              as num?)
                                                          ?.toDouble() ??
                                                      0.0;

                                                  final displayName =
                                                      className
                                                          .replaceAll(
                                                        '-',
                                                        ' ',
                                                      )
                                                          .toUpperCase();

                                                  return Padding(
                                                    padding:
                                                        const EdgeInsets
                                                            .only(
                                                      bottom: 4,
                                                    ),
                                                    child: Text(
                                                      '• $displayName '
                                                      '(${(confidence * 100).toStringAsFixed(0)}%)',
                                                      style:
                                                          const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),

                                            const SizedBox(height: 4),

                                            Text('Time: $detectedAt'),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState
    extends State<AdminDashboardScreen> {
  Future<void> logout() async {
    await AuthService.logout();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
//             ElevatedButton.icon(
//   icon: const Icon(Icons.people),
//   label: const Text('User Management'),
//   onPressed: () {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) =>
//             const UserManagementScreen(),
//       ),
//     );
//   },
// ),
            const Text(
              'Welcome, Admin',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Manage and monitor industrial safety',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 25),

            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const DashboardScreen(
  adminOverview: true,
),
                  ),
                );
              },
              icon: const Icon(Icons.dashboard),
              label: const Text(
                'View Safety Dashboard',
              ),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.all(16),
              ),
            ),

            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const MonitoringScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.camera_alt),
              label: const Text(
                'Start Safety Monitoring',
              ),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.all(16),
              ),
            ),

            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const IncidentHistoryScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.history),
              label: const Text(
                'View All Incidents',
              ),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 12),

             ElevatedButton.icon(
  icon: const Icon(Icons.people),
  label: const Text('User Management'),
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const UserManagementScreen(),
      ),
    );
  },
  style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.all(16),
              ),
),
const SizedBox(height: 12),

ElevatedButton.icon(
  icon: const Icon(Icons.analytics),
  label: const Text('Incident Analytics & Reports'),
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const AdminIncidentAnalyticsScreen(),
      ),
    );
  },
  style: ElevatedButton.styleFrom(
    padding: const EdgeInsets.all(16),
  ),
),
          ],
        ),
      ),
    );
  }
}