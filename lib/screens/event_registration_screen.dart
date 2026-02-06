import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class EventDetailsScreen extends StatefulWidget {
  final String eventName;

  const EventDetailsScreen({Key? key, required this.eventName}) : super(key: key);

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  final TextEditingController _eventNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _subEventController = TextEditingController();
  final List<String> subEvents = [];
  bool isProcessing = false;
  bool _isTeamBasedEvent = false;
  File? _selectedBannerImage;
  final ImagePicker _picker = ImagePicker();

  // Pick banner image from gallery
  Future<void> _pickBannerImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() {
          _selectedBannerImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  // Upload banner to Firebase Storage and return URL
  Future<String?> _uploadBanner(String eventName) async {
    if (_selectedBannerImage == null) return null;

    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('event_images')
          .child('$eventName.jpg');

      final uploadTask = await storageRef.putFile(
        _selectedBannerImage!,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading banner: $e')),
      );
      return null;
    }
  }

  // Event creation function
  Future<void> createEvent() async {
    final eventName = _eventNameController.text.trim();
    final description = _descriptionController.text.trim();

    // Validate event name and sub-events
    if (eventName.isEmpty || subEvents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter event name and at least one sub-event.')),
      );
      return;
    }

    try {
      setState(() {
        isProcessing = true;
      });

      // Upload banner if selected
      String? bannerUrl;
      if (_selectedBannerImage != null) {
        bannerUrl = await _uploadBanner(eventName);
      }

      final eventDoc = FirebaseFirestore.instance.collection('skeleton').doc(eventName);

      // Store event with all fields including banner and description
      await eventDoc.set({
        'eventName': eventName,
        'description': description,
        'subEvents': subEvents,
        'isTeamBasedEvent': _isTeamBasedEvent,
        'bannerUrl': bannerUrl ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event created successfully!')),
      );

      Navigator.pop(context, eventName);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating event: $e')),
      );
    } finally {
      setState(() {
        isProcessing = false;
      });
    }
  }

  // Add sub-event logic
  void addSubEvent() {
    final subEvent = _subEventController.text.trim();
    if (subEvent.isNotEmpty && !subEvents.contains(subEvent)) {
      setState(() {
        subEvents.add(subEvent);
        _subEventController.clear();
      });
    } else if (subEvents.contains(subEvent)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Duplicate sub-event not allowed.')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.eventName.isNotEmpty) {
      _eventNameController.text = widget.eventName;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Event')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event Name
            TextField(
              controller: _eventNameController,
              decoration: const InputDecoration(
                labelText: 'Event Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Event Description
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Event Description',
                hintText: 'Enter a brief description of the event...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Banner Image Picker
            const Text('Event Banner', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickBannerImage,
              child: Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[600]!),
                ),
                child: _selectedBannerImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _selectedBannerImage!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('Tap to select banner image', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Team-based Event Checkbox
            CheckboxListTile(
              title: const Text("Team-based Event"),
              subtitle: const Text("Enable if participants register as teams"),
              value: _isTeamBasedEvent,
              onChanged: (newValue) {
                setState(() {
                  _isTeamBasedEvent = newValue!;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),

            // Sub-events
            const Text('Sub-Events (Checkpoints)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextField(
              controller: _subEventController,
              decoration: InputDecoration(
                labelText: 'Add Sub-Event',
                hintText: 'e.g., Check-in, Lunch, Dinner',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add_circle),
                  onPressed: addSubEvent,
                ),
              ),
              onSubmitted: (_) => addSubEvent(),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: subEvents.map((e) {
                return Chip(
                  label: Text(e),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: () {
                    setState(() {
                      subEvents.remove(e);
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            // Create Event Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isProcessing ? null : createEvent,
                child: isProcessing
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create Event', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
