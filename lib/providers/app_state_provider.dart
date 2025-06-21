import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class AppStateProvider extends ChangeNotifier {
  late final SupabaseService _supabaseService;
  List<Contact> _contacts = [];
  bool _isLoading = false;
  String? _error;

  AppStateProvider() {
    _initialize();
  }

  List<Contact> get contacts => _contacts;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> _initialize() async {
    _supabaseService = SupabaseService(Supabase.instance.client);
    await loadContacts();
  }

  Future<void> loadContacts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _contacts = await _supabaseService.getContacts();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Contact> saveContact(String name, String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final contact = await _supabaseService.saveContact(name, email);
      _contacts.add(contact);
      _contacts.sort((a, b) => a.name.compareTo(b.name));
      return contact;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteContact(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _supabaseService.deleteContact(id);
      _contacts.removeWhere((contact) => contact.id == id);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Contact?> findContactByName(String name) async {
    try {
      return await _supabaseService.findContactByName(name);
    } catch (e) {
      _error = e.toString();
      return null;
    }
  }
}
