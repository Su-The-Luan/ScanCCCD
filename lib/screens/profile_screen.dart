import 'package:flutter/material.dart';
import 'package:smart_cccd/widgets/info_row.dart';
import '../models/cccd_info.dart';

class ProfileScreen extends StatelessWidget {
  final CccdInfo info;

  const ProfileScreen({super.key, required this.info});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông tin CCCD'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.lightBlue.shade100, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.blue.shade200,
                      child: const Icon(
                        Icons.person,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    info.fullName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  InfoRow(icon: Icons.credit_card, label: 'Số CCCD', value: info.idNumber),
                  InfoRow(icon: Icons.badge, label: 'Số CMND', value: info.oldIdNumber),
                  InfoRow(icon: Icons.calendar_today, label: 'Ngày sinh', value: info.dateOfBirth),
                  InfoRow(icon: Icons.person_outline, label: 'Giới tính', value: info.gender),
                  InfoRow(icon: Icons.flag, label: 'Quốc tịch', value: info.nationality),
                  InfoRow(icon: Icons.home, label: 'Thường trú', value: info.permanentAddress),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
