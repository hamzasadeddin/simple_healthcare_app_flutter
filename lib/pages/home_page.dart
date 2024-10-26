import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pure_health_clinic/pages/sign_up_page.dart';
import 'bookings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DateTime? _dentistDate;
  TimeOfDay? _dentistTime;

  DateTime? _internistDate;
  TimeOfDay? _internistTime;

  DateTime? _radiologistDate;
  TimeOfDay? _radiologistTime;

  DateTime? _plasticSurgeryDate;
  TimeOfDay? _plasticSurgeryTime;

  String _userName = 'Guest';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _fetchUserName();
  }

  void _fetchUserName() {
    if (_user != null) {
      setState(() {
        _userName = _user!.email?.split('@')[0] ?? 'Guest';
      });
    }
  }

  Future<void> _selectDate(BuildContext context, String appointmentType) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        switch (appointmentType) {
          case 'Dentist':
            _dentistDate = picked;
            break;
          case 'Internist':
            _internistDate = picked;
            break;
          case 'Radiologist':
            _radiologistDate = picked;
            break;
          case 'Plastic Surgery':
            _plasticSurgeryDate = picked;
            break;
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context, String appointmentType) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        switch (appointmentType) {
          case 'Dentist':
            _dentistTime = picked;
            break;
          case 'Internist':
            _internistTime = picked;
            break;
          case 'Radiologist':
            _radiologistTime = picked;
            break;
          case 'Plastic Surgery':
            _plasticSurgeryTime = picked;
            break;
        }
      });
    }
  }

  Future<String?> _validateBooking(DateTime? date, TimeOfDay? time) async {
    if (date == null || time == null) {
      return 'Please select both date and time.';
    }

    final selectedDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    final now = DateTime.now();
    final startOfWorkingHours = DateTime(
      selectedDateTime.year,
      selectedDateTime.month,
      selectedDateTime.day,
      9,
      0,
    );
    final endOfWorkingHours = DateTime(
      selectedDateTime.year,
      selectedDateTime.month,
      selectedDateTime.day,
      18,
      0,
    );

    if (selectedDateTime.isBefore(startOfWorkingHours) ||
        selectedDateTime.isAfter(endOfWorkingHours)) {
      return 'Appointment must be within working hours (9 AM to 6 PM).';
    }

    if (selectedDateTime.isBefore(now)) {
      return 'You cannot book an appointment in the past.';
    }

    final appointmentsQuery = await _firestore
        .collection('appointments')
        .where('dateTime', isEqualTo: selectedDateTime)
        .get();

    if (appointmentsQuery.docs.isNotEmpty) {
      return 'The selected time slot is already booked.';
    }

    final oneHourBefore = selectedDateTime.subtract(Duration(hours: 1));
    final oneHourAfter = selectedDateTime.add(Duration(hours: 1));

    final overlappingAppointmentsQuery = await _firestore
        .collection('appointments')
        .where('dateTime', isGreaterThanOrEqualTo: oneHourBefore)
        .where('dateTime', isLessThanOrEqualTo: oneHourAfter)
        .get();

    if (overlappingAppointmentsQuery.docs.isNotEmpty) {
      return 'There should be at least 1 hour between appointments.';
    }

    return null;
  }

  Future<void> _bookAppointment(
      String appointmentType, DateTime? date, TimeOfDay? time) async {
    final errorMessage = await _validateBooking(date, time);

    if (errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_user != null) {
      final selectedDateTime = DateTime(
        date!.year,
        date.month,
        date.day,
        time!.hour,
        time.minute,
      );

      await _firestore.collection('appointments').add({
        'userId': _user!.uid,
        'appointmentType': appointmentType,
        'dateTime': selectedDateTime,
        'createdAt': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Appointment booked successfully.'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User not logged in.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildAppointmentItem({
    required String name,
    required String price,
    required String imagePath,
    required String appointmentType,
    required DateTime? date,
    required TimeOfDay? time,
  }) {
    return Card(
      elevation: 5,
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Image.asset(imagePath, height: 60, width: 60),
        title: Text(name,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Price: $price'),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => _selectDate(context, appointmentType),
                    child: Text(
                      date != null
                          ? '${date.toLocal()}'.split(' ')[0]
                          : 'Select Date',
                      style: TextStyle(color: Colors.blueAccent),
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () => _selectTime(context, appointmentType),
                    child: Text(
                      time != null ? time.format(context) : 'Select Time',
                      style: TextStyle(color: Colors.blueAccent),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: () => _bookAppointment(appointmentType, date, time),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          child: Text('Book', style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }

  void _showUserOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.account_circle),
              title: Text('Welcome, $_userName'),
            ),
            ListTile(
              leading: Icon(Icons.book),
              title: Text('My Bookings'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BookingsPage(),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.logout),
              title: Text("Logout"),
              onTap: () async {
                bool? confirmLogout = await showDialog<bool>(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: Text('Logout'),
                      content: Text('Are you sure you want to logout?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: Text(
                            'Yes',
                            style: TextStyle(color: Colors.blueAccent),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text('No',
                              style: TextStyle(color: Colors.blueAccent)),
                        ),
                      ],
                    );
                  },
                );

                if (confirmLogout == true) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => SignUpPage()),
                    (route) => false,
                  );
                }
              },
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(
            child: Text(
          'Available Appointments',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        )),
        backgroundColor: Colors.blueAccent,
        automaticallyImplyLeading: false,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.more_vert),
            label: 'Options',
          ),
        ],
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.black,
        backgroundColor: Colors.white,
        elevation: 20,
        onTap: (index) {
          if (index == 1) {
            _showUserOptions();
          }
        },
      ),
      body: ListView(
        children: [
          _buildAppointmentItem(
            name: 'Dentist Appointment',
            price: '\$20',
            imagePath: 'assets/pictures/dentist.png',
            appointmentType: 'Dentist',
            date: _dentistDate,
            time: _dentistTime,
          ),
          _buildAppointmentItem(
            name: 'Internist Appointment',
            price: '\$35',
            imagePath: 'assets/pictures/internist.png',
            appointmentType: 'Internist',
            date: _internistDate,
            time: _internistTime,
          ),
          _buildAppointmentItem(
            name: 'Radiologist Appointment',
            price: '\$25',
            imagePath: 'assets/pictures/radiologist.png',
            appointmentType: 'Radiologist',
            date: _radiologistDate,
            time: _radiologistTime,
          ),
          _buildAppointmentItem(
            name: 'Plastic Surgery Appointment',
            price: '\$50',
            imagePath: 'assets/pictures/plasticsurgery.png',
            appointmentType: 'Plastic Surgery',
            date: _plasticSurgeryDate,
            time: _plasticSurgeryTime,
          ),
        ],
      ),
    );
  }
}
