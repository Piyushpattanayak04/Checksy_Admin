import 'package:cloud_firestore/cloud_firestore.dart';

/// Organization Model for Admin App
class Organization {
  final String id;
  final String name;
  final String? logoUrl;
  final String? bannerUrl;
  final String? description;
  final String? city;
  final String category;
  final bool isVerified;
  final int eventCount;
  final DateTime createdAt;

  Organization({
    required this.id,
    required this.name,
    this.logoUrl,
    this.bannerUrl,
    this.description,
    this.city,
    this.category = 'other',
    this.isVerified = false,
    this.eventCount = 0,
    required this.createdAt,
  });

  factory Organization.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Organization.fromMap(doc.id, data);
  }

  factory Organization.fromMap(String id, Map<String, dynamic> data) {
    return Organization(
      id: id,
      name: data['name'] ?? '',
      logoUrl: data['logoUrl'],
      bannerUrl: data['bannerUrl'],
      description: data['description'],
      city: data['city'],
      category: data['category'] ?? 'other',
      isVerified: data['isVerified'] ?? false,
      eventCount: data['eventCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'logoUrl': logoUrl,
      'bannerUrl': bannerUrl,
      'description': description,
      'city': city,
      'category': category,
      'isVerified': isVerified,
      'eventCount': eventCount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  String get initials {
    final words = name.split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }
}
