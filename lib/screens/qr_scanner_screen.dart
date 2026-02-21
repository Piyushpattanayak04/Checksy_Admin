import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'attendance_screen.dart';
import '../widgets/scanner_overlay.dart';
import '../services/admin_auth_service.dart';
import '../themes/app_colors.dart';

class QRScannerScreen extends StatefulWidget {
  final String eventName;

  const QRScannerScreen({super.key, required this.eventName});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  bool isProcessing = false;
  final MobileScannerController scannerController = MobileScannerController();

  void handleScan(String code) async {
    if (isProcessing) return;
    setState(() => isProcessing = true);
    scannerController.stop();

    try {
      final parts = code.split('_');
      if (parts.length < 4) throw 'Invalid QR format';

      final eventName = parts[0];
      final memberName = parts[1];
      final teamName = parts[2];
      final collegeName = parts[3];

      final skeletonDoc = await FirebaseFirestore.instance
          .collection('skeleton')
          .doc(eventName)
          .get();

      if (!skeletonDoc.exists) throw 'Event not registered in skeleton.';

      // Check organization access
      final eventData = skeletonDoc.data()!;
      final eventOrgId = eventData['organizationId'] ?? '';
      final currentAdmin = AdminAuthService.currentAdmin;
      
      // Only allow scanning for events in the admin's organization (or super admin)
      if (!AdminAuthService.isSuperAdmin && 
          currentAdmin != null && 
          eventOrgId.isNotEmpty &&
          currentAdmin.organizationId != eventOrgId) {
        throw 'This event belongs to a different organization.';
      }

      final subEvents = List<String>.from(eventData['subEvents'] ?? []);
      if (subEvents.isEmpty) throw 'No sub-events found for this event.';

      final memberRef = FirebaseFirestore.instance
          .collection('events')
          .doc(eventName)
          .collection('teams')
          .doc(teamName)
          .collection('members')
          .doc(memberName);

      final memberDoc = await memberRef.get();

      if (!memberDoc.exists) {
        await FirebaseFirestore.instance
            .collection('events')
            .doc(eventName)
            .set({'eventName': eventName}, SetOptions(merge: true));

        await FirebaseFirestore.instance
            .collection('events')
            .doc(eventName)
            .collection('teams')
            .doc(teamName)
            .set({'teamName': teamName}, SetOptions(merge: true));

        final memberData = {
          for (var sub in subEvents) sub: false,
          'collegeName': collegeName,
        };
        await memberRef.set(memberData);
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AttendanceScreen(
            eventName: eventName,
            teamName: teamName,
            memberName: memberName,
          ),
        ),
      );

      scannerController.start();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      scannerController.start();
    } finally {
      setState(() => isProcessing = false);
    }
  }

  @override
  void dispose() {
    scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Prevent navigating back from QR screen
      onWillPop: () async => false,
      child: Stack(
        children: [
          MobileScanner(
            controller: scannerController,
            onDetect: (BarcodeCapture capture) {
              for (final barcode in capture.barcodes) {
                final code = barcode.rawValue;
                if (code != null) {
                  handleScan(code);
                  break;
                }
              }
            },
          ),
          const ScannerOverlay(),
        ],
      ),
    );
  }
}
