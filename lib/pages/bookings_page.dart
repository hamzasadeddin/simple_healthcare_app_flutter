import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class BookingsPage extends StatefulWidget {
  const BookingsPage({super.key});

  @override
  State<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return Scaffold(
        appBar: AppBar(
          title: Center(child: Text('Bookings')),
          backgroundColor: Colors.blueAccent,
        ),
        body: Center(child: Text('User not logged in.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Center(
            child: Text(
          'My Bookings',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        )),
        backgroundColor: Colors.blueAccent,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('appointments')
            .where('userId', isEqualTo: _user!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No bookings found.'));
          }

          final bookings = snapshot.data!.docs;

          return ListView.builder(
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final booking = bookings[index];
              final appointmentType = booking['appointmentType'];
              final dateTime = (booking['dateTime'] as Timestamp).toDate();

              return Card(
                elevation: 5,
                margin:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text('$appointmentType Appointment',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  subtitle: Text('Date & Time: ${dateTime.toLocal()}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, color: Colors.blueAccent),
                        onPressed: () async {
                          await _editAppointment(booking.id, dateTime);
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final confirm = await _showConfirmationDialog();
                          if (confirm) {
                            await _cancelAppointment(booking.id);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<bool> _showConfirmationDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Cancel Appointment'),
          content: Text('Are you sure you want to cancel this appointment?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: Text('Yes', style: TextStyle(color: Colors.blueAccent)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: Text('No', style: TextStyle(color: Colors.blueAccent)),
            ),
          ],
        );
      },
    ).then((value) => value ?? false);
  }

  Future<void> _cancelAppointment(String bookingId) async {
    try {
      await _firestore.collection('appointments').doc(bookingId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Appointment cancelled successfully.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel appointment. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _editAppointment(String bookingId, DateTime oldDateTime) async {
    DateTime? newDate;
    TimeOfDay? newTime;

    await _selectDate(context).then((value) {
      newDate = value;
    });

    await _selectTime(context).then((value) {
      newTime = value;
    });

    if (newDate != null && newTime != null) {
      final newDateTime = DateTime(
        newDate!.year,
        newDate!.month,
        newDate!.day,
        newTime!.hour,
        newTime!.minute,
      );

      final errorMessage = await _validateBooking(newDateTime);

      if (errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      try {
        await _firestore.collection('appointments').doc(bookingId).update({
          'dateTime': newDateTime,
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Appointment updated successfully.'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update appointment. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<DateTime?> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    return picked;
  }

  Future<TimeOfDay?> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    return picked;
  }

  Future<String?> _validateBooking(DateTime dateTime) async {
    final now = DateTime.now();
    final startOfWorkingHours = DateTime(
      dateTime.year,
      dateTime.month,
      dateTime.day,
      9,
      0,
    );
    final endOfWorkingHours = DateTime(
      dateTime.year,
      dateTime.month,
      dateTime.day,
      18,
      0,
    );

    if (dateTime.isBefore(startOfWorkingHours) ||
        dateTime.isAfter(endOfWorkingHours)) {
      return 'Appointment must be within working hours (9 AM to 6 PM).';
    }

    if (dateTime.isBefore(now)) {
      return 'You cannot book an appointment in the past.';
    }

    final appointmentsQuery = await _firestore
        .collection('appointments')
        .where('dateTime', isEqualTo: dateTime)
        .get();

    if (appointmentsQuery.docs.isNotEmpty) {
      return 'The selected time slot is already booked.';
    }

    final oneHourBefore = dateTime.subtract(Duration(hours: 1));
    final oneHourAfter = dateTime.add(Duration(hours: 1));

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
}
