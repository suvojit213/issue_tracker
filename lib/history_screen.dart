import 'dart:io';

import 'package:flutter/material.dart';
import 'package:issue_tracker_app/issue_tracker_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with TickerProviderStateMixin {
  List<String> _issueHistory = [];
  DateTime? _selectedDate;
  late AnimationController _animationController;
  late AnimationController _listController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _listController = AnimationController(
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
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _listController,
      curve: Curves.easeOutCubic,
    ));
    _animationController.forward();
    _listController.forward();
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
    if (_selectedDate == null) {
      return _issueHistory;
    }
    return _issueHistory.where((entry) {
      Map<String, String> parsedEntry = _parseHistoryEntry(entry);
      String? fillTime = parsedEntry['Fill Time'];
      if (fillTime == null) return false;

      try {
        DateTime entryDate = DateTime.parse(fillTime);
        return entryDate.year == _selectedDate!.year &&
            entryDate.month == _selectedDate!.month &&
            entryDate.day == _selectedDate!.day;
      } catch (e) {
        return false;
      }
    }).toList();
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
                        onPressed: () => Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const IssueTrackerScreen()),
                        (Route<dynamic> route) => false,
                      ),
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
                    if (_issueHistory.isNotEmpty)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                          onPressed: _clearHistory,
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
                              child: Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
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
                                          });
                                        },
                                      ),
                                    ),
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
            // Stats Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E3A8A).withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.analytics_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Issues Recorded',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Poppins', // Added Poppins font
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_issueHistory.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins', // Added Poppins font
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
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
                    child: _buildHistoryItem(_filteredHistory[index], index),
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

  Widget _buildHistoryItem(String entry, int index) {
    Map<String, String> parsedEntry = _parseHistoryEntry(entry);
    List<String> imagePaths = parsedEntry['Images']?.split('|') ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
                    if (parsedEntry['Fill Time'] != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${_formatOnlyDate(parsedEntry['Fill Time']!)}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          Text(
                            'Filled: ${_formatTime(parsedEntry['Fill Time']!)}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.share_rounded, color: Colors.blueAccent),
                      onPressed: () => _shareIssue(parsedEntry, imagePaths),
                      visualDensity: VisualDensity.compact,
                    ),
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
                                    await Share.shareXFiles([XFile(imagePaths[imgIndex])]);
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

  Map<String, String> _parseHistoryEntry(String entry) {
    Map<String, String> parsed = {};
    List<String> parts = entry.split(', ');
    
    for (String part in parts) {
      List<String> keyValue = part.split(': ');
      if (keyValue.length == 2) {
        parsed[keyValue[0]] = keyValue[1];
      }
    }
    
    return parsed;
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

  _shareIssue(Map<String, String> parsedEntry, List<String> imagePaths) {
    String message = "*Issue Report*\n\n"
        "*Advisor Name:* ${parsedEntry['Advisor Name']}\n"
        "*CRM ID:* ${parsedEntry['CRM ID']}\n"
        
        "*Organization:* ${parsedEntry['Organization']}\n\n"
        "*Issue:* ${parsedEntry['Issue Explanation']}\n"
        "*Reason:* ${parsedEntry['Reason']}\n\n"
        "*Start Time:* ${_formatTime(parsedEntry['Start Time']!)} on ${_formatOnlyDate(parsedEntry['Start Time']!)}\n"
        "*End Time:* ${_formatTime(parsedEntry['End Time']!)} on ${_formatOnlyDate(parsedEntry['End Time']!)}\n"
        "*Duration:* ${_formatDuration(parsedEntry['Start Time']!, parsedEntry['End Time']!)}\n"
        "*Fill Time:* ${_formatTime(parsedEntry['Fill Time']!)} on ${_formatOnlyDate(parsedEntry['Fill Time']!)}\n\n"
        "This report was generated from the Issue Tracker App.";

    Share.shareXFiles(imagePaths.map((path) => XFile(path)).toList(), text: message);
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
}