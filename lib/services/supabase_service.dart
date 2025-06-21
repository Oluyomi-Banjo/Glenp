import 'package:supabase_flutter/supabase_flutter.dart';

class Contact {
  final String id;
  final String name;
  final String email;

  Contact({
    required this.id,
    required this.name,
    required this.email,
  });

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'],
      name: json['name'],
      email: json['email'],
    );
  }
}

class SupabaseService {
  final SupabaseClient _supabaseClient;

  SupabaseService(this._supabaseClient);

  Future<List<Contact>> getContacts() async {
    final response = await _supabaseClient
        .from('contacts')
        .select()
        .order('name');
    
    return (response as List)
        .map((contact) => Contact.fromJson(contact))
        .toList();
  }

  Future<Contact> saveContact(String name, String email) async {
    final response = await _supabaseClient
        .from('contacts')
        .insert({
          'name': name,
          'email': email,
        })
        .select()
        .single();
    
    return Contact.fromJson(response);
  }

  Future<void> deleteContact(String id) async {
    await _supabaseClient
        .from('contacts')
        .delete()
        .eq('id', id);
  }

  Future<Contact?> findContactByName(String name) async {
    final response = await _supabaseClient
        .from('contacts')
        .select()
        .ilike('name', '%$name%')
        .limit(1);
    
    if (response.isEmpty) {
      return null;
    }
    
    return Contact.fromJson(response[0]);
  }
}
