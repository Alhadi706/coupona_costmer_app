// Lightweight Firebase wrapper to keep shared package API stable.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class SupabaseService {
  // Expose Firestore and Storage through a familiar class name so imports
  // in the shared package remain valid while using Firebase under the hood.
  static FirebaseFirestore get firestore => FirebaseFirestore.instance;
  static FirebaseStorage get storage => FirebaseStorage.instance;
}
