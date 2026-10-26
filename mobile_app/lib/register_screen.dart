import 'package:flutter/material.dart';
import 'auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() =>
      _RegisterScreenState();
}

class _RegisterScreenState
    extends State<RegisterScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  String selectedRole = 'USER';
  bool loading = false;
  bool obscurePassword = true;

  Future<void> register() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty) {
      showMessage('Please fill all fields');
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      await AuthService.register(
        name,
        email,
        password,
        selectedRole,
      );

      if (!mounted) return;

      showMessage(
        'Registration successful. Please login.',
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      showMessage(
        e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(
              Icons.person_add,
              size: 70,
              color: Colors.indigo,
            ),

            const SizedBox(height: 20),

            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: emailController,
              keyboardType:
                  TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: passwordController,
              obscureText: obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon:
                    const Icon(Icons.lock),
                border:
                    const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      obscurePassword =
                          !obscurePassword;
                    });
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: selectedRole,
              decoration:
                  const InputDecoration(
                labelText: 'Role',
                prefixIcon:
                    Icon(Icons.badge),
                border:
                    OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'USER',
                  child: Text('User'),
                ),
                DropdownMenuItem(
                  value: 'ADMIN',
                  child: Text('Admin'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    selectedRole = value;
                  });
                }
              },
            ),

            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    loading ? null : register,
                style:
                    ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.all(16),
                ),
                child: loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'REGISTER',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}