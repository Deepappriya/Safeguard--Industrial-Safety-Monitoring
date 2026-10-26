
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState
    extends State<UserManagementScreen> {
  List<dynamic> users = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchUsers();
  }

  Future<void> fetchUsers() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final token = await AuthService.getToken();

      if (token == null) {
        throw Exception('Please log in again.');
      }

      final response = await http.get(
        Uri.parse('${AuthService.baseUrl}/admin/users'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          data['status'] == 'success') {
        if (!mounted) return;

        setState(() {
          users = data['users'] as List<dynamic>;
          isLoading = false;
        });
      } else {
        throw Exception(
          data['detail'] ?? 'Unable to load users.',
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          IconButton(
            onPressed: fetchUsers,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh users',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          errorMessage!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: fetchUsers,
                          child: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                )
              : users.isEmpty
                  ? const Center(
                      child: Text('No registered users found.'),
                    )
                  : RefreshIndicator(
                      onRefresh: fetchUsers,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Card(
                            child: ListTile(
                              leading: const Icon(
                                Icons.people,
                                size: 36,
                              ),
                              title: const Text(
                                'Registered Users',
                              ),
                              subtitle: const Text(
                                'Total accounts',
                              ),
                              trailing: Text(
                                '${users.length}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...users.map((user) {
                            final role =
                                user['role']?.toString() ?? 'USER';

                            return Card(
                              margin: const EdgeInsets.only(
                                bottom: 10,
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  child: Icon(
                                    role == 'ADMIN'
                                        ? Icons.admin_panel_settings
                                        : Icons.person,
                                  ),
                                ),
                                title: Text(
                                  user['name']?.toString() ??
                                      'Unknown',
                                ),
                                subtitle: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user['email']?.toString() ??
                                          '',
                                    ),
                                    const SizedBox(height: 4),
                                    Text('Role: $role'),
                                    Text(
                                      'Registered: ${user['created_at'] ?? 'Unknown'}',
                                    ),
                                  ],
                                ),
                                isThreeLine: true,
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
    );
  }
}
