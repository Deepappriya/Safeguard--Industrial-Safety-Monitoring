
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'auth_service.dart';

class AdminIncidentAnalyticsScreen extends StatefulWidget {
  const AdminIncidentAnalyticsScreen({super.key});

  @override
  State<AdminIncidentAnalyticsScreen> createState() =>
      _AdminIncidentAnalyticsScreenState();
}

class _AdminIncidentAnalyticsScreenState
    extends State<AdminIncidentAnalyticsScreen> {
  // Update this IP if your laptop's Wi-Fi IP changes.
  static const String baseUrl = 'http://10.29.216.67:8000';

  String selectedPeriod = 'weekly';
  bool loading = true;
  bool exportingPdf = false;
  String errorMessage = '';

  Map<String, dynamic> report = {};
  List<dynamic> incidents = [];

  @override
  void initState() {
    super.initState();
    fetchReport();
  }

  Future<void> fetchReport() async {
    setState(() {
      loading = true;
      errorMessage = '';
    });

    try {
      final token = await AuthService.getToken();

      if (token == null) {
        throw Exception('Please log in again.');
      }

      final headers = {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      };

      final reportResponse = await http.get(
        Uri.parse(
          '$baseUrl/admin/incident-report?period=$selectedPeriod',
        ),
        headers: headers,
      );

      final incidentsResponse = await http.get(
        Uri.parse('$baseUrl/incidents'),
        headers: headers,
      );

      if (!mounted) return;

      if (reportResponse.statusCode == 403) {
        throw Exception('Admin access is required for this report.');
      }

      if (reportResponse.statusCode != 200) {
        throw Exception(
          'Report API error: ${reportResponse.statusCode}',
        );
      }

      if (incidentsResponse.statusCode != 200) {
        throw Exception(
          'Incident API error: ${incidentsResponse.statusCode}',
        );
      }

      final reportData = jsonDecode(reportResponse.body);
      final incidentData = jsonDecode(incidentsResponse.body);

      if (reportData is! Map || incidentData is! Map) {
        throw Exception('Unexpected response from the server.');
      }

      setState(() {
        report = Map<String, dynamic>.from(reportData);
        incidents = List<dynamic>.from(
          incidentData['incidents'] ?? [],
        );
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  int get reportDays {
    switch (selectedPeriod) {
      case 'daily':
        return 1;
      case 'monthly':
        return 30;
      default:
        return 7;
    }
  }

  int numberValue(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double doubleValue(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String formatDate(dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return 'Unknown date';
    }

    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return value.toString();

    final date = parsed.toLocal();

    String twoDigits(int number) => number.toString().padLeft(2, '0');

    return '${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year} '
        '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
  }

  DateTime? incidentDate(Map<String, dynamic> incident) {
    return DateTime.tryParse(
      (incident['detected_at'] ?? '').toString(),
    );
  }

  List<dynamic> parseViolations(dynamic raw) {
    if (raw == null) return [];

    dynamic decoded = raw;

    if (raw is String) {
      try {
        decoded = jsonDecode(raw);
      } catch (_) {
        return raw.trim().isEmpty ? [] : [raw];
      }
    }

    if (decoded is List) return decoded;
    if (decoded is Map) return [decoded];

    return decoded.toString().isEmpty ? [] : [decoded];
  }

  String violationLabel(dynamic item) {
    if (item is Map) {
      return (item['class'] ??
              item['label'] ??
              item['name'] ??
              item['violation'] ??
              'Unknown violation')
          .toString();
    }

    return item.toString();
  }

  List<Map<String, dynamic>> get periodIncidents {
    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: reportDays));

    final result = <Map<String, dynamic>>[];

    for (final item in incidents) {
      if (item is! Map) continue;

      final incident = Map<String, dynamic>.from(item);
      final date = incidentDate(incident);

      if (date != null && !date.isBefore(cutoff)) {
        result.add(incident);
      }
    }

    result.sort((a, b) {
      final dateA = incidentDate(a);
      final dateB = incidentDate(b);

      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;

      return dateB.compareTo(dateA);
    });

    return result;
  }

  Future<void> exportPdf() async {
    if (report.isEmpty) return;

    setState(() {
      exportingPdf = true;
    });

    try {
      final pdf = pw.Document();

      final totalChecks = numberValue(report['total_checks']);
      final safeCount = numberValue(report['safe_count']);
      final violationCount = numberValue(report['violation_count']);
      final violationRate = doubleValue(report['violation_rate']);

      final rawPpe = report['violations'];
      final ppe = rawPpe is Map
          ? Map<String, dynamic>.from(rawPpe)
          : <String, dynamic>{};

      final reportIncidents = periodIncidents;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          footer: (context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 12),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
          build: (context) => [
            pw.Text(
              'Industrial Safety Monitoring System',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              '${selectedPeriod[0].toUpperCase()}'
              '${selectedPeriod.substring(1)} Incident Report',
              style: const pw.TextStyle(fontSize: 16),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Generated: ${formatDate(DateTime.now().toIso8601String())}',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 20),

            pw.Text(
              '1. Safety Summary',
              style: pw.TextStyle(
                fontSize: 15,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Metric', 'Value'],
              data: [
                ['Reporting period', selectedPeriod],
                ['Total inspections', '$totalChecks'],
                ['Safe inspections', '$safeCount'],
                ['Safety violations', '$violationCount'],
                ['Violation rate', '$violationRate%'],
              ],
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellPadding: const pw.EdgeInsets.all(7),
            ),

            pw.SizedBox(height: 20),
            pw.Text(
              '2. PPE Violation Breakdown',
              style: pw.TextStyle(
                fontSize: 15,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['PPE category', 'Violation records'],
              data: [
                ['No helmet', '${numberValue(ppe['no_helmet'])}'],
                ['No vest', '${numberValue(ppe['no_vest'])}'],
                ['No gloves', '${numberValue(ppe['no_gloves'])}'],
                ['No shoes', '${numberValue(ppe['no_shoes'])}'],
              ],
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellPadding: const pw.EdgeInsets.all(7),
            ),

            pw.SizedBox(height: 20),
            pw.Text(
              '3. Individual Incident Details',
              style: pw.TextStyle(
                fontSize: 15,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),

            if (reportIncidents.isEmpty)
              pw.Text(
                'No incidents were returned for this reporting period.',
              )
            else
              pw.TableHelper.fromTextArray(
                headers: [
                  'ID',
                  'Date and time',
                  'Status',
                  'Detected violations',
                ],
                data: reportIncidents.map((incident) {
                  final violations =
                      parseViolations(incident['violations'])
                          .map(violationLabel)
                          .where((label) => label.trim().isNotEmpty)
                          .toSet()
                          .toList();

                  return [
                    (incident['id'] ?? 'N/A').toString(),
                    formatDate(incident['detected_at']),
                    (incident['status'] ?? 'UNKNOWN').toString(),
                    violations.isEmpty
                        ? 'None recorded'
                        : violations.join(', '),
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 9,
                ),
                cellStyle: const pw.TextStyle(fontSize: 8),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                cellPadding: const pw.EdgeInsets.all(5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(0.6),
                  1: const pw.FlexColumnWidth(1.5),
                  2: const pw.FlexColumnWidth(1.1),
                  3: const pw.FlexColumnWidth(2.2),
                },
              ),

            pw.SizedBox(height: 16),
            pw.Text(
              'Note: PPE category counts may overlap when one inspection '
              'contains multiple violations. Incident details are based '
              'on the records returned by the server.',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'Industrial_Safety_${selectedPeriod}_Report.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not generate PDF: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          exportingPdf = false;
        });
      }
    }
  }

  Widget buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildPpeRow(String label, int count, int maximum) {
    final progress = maximum == 0 ? 0.0 : count / maximum;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label)),
              Text(
                '$count',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
            backgroundColor: Colors.grey.shade300,
            color: Colors.deepOrange,
          ),
        ],
      ),
    );
  }

  Widget buildIncidentCard(Map<String, dynamic> incident) {
    final status =
        (incident['status'] ?? 'UNKNOWN').toString().toUpperCase();

    final isSafe = status == 'SAFE';

    final violations = parseViolations(incident['violations'])
        .map(violationLabel)
        .where((label) => label.trim().isNotEmpty)
        .toSet()
        .toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Incident #${incident['id'] ?? 'N/A'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Chip(
                  label: Text(status),
                  backgroundColor:
                      isSafe ? Colors.green.shade100 : Colors.red.shade100,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Date: ${formatDate(incident['detected_at'])}'),
            const SizedBox(height: 6),
            Text(
              'PPE violations: ${violations.isEmpty ? 'None recorded' : violations.join(', ')}',
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalChecks = numberValue(report['total_checks']);
    final safeCount = numberValue(report['safe_count']);
    final violationCount = numberValue(report['violation_count']);
    final violationRate = doubleValue(report['violation_rate']);

    final rawPpe = report['violations'];
    final ppe = rawPpe is Map
        ? Map<String, dynamic>.from(rawPpe)
        : <String, dynamic>{};

    final noHelmet = numberValue(ppe['no_helmet']);
    final noVest = numberValue(ppe['no_vest']);
    final noGloves = numberValue(ppe['no_gloves']);
    final noShoes = numberValue(ppe['no_shoes']);

    final maxPpe = [
      noHelmet,
      noVest,
      noGloves,
      noShoes,
      1,
    ].reduce((a, b) => a > b ? a : b);

    final reportIncidents = periodIncidents;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Incident Analytics & Reports'),
        actions: [
          IconButton(
            tooltip: 'Refresh report',
            onPressed: loading ? null : fetchReport,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          errorMessage,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: fetchReport,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: fetchReport,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text(
                        'Safety Report Overview',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Review inspections and PPE safety violations.',
                      ),
                      const SizedBox(height: 18),

                      DropdownButtonFormField<String>(
                        value: selectedPeriod,
                        decoration: const InputDecoration(
                          labelText: 'Reporting period',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.date_range),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'daily',
                            child: Text('Daily — last 1 day'),
                          ),
                          DropdownMenuItem(
                            value: 'weekly',
                            child: Text('Weekly — last 7 days'),
                          ),
                          DropdownMenuItem(
                            value: 'monthly',
                            child: Text('Monthly — last 30 days'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;

                          setState(() {
                            selectedPeriod = value;
                          });

                          fetchReport();
                        },
                      ),

                      const SizedBox(height: 16),

                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 1.35,
                        children: [
                          buildSummaryCard(
                            'Total Inspections',
                            '$totalChecks',
                            Icons.fact_check,
                            Colors.blue,
                          ),
                          buildSummaryCard(
                            'Safe Inspections',
                            '$safeCount',
                            Icons.verified_user,
                            Colors.green,
                          ),
                          buildSummaryCard(
                            'Safety Violations',
                            '$violationCount',
                            Icons.warning_amber,
                            Colors.red,
                          ),
                          buildSummaryCard(
                            'Violation Rate',
                            '${violationRate.toStringAsFixed(2)}%',
                            Icons.pie_chart,
                            Colors.deepOrange,
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'PPE Violation Breakdown',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              buildPpeRow(
                                'No Helmet',
                                noHelmet,
                                maxPpe,
                              ),
                              buildPpeRow(
                                'No Vest',
                                noVest,
                                maxPpe,
                              ),
                              buildPpeRow(
                                'No Gloves',
                                noGloves,
                                maxPpe,
                              ),
                              buildPpeRow(
                                'No Shoes',
                                noShoes,
                                maxPpe,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Individual Incident Details (${reportIncidents.length})',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      if (reportIncidents.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(18),
                            child: Text(
                              'No incidents found for this period.',
                            ),
                          ),
                        )
                      else
                        ...reportIncidents.map(buildIncidentCard),

                      const SizedBox(height: 16),

                      SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: exportingPdf ? null : exportPdf,
                          icon: exportingPdf
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.picture_as_pdf),
                          label: Text(
                            exportingPdf
                                ? 'Generating PDF...'
                                : 'Export Full Report as PDF',
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }
}
