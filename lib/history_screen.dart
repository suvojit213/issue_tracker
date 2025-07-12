import 'dart:io';

import 'package:flutter/material.dart';
import 'package:issue_tracker_app/issue_tracker_screen.dart';
import 'package:issue_tracker_app/issue_detail_screen.dart'; // New import
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart'; // Added for path_provider
import 'package:issue_tracker_app/report_generator.dart'; // Added for ReportGenerator

import 'package:issue_tracker_app/utils/issue_parser.dart';
import 'package:issue_tracker_app/history_onboarding_tour.dart'; // New import

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with TickerProviderStateMixin {
  List<String> _issueHistory = [];
  DateTime? _selectedDate;
  TimeOfDay? _selectedStartTime;
  TimeOfDay? _selectedEndTime;
  DateTime? _selectedDownloadDate;
  late AnimationController _animationController;
  late AnimationController _listController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  // GlobalKeys for onboarding tour
  final GlobalKey _firstHistoryItemKey = GlobalKey();
  final GlobalKey _dateFilterButtonKey = GlobalKey();
  final GlobalKey _startTimeFilterButtonKey = GlobalKey();
  final GlobalKey _endTimeFilterButtonKey = GlobalKey();
  final GlobalKey _clearHistoryButtonKey = GlobalKey();
  final GlobalKey _downloadButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _listController = AnimationController(
      duration: const Duration(milliseconds: 300),
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
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _listController,
      curve: Curves.easeOutCubic,
    ));
    _animationController.forward();
    _listController.forward();

    _checkAndShowHistoryOnboardingTour();
  }

  _checkAndShowHistoryOnboardingTour() async {
    final prefs = await SharedPreferences.getInstance();
    final bool onboardingComplete = prefs.getBool('history_onboarding_complete') ?? false;

    if (!onboardingComplete && _issueHistory.isNotEmpty) {
      // Delay showing the tour until the UI is rendered
      WidgetsBinding.instance.addPostFrameCallback((_) {
        HistoryOnboardingTour onboardingTour = HistoryOnboardingTour(
          firstHistoryItemKey: _firstHistoryItemKey,
          dateFilterButtonKey: _dateFilterButtonKey,
          startTimeFilterButtonKey: _startTimeFilterButtonKey,
          endTimeFilterButtonKey: _endTimeFilterButtonKey,
          clearHistoryButtonKey: _clearHistoryButtonKey,
        );
        onboardingTour.show(context);
        prefs.setBool('history_onboarding_complete', true);
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _listController.dispose();
    super.dispose();
  }

  _loadHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _issueHistory = prefs.getStringList("issueHistory") ?? [];
      _issueHistory = _issueHistory.reversed.toList();
    });
  }

  List<String> get _filteredHistory {
    List<String> filteredByDate = _issueHistory.where((entry) {
      Map<String, String> parsedEntry = parseHistoryEntry(entry);
      String? fillTime = parsedEntry['Fill Time'];
      if (fillTime == null) return false;

      try {
        DateTime entryDate = DateTime.parse(fillTime);
        return _selectedDate == null ||
            (entryDate.year == _selectedDate!.year &&
                entryDate.month == _selectedDate!.month &&
                entryDate.day == _selectedDate!.day);
      } catch (e) {
        return false;
      }
    }).toList();

    if (_selectedDate != null && (_selectedStartTime != null || _selectedEndTime != null)) {
      return filteredByDate.where((entry) {
        Map<String, String> parsedEntry = parseHistoryEntry(entry);
        String? startTimeStr = parsedEntry['Start Time'];
        String? endTimeStr = parsedEntry['End Time'];

        if (startTimeStr == null || endTimeStr == null) return false;

        try {
          DateTime issueStartTime = DateTime.parse(startTimeStr);
          DateTime issueEndTime = DateTime.parse(endTimeStr);

          // Apply date from _selectedDate to issue times for comparison
          issueStartTime = DateTime(
            _selectedDate!.year,
            _selectedDate!.month,
            _selectedDate!.day,
            issueStartTime.hour,
            issueStartTime.minute,
          );
          issueEndTime = DateTime(
            _selectedDate!.year,
            _selectedDate!.month,
            _selectedDate!.day,
            issueEndTime.hour,
            issueEndTime.minute,
          );

          bool matchesStartTime = true;
          if (_selectedStartTime != null) {
            DateTime selectedStartDateTime = DateTime(
              _selectedDate!.year,
              _selectedDate!.month,
              _selectedDate!.day,
              _selectedStartTime!.hour,
              _selectedStartTime!.minute,
            );
            matchesStartTime = issueStartTime.isAtSameMomentAs(selectedStartDateTime) ||
                (issueStartTime.isAfter(selectedStartDateTime) &&
                    issueStartTime.difference(selectedStartDateTime).inMinutes <= 15);
          }

          bool matchesEndTime = true;
          if (_selectedEndTime != null) {
            DateTime selectedEndDateTime = DateTime(
              _selectedDate!.year,
              _selectedDate!.month,
              _selectedDate!.day,
              _selectedEndTime!.hour,
              _selectedEndTime!.minute,
            );
            matchesEndTime = issueEndTime.isAtSameMomentAs(selectedEndDateTime) ||
                (issueEndTime.isBefore(selectedEndDateTime) &&
                    selectedEndDateTime.difference(issueEndTime).inMinutes <= 15);
          }
          return matchesStartTime && matchesEndTime;
        } catch (e) {
          return false;
        }
      }).toList();
    }
    return filteredByDate;
  }

  _clearHistory() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'Clear History',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A8A),
                  fontFamily: 'Poppins', // Added Poppins font
                ),
              ),
            ],
          ),
          content: const Text(
            'Are you sure you want to clear all issue history? This action cannot be undone.',
            style: TextStyle(
              fontSize: 16,
              fontFamily: 'Poppins', // Added Poppins font
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Poppins', // Added Poppins font
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                SharedPreferences prefs = await SharedPreferences.getInstance();
                await prefs.remove("issueHistory");
                setState(() {
                  _issueHistory.clear();
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Colors.white),
                        const SizedBox(width: 12),
                        const Text(
                          'History cleared successfully',
                          style: TextStyle(fontFamily: 'Poppins'), // Added Poppins font
                        ),
                      ],
                    ),
                    backgroundColor: const Color(0xFF059669),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.all(16),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Clear',
                style: TextStyle(fontFamily: 'Poppins'), // Added Poppins font
              ),
            ),
          ],
        );
      },
    );
  }

  void _showDownloadOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.download_rounded),
                title: const Text('Download All History (PDF)'),
                onTap: () {
                  Navigator.pop(bc);
                  _downloadReport(context, 'pdf', null);
                },
              ),
              ListTile(
                leading: const Icon(Icons.download_rounded),
                title: const Text('Download All History (XLSX)'),
                onTap: () {
                  Navigator.pop(bc);
                  _downloadReport(context, 'xlsx', null);
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today_rounded),
                title: const Text('Download for a Specific Date (PDF)'),
                onTap: () {
                  Navigator.pop(bc);
                  _showDatePickerForDownload(context, 'pdf');
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today_rounded),
                title: const Text('Download for a Specific Date (XLSX)'),
                onTap: () {
                  Navigator.pop(bc);
                  _showDatePickerForDownload(context, 'xlsx');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showDatePickerForDownload(BuildContext context, String format) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDate: _selectedDownloadDate ?? DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedDownloadDate = picked;
      });
      _downloadReport(context, format, _selectedDownloadDate);
    }
  }

  Future<void> _downloadReport(BuildContext context, String format, DateTime? downloadDate) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 12),
            Text('Generating $format report...'),
          ],
        ),
        duration: const Duration(days: 1), // Show indefinitely
      ),
    );

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String> history = prefs.getStringList("issueHistory") ?? [];

      List<String> filteredHistory = history.where((entry) {
        Map<String, String> parsedEntry = parseHistoryEntry(entry);
        String? fillTime = parsedEntry['Fill Time'];
        if (fillTime == null) return false;

        try {
          DateTime entryDate = DateTime.parse(fillTime);
          if (downloadDate != null) {
            return entryDate.year == downloadDate.year &&
                   entryDate.month == downloadDate.month &&
                   entryDate.day == downloadDate.day;
          } else {
            return true; // No date filter applied
          }
        } catch (e) {
          return false;
        }
      }).toList();

      if (filteredHistory.isEmpty) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Colors.white),
                const SizedBox(width: 12),
                const Text('No issues to download for the selected criteria.', style: TextStyle(fontFamily: 'Poppins')),
              ],
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
        return;
      }

      File? file;
      if (format == 'pdf') {
        file = await ReportGenerator.generatePdfReport(filteredHistory, downloadDate);
      } else if (format == 'xlsx') {
        file = await ReportGenerator.generateXlsxReport(filteredHistory, downloadDate);
      }

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (file != null) {
        _openFile(file.path);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Text('Report generated and ready to open!', style: TextStyle(fontFamily: 'Poppins')),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      } else {
        throw Exception('File generation failed.');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Text('Failed to generate report: $e', style: TextStyle(fontFamily: 'Poppins')),
            ],
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1E3A8A),
              Color(0xFFF8FAFC),
            ],
            stops: [0.0, 0.3],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
                        onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Issue History',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins', // Added Poppins font
                        ),
                      ),
                    ),
                    Container(
                      key: _downloadButtonKey, // Assign key
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.download_rounded, color: Colors.white),
                        onPressed: () => _showDownloadOptions(context),
                      ),
                    ),
                    if (_issueHistory.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Container(
                          key: _clearHistoryButtonKey, // Assign key
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                            onPressed: _clearHistory,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              // Content
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _issueHistory.isEmpty
                      ? _buildEmptyState()
                      : Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          key: _dateFilterButtonKey, // Assign key
                                          onPressed: () async {
                                            final DateTime? picked = await showDatePicker(
                                              context: context,
                                              initialDate: _selectedDate ?? DateTime.now(),
                                              firstDate: DateTime(2020),
                                              lastDate: DateTime.now(),
                                            );
                                            if (picked != null && picked != _selectedDate) {
                                              setState(() {
                                                _selectedDate = picked;
                                                _selectedStartTime = null; // Reset times on date change
                                                _selectedEndTime = null;
                                              });
                                            }
                                          },
                                          icon: const Icon(Icons.calendar_today_rounded, color: Colors.white),
                                          label: Text(
                                            _selectedDate == null
                                                ? 'Select Date'
                                                : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                                            style: const TextStyle(fontFamily: 'Poppins', color: Colors.white),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF3B82F6),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            elevation: 4,
                                          ),
                                        ),
                                      ),
                                      if (_selectedDate != null)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 8.0),
                                          child: IconButton(
                                            icon: const Icon(Icons.clear_rounded, color: Colors.grey),
                                            onPressed: () {
                                              setState(() {
                                                _selectedDate = null;
                                                _selectedStartTime = null;
                                                _selectedEndTime = null;
                                              });
                                            },
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (_selectedDate != null) ...[
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            key: _startTimeFilterButtonKey, // Assign key
                                            onPressed: () async {
                                              final TimeOfDay? picked = await showTimePicker(
                                                context: context,
                                                initialTime: _selectedStartTime ?? TimeOfDay.now(),
                                              );
                                              if (picked != null && picked != _selectedStartTime) {
                                                setState(() {
                                                  _selectedStartTime = picked;
                                                });
                                              }
                                            },
                                            icon: const Icon(Icons.access_time_rounded, color: Colors.white),
                                            label: Text(
                                              _selectedStartTime == null
                                                  ? 'Start Time'
                                                  : _selectedStartTime!.format(context),
                                              style: const TextStyle(fontFamily: 'Poppins', color: Colors.white),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF059669),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              elevation: 4,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            key: _endTimeFilterButtonKey, // Assign key
                                            onPressed: () async {
                                              final TimeOfDay? picked = await showTimePicker(
                                                context: context,
                                                initialTime: _selectedEndTime ?? TimeOfDay.now(),
                                              );
                                              if (picked != null && picked != _selectedEndTime) {
                                                setState(() {
                                                  _selectedEndTime = picked;
                                                });
                                              }
                                            },
                                            icon: const Icon(Icons.access_time_rounded, color: Colors.white),
                                            label: Text(
                                              _selectedEndTime == null
                                                  ? 'End Time'
                                                  : _selectedEndTime!.format(context),
                                              style: const TextStyle(fontFamily: 'Poppins', color: Colors.white),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFFEF4444),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              elevation: 4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        if (_selectedStartTime != null || _selectedEndTime != null)
                                          IconButton(
                                            icon: const Icon(Icons.clear_rounded, color: Colors.grey),
                                            onPressed: () {
                                              setState(() {
                                                _selectedStartTime = null;
                                                _selectedEndTime = null;
                                              });
                                            },
                                          ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Expanded(
                              child: _filteredHistory.isEmpty
                                  ? _buildNoResultsState()
                                  : _buildHistoryList(),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF1E3A8A).withOpacity(0.1),
                    const Color(0xFF3B82F6).withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(60),
              ),
              child: const Icon(
                Icons.history_rounded,
                size: 60,
                color: Color(0xFF1E3A8A),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'No History Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
                fontFamily: 'Poppins', // Added Poppins font
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your issue tracking history will appear here once you start recording issues.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
                fontFamily: 'Poppins', // Added Poppins font
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const IssueTrackerScreen()),
                        (Route<dynamic> route) => false,
                      ),
              icon: const Icon(Icons.add_task_rounded),
              label: const Text(
                'Record First Issue',
                style: TextStyle(fontFamily: 'Poppins'), // Added Poppins font
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(_slideAnimation),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Issues',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
                fontFamily: 'Poppins', // Added Poppins font
              ),
            ),
            
            const SizedBox(height: 16),
            
            // History List
            Expanded(
              child: ListView.builder(
                itemCount: _filteredHistory.length,
                itemBuilder: (context, index) {
                  return AnimatedContainer(
                    duration: Duration(milliseconds: 200 + (index * 50)),
                    curve: Curves.easeOutCubic,
                    child: _buildHistoryItem(
                      _filteredHistory[index],
                      index,
                      key: index == 0 ? _firstHistoryItemKey : null, // Assign key to the first item
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF1E3A8A).withOpacity(0.1),
                    const Color(0xFF3B82F6).withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 50,
                color: Color(0xFF1E3A8A),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Matching Results',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Try adjusting your search terms or clearing the search bar.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(String entry, int index, {Key? key}) {
    Map<String, String> parsedEntry = parseHistoryEntry(entry);
    List<String> imagePaths = parsedEntry['Images']?.split('|') ?? [];

    return Container(
      key: key, // Assign the key here
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => IssueDetailScreen(
                issueDetails: parsedEntry,
                imagePaths: imagePaths,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Issue #${_issueHistory.length - index}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                        onPressed: () => _confirmDelete(index),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF3B82F6).withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.report_problem_outlined,
                            color: Color(0xFF3B82F6),
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Issue Details',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF3B82F6),
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildIssueDetailRow('Issue Type', parsedEntry['Issue Explanation'] ?? 'N/A'),
                    const SizedBox(height: 8),
                    _buildIssueDetailRow('Reason', parsedEntry['Reason'] ?? 'N/A'),
                    if (parsedEntry['Issue Remarks'] != null && parsedEntry['Issue Remarks']!.isNotEmpty)
                      const SizedBox(height: 8),
                    if (parsedEntry['Issue Remarks'] != null && parsedEntry['Issue Remarks']!.isNotEmpty)
                      _buildIssueDetailRow('Remarks', parsedEntry['Issue Remarks']!),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E3A8A).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.access_time_rounded,
                            color: Color(0xFF1E3A8A),
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Time Information',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A),
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTimeInfo(
                            Icons.play_circle_outline_rounded,
                            'Start Time',
                            parsedEntry['Start Time'] ?? 'N/A',
                            const Color(0xFF059669),
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: const Color(0xFFE2E8F0),
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        Expanded(
                          child: _buildTimeInfo(
                            Icons.stop_circle_outlined,
                            'End Time',
                            parsedEntry['End Time'] ?? 'N/A',
                            const Color(0xFFEF4444),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(Icons.timer_rounded, 'Duration', _formatDuration(parsedEntry['Start Time'] ?? '', parsedEntry['End Time'] ?? '')),
                  ],
                ),
              ),
              if (imagePaths.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: imagePaths.length,
                    itemBuilder: (context, imgIndex) {
                      return GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => Dialog(
                              child: Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  Image.file(File(imagePaths[imgIndex])),
                                  IconButton(
                                    icon: const Icon(Icons.download_rounded, color: Colors.white),
                                    onPressed: () async {
                                      _openFile(imagePaths[imgIndex]);
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(imagePaths[imgIndex]),
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A8A).withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF3B82F6), // Changed icon color
            size: 16,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
            fontFamily: 'Poppins', // Added Poppins font
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E3A8A),
              fontFamily: 'Poppins', // Added Poppins font
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeInfo(IconData icon, String label, String timeIso, Color color) {
    String formattedTime = _formatTime(timeIso);
    String formattedDate = _formatOnlyDate(timeIso);

    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
            fontFamily: 'Poppins',
          ),
        ),
        const SizedBox(height: 2),
        Text(
          formattedDate,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: color,
            fontFamily: 'Poppins',
          ),
        ),
        const SizedBox(height: 2),
        Text(
          formattedTime,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }

  Widget _buildIssueDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
            fontFamily: 'Poppins', // Added Poppins font
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF3B82F6),
              fontFamily: 'Poppins', // Added Poppins font
            ),
          ),
        ),
      ],
    );
  }

  

  String _formatTime(String isoString) {
    try {
      DateTime dateTime = DateTime.parse(isoString);
      int hour = dateTime.hour;
      String period = hour >= 12 ? 'PM' : 'AM';
      hour = hour % 12;
      if (hour == 0) {
        hour = 12;
      }
      return '${hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')} $period';
    } catch (e) {
      return 'N/A';
    }
  }

  String _formatOnlyDate(String isoString) {
    try {
      DateTime dateTime = DateTime.parse(isoString);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return 'N/A';
    }
  }

  String _formatDuration(String startTimeIso, String endTimeIso) {
    try {
      DateTime start = DateTime.parse(startTimeIso);
      DateTime end = DateTime.parse(endTimeIso);
      Duration duration = end.difference(start);

      String twoDigits(int n) => n.toString().padLeft(2, "0");
      String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
      String twoDigitHours = twoDigits(duration.inHours);

      if (duration.inHours > 0) {
        return "${twoDigitHours}h ${twoDigitMinutes}m";
      } else if (duration.inMinutes > 0) {
        return "${twoDigitMinutes}m";
      } else {
        return "${duration.inSeconds}s";
      }
    } catch (e) {
      return 'N/A';
    }
  }

  

  _confirmDelete(int index) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.delete_forever_rounded,
                  color: Colors.red,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'Delete Entry',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A8A),
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
          content: const Text(
            'Are you sure you want to delete this history entry? This action cannot be undone.',
            style: TextStyle(
              fontSize: 16,
              fontFamily: 'Poppins',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                _deleteHistoryItem(index);
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Delete',
                style: TextStyle(fontFamily: 'Poppins'),
              ),
            ),
          ],
        );
      },
    );
  }

  _deleteHistoryItem(int index) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> currentHistory = prefs.getStringList("issueHistory") ?? [];
    // The displayed list is reversed, so we need to adjust the index for the actual stored list
    int originalIndex = currentHistory.length - 1 - index;
    if (originalIndex >= 0 && originalIndex < currentHistory.length) {
      currentHistory.removeAt(originalIndex);
      await prefs.setStringList("issueHistory", currentHistory);
      setState(() {
        _issueHistory.removeAt(index);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 12),
              const Text(
                'Entry deleted successfully',
                style: TextStyle(fontFamily: 'Poppins'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  static const platform = MethodChannel('com.suvojeet.issue_tracker_app/file_opener');

  Future<void> _openFile(String filePath) async {
    try {
      await platform.invokeMethod('openFile', {'filePath': filePath});
    } on PlatformException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open file: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}