import 'package:flutter/material.dart';
import 'ambulance_confirmation_screen.dart';

class MessageReportDetailsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Message Report')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Incident Details:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              'Incident location: [Sample location]',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 10),
            Text(
              'Details: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
              style: TextStyle(fontSize: 16),
            ),
            Spacer(),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AmbulanceConfirmationScreen()),
                );
              },
              child: Text('Submit to CDRRMO'),
            ),
          ],
        ),
      ),
    );
  }
}
