import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';

class PrayerTimesPage extends StatefulWidget {
  @override
  _PrayerTimesPageState createState() => _PrayerTimesPageState();
}

class _PrayerTimesPageState extends State<PrayerTimesPage> {
  Map<String, dynamic>? todayData;
  String? todayDate;
  String? todayDay;

  @override
  void initState() {
    super.initState();
    loadPrayerTimes();
  }

  Future<void> loadPrayerTimes() async {
    // Load JSON data
    String jsonString = await rootBundle.loadString('assets/prayer_times.json');
    Map<String, dynamic> jsonData = json.decode(jsonString);

    // Get current date components
    int currentDay = DateTime.now().day;
    String currentMonth = DateFormat('MMMM').format(DateTime.now());
    int currentYear = DateTime.now().year;

    // Debugging: Print current date info
    print('Current Day: $currentDay');
    print('Current Month: $currentMonth');
    print('Current Year: $currentYear');

    // Extract data from "Sheet 2"
    List<dynamic> sheetData = jsonData["Sheet 2"];

    // Find today's prayer times and details
    var today = sheetData.firstWhere(
      (item) =>
          item['gregorian_day'] == currentDay &&
          item['gregorian_month'].toString().toLowerCase() ==
              currentMonth.toLowerCase() &&
          item['gregorian_year'] == currentYear,
      orElse: () => null,
    );

    // Debugging: Print today's data if found
    if (today != null) {
      print('Today\'s Data: $today');
    } else {
      print('No data found for today.');
    }

    setState(() {
      todayData = today;
      todayDate = '$currentDay $currentMonth $currentYear';
      todayDay = today?['day_of_week'];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Today\'s Prayer Times'),
      ),
      body: todayData != null
          ? Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Display Gregorian date
                  Text(
                    'Date: $todayDate',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  // Display day of the week
                  Text(
                    'Day: ${todayDay ?? ''}',
                    style: TextStyle(fontSize: 20, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  // Display Hijri date
                  Text(
                    'Hijri: ${todayData!['hijri_month_name']} ${todayData!['hijri_year']}',
                    style: TextStyle(fontSize: 18),
                  ),
                  SizedBox(height: 8),
                  // Display Event if available
                  if (todayData!['event'] != null)
                    Text(
                      'Event: ${todayData!['event']}',
                      style: TextStyle(fontSize: 18, color: Colors.blue),
                    ),
                  SizedBox(height: 8),
                  // Display status
                  Text(
                    'Status: ${todayData!['status']}',
                    style: TextStyle(
                      fontSize: 18,
                      color: todayData!['status'] == 'صالحة'
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                  SizedBox(height: 16),
                  // Display prayer times in the center
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Fajr: ${todayData!['fajr_hour']}:${todayData!['fajr_minute']}',
                            style: TextStyle(fontSize: 18),
                          ),
                          Text(
                            'Sunrise: ${todayData!['sunrise_hour']}:${todayData!['sunrise_minute']}',
                            style: TextStyle(fontSize: 18),
                          ),
                          Text(
                            'Dhuhr: ${todayData!['dhuhr_hour']}:${todayData!['dhuhr_minute']}',
                            style: TextStyle(fontSize: 18),
                          ),
                          Text(
                            'Maghrib: ${todayData!['maghrib_hour']}:${todayData!['maghrib_minute']}',
                            style: TextStyle(fontSize: 18),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )
          : Center(
              child: Text(
                'Prayer times not available for today.',
                style: TextStyle(fontSize: 18),
              ),
            ),
    );
  }
}
