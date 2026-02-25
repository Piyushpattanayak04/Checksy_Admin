import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';

/// Service to export event participant data to Excel and upload to Firebase Storage.
/// Runs export in background and stores history in Firestore.
class ExportService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Start the export process in the background.
  /// Shows a toast immediately and notifies via [onComplete] callback when done.
  static Future<void> exportEventData({
    required String eventName,
    required String eventDisplayName,
    required List<String> subEvents,
    required String exportedBy,
    required VoidCallback onComplete,
    required Function(String error) onError,
  }) async {
    try {
      // 1. Fetch all teams
      final teamsSnapshot =
          await _firestore
              .collection('tickets')
              .doc(eventName)
              .collection('teams')
              .get();

      if (teamsSnapshot.docs.isEmpty) {
        onError('No participants registered for this event');
        return;
      }

      // 2. Create Excel workbook
      final excel = Excel.createExcel();
      final sheet = excel['Participants'];
      excel.delete('Sheet1');

      // Headers
      final headers = [
        'Team Name',
        'Member Name',
        'Email',
        'College',
        'Roll Number',
        'Class',
        'Registration Date',
        ...subEvents,
      ];

      for (var i = 0; i < headers.length; i++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
        );
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.blue200,
          horizontalAlign: HorizontalAlign.Center,
        );
      }

      int rowIndex = 1;

      // 3. Iterate through all teams and members
      for (final teamDoc in teamsSnapshot.docs) {
        final teamName = teamDoc.id;

        final membersSnapshot =
            await _firestore
                .collection('tickets')
                .doc(eventName)
                .collection('teams')
                .doc(teamName)
                .collection('members')
                .get();

        for (final memberDoc in membersSnapshot.docs) {
          final data = memberDoc.data();
          final memberName = data['memberName'] ?? '';

          // Fetch attendance from events collection
          Map<String, dynamic> attendanceData = {};
          if (memberName.isNotEmpty) {
            try {
              final attendanceDoc =
                  await _firestore
                      .collection('events')
                      .doc(eventName)
                      .collection('teams')
                      .doc(teamName)
                      .collection('members')
                      .doc(memberName)
                      .get();

              if (attendanceDoc.exists) {
                attendanceData = attendanceDoc.data() ?? {};
              }
            } catch (_) {}
          }

          final row = [
            data['teamName'] ?? teamName,
            memberName,
            data['email'] ?? '',
            data['collegeName'] ?? '',
            data['rollNumber'] ?? '',
            data['class'] ?? '',
            data['date'] ?? '',
          ];

          for (final subEvent in subEvents) {
            final value = attendanceData[subEvent];
            row.add(value == true ? 'Yes' : 'No');
          }

          for (var i = 0; i < row.length; i++) {
            final cell = sheet.cell(
              CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIndex),
            );
            cell.value = TextCellValue(row[i].toString());
          }
          rowIndex++;
        }
      }

      // Set column widths
      for (var i = 0; i < headers.length; i++) {
        sheet.setColumnWidth(i, 20);
      }

      // 4. Save locally
      final bytes = excel.save();
      if (bytes == null) throw Exception('Failed to generate Excel file');

      final directory = await getTemporaryDirectory();
      final now = DateTime.now();
      final timestamp =
          '${now.year}${_pad(now.month)}${_pad(now.day)}_${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';
      final fileName =
          '${eventDisplayName.replaceAll(' ', '_')}_export_$timestamp.xlsx';
      final localPath = '${directory.path}/$fileName';
      final file = File(localPath);
      await file.writeAsBytes(bytes);

      // 5. Upload to Firebase Storage
      final storageRef = _storage
          .ref()
          .child('exports')
          .child(eventName)
          .child(fileName);

      await storageRef.putFile(
        file,
        SettableMetadata(
          contentType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ),
      );

      final downloadUrl = await storageRef.getDownloadURL();

      // 6. Save export record to Firestore
      await _firestore
          .collection('skeleton')
          .doc(eventName)
          .collection('exports')
          .add({
            'fileName': fileName,
            'downloadUrl': downloadUrl,
            'storagePath': 'exports/$eventName/$fileName',
            'exportedAt': FieldValue.serverTimestamp(),
            'exportedBy': exportedBy,
            'participantCount': rowIndex - 1,
          });

      // 7. Notify completion
      onComplete();
    } catch (e) {
      onError(e.toString());
    }
  }

  /// Fetch list of past exports for an event
  static Stream<QuerySnapshot> getExportsStream(String eventName) {
    return _firestore
        .collection('skeleton')
        .doc(eventName)
        .collection('exports')
        .orderBy('exportedAt', descending: true)
        .snapshots();
  }

  /// Delete an export record and its file from storage
  static Future<void> deleteExport(
    String eventName,
    String docId,
    String storagePath,
  ) async {
    try {
      await _storage.ref().child(storagePath).delete();
    } catch (_) {
      // File might already be deleted from storage
    }
    await _firestore
        .collection('skeleton')
        .doc(eventName)
        .collection('exports')
        .doc(docId)
        .delete();
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
