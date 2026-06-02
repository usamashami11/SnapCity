import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models.dart';
import '../backend_contract.dart';
import '../snapcity_theme.dart';
import '../widgets.dart';
import '../services/api_service.dart';
import 'god_mode_viewer.dart';

class RewardScreen extends StatefulWidget {
  const RewardScreen({
    super.key,
    required this.onHome,
    required this.onCase,
    this.response,
  });

  final VoidCallback onHome;
  final VoidCallback onCase;
  final AgentReportResponse? response;

  @override
  State<RewardScreen> createState() => _RewardScreenState();
}

class _RewardScreenState extends State<RewardScreen> {
  void _showDeveloperLogin() {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isLoading = false;
    String? errorMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF10091E),
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              Future<void> login() async {
                setModalState(() {
                  isLoading = true;
                  errorMessage = null;
                });

                final email = emailController.text.trim();
                final password = passwordController.text.trim();

                try {
                  String url =
                      '${ApiService.activeBaseUrl}/api/v1/godmode/auth';
                  final response = await http
                      .post(
                        Uri.parse(url),
                        headers: {'Content-Type': 'application/json'},
                        body:
                            jsonEncode({'email': email, 'password': password}),
                      )
                      .timeout(const Duration(seconds: 30));

                  if (response.statusCode == 200) {
                    final data = jsonDecode(response.body);
                    final token = data['token'] ?? 'mock_jwt_token_123';

                    if (context.mounted) {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => GodModeLogViewerScreen(token: token),
                        ),
                      );
                    }
                  } else {
                    setModalState(() {
                      errorMessage = 'Invalid Credentials or Unauthorized';
                    });
                  }
                } catch (e) {
                  setModalState(() {
                    errorMessage =
                        'Connection failed. Ensure backend is running.';
                  });
                } finally {
                  if (context.mounted) {
                    setModalState(() {
                      isLoading = false;
                    });
                  }
                }
              }

              return Container(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Admin Login',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter credentials to access God Mode logs.',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: emailController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Email',
                        labelStyle: const TextStyle(color: Colors.white60),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle: const TextStyle(color: Colors.white60),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white),
                        ),
                      ),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: isLoading ? null : login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Login'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.response?.points ?? 40;
    final message = widget.response?.rewardMessage ??
        'Your snap increased this case by 12%.\nThis issue is now eligible for escalation.';

    return Stack(
      children: [
        Positioned.fill(
            child: Image.asset('assets/pothole-camera.png', fit: BoxFit.cover)),
        Positioned.fill(
            child: ColoredBox(color: Colors.black.withOpacity(.32))),
        Center(
          child: AppCard(
            margin: const EdgeInsets.all(22),
            padding: const EdgeInsets.all(20),
            radius: 18,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 62,
                    height: 62,
                    decoration: const BoxDecoration(
                        color: SnapColors.yellow, shape: BoxShape.circle),
                    child: const Icon(Icons.auto_awesome_rounded, size: 28)),
                const SizedBox(height: 16),
                const Text('Case Strengthened!',
                    style:
                        TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('+$points Civic Impact Points',
                    style: const TextStyle(
                        fontSize: 17,
                        color: SnapColors.purple,
                        fontWeight: FontWeight.w800)),
                Text(message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13, color: SnapColors.muted, height: 1.45)),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 120),
                  child: Image.asset('assets/Reward2.gif', height: 120, fit: BoxFit.contain),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F2),
                      borderRadius: BorderRadius.circular(18)),
                  child: Column(
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Evidence Strength',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w800)),
                          Text('72% -> 84%',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: SnapColors.success,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                          value: .84,
                          minHeight: 10,
                          color: SnapColors.success,
                          backgroundColor: Colors.white,
                          borderRadius: BorderRadius.circular(999)),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                    onPressed: widget.onHome,
                    style: FilledButton.styleFrom(
                        backgroundColor: SnapColors.purple,
                        minimumSize: const Size.fromHeight(50)),
                    child: const Text('Back to Home')),
                const SizedBox(height: 10),
                OutlinedButton(
                    onPressed: widget.onCase,
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48)),
                    child: const Text('View Case')),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _showDeveloperLogin,
                  child: const Text(
                    'Tap to view AI Swarm Logs',
                    style: TextStyle(
                      color: SnapColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
