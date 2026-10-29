import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../models/server_profile.dart';
import '../providers/auth_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  final VoidCallback? onCompleted;
  final ServerProfile? initialProfile;

  const OnboardingScreen({
    super.key,
    this.onCompleted,
    this.initialProfile,
  });

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _primaryHostController;
  late TextEditingController _secondaryHostController;
  late TextEditingController _apiKeyController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;

  AuthType _authType = AuthType.apiKey;
  bool _allowSelfSigned = true;
  bool _obscurePassword = true;
  bool _isTesting = false;
  String? _testResult;
  bool _testSuccess = false;

  @override
  void initState() {
    super.initState();
    final p = widget.initialProfile;
    _nameController = TextEditingController(text: p?.name ?? 'Home TrueNAS');
    _primaryHostController = TextEditingController(text: p?.primaryHost ?? 'https://192.168.1.11');
    _secondaryHostController = TextEditingController(text: p?.secondaryHost ?? '');
    _authType = p?.authType ?? AuthType.apiKey;
    _apiKeyController = TextEditingController(text: p?.apiKey ?? '');
    _usernameController = TextEditingController(text: p?.username ?? '');
    _passwordController = TextEditingController(text: p?.password ?? '');
    _allowSelfSigned = p?.allowSelfSigned ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _primaryHostController.dispose();
    _secondaryHostController.dispose();
    _apiKeyController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  ServerProfile _buildProfile() {
    return ServerProfile(
      id: widget.initialProfile?.id ?? 'server_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : 'TrueNAS SCALE',
      primaryHost: _primaryHostController.text.trim(),
      secondaryHost: _secondaryHostController.text.trim().isNotEmpty ? _secondaryHostController.text.trim() : null,
      authType: _authType,
      apiKey: _authType == AuthType.apiKey ? _apiKeyController.text.trim() : null,
      username: _usernameController.text.trim().isNotEmpty ? _usernameController.text.trim() : null,
      password: _passwordController.text.isNotEmpty ? _passwordController.text : null,
      allowSelfSigned: _allowSelfSigned,
      activeRoute: widget.initialProfile?.activeRoute ?? ActiveRoute.lan,
    );
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final profile = _buildProfile();
    final ok = await ref.read(authStateProvider.notifier).testConnection(profile);

    setState(() {
      _isTesting = false;
      _testSuccess = ok;
      _testResult = ok
          ? 'Connected successfully to TrueNAS SCALE!'
          : 'Failed to connect. Please check the Host URL, SSL cert, and API Key.';
    });
  }

  Future<void> _saveAndConnect() async {
    if (!_formKey.currentState!.validate()) return;

    final profile = _buildProfile();
    await ref.read(authStateProvider.notifier).saveProfile(profile);

    if (mounted) {
      if (widget.onCompleted != null) {
        widget.onCompleted!();
      } else {
        Navigator.of(context).maybePop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialProfile != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Server Configuration' : 'Setup TrueNAS Server'),
        leading: isEditing ? const BackButton() : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isEditing) ...[
                  const Row(
                    children: [
                      Icon(Icons.dns_rounded, size: 32, color: AppColors.primary),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome to NAS Dash',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Configure your TrueNAS SCALE instance to get started',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],

                // 1. Host Info Section
                Text(
                  'Server Connection',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Server Name',
                    hintText: 'e.g. Home TrueNAS',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Server name is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _primaryHostController,
                  decoration: const InputDecoration(
                    labelText: 'Primary Host URL (LAN)',
                    hintText: 'https://192.168.1.11',
                    prefixIcon: Icon(Icons.lan_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Primary Host URL is required';
                    if (!v.contains('.')) return 'Enter a valid IP or hostname';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _secondaryHostController,
                  decoration: const InputDecoration(
                    labelText: 'Secondary Host / VPN (Optional)',
                    hintText: 'e.g. https://100.102.141.91 (NetBird/Tailscale)',
                    prefixIcon: Icon(Icons.vpn_lock_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _allowSelfSigned,
                  onChanged: (val) => setState(() => _allowSelfSigned = val),
                  title: const Text('Allow Self-Signed TLS Certificates', style: TextStyle(fontSize: 13)),
                  subtitle: const Text('Required for typical home-lab HTTPS setups', style: TextStyle(fontSize: 11)),
                ),
                const SizedBox(height: 20),

                // 2. Authentication Section
                Text(
                  'Authentication',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('API Key (Recommended)'),
                      selected: _authType == AuthType.apiKey,
                      onSelected: (sel) {
                        if (sel) setState(() => _authType = AuthType.apiKey);
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Username & Password'),
                      selected: _authType == AuthType.credentials,
                      onSelected: (sel) {
                        if (sel) setState(() => _authType = AuthType.credentials);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_authType == AuthType.apiKey) ...[
                  TextFormField(
                    controller: _apiKeyController,
                    decoration: const InputDecoration(
                      labelText: 'TrueNAS API Key',
                      hintText: 'Generate from TrueNAS WebUI > User > API Keys',
                      prefixIcon: Icon(Icons.key_outlined),
                    ),
                    validator: (v) {
                      if (_authType == AuthType.apiKey && (v == null || v.trim().isEmpty)) {
                        return 'API Key is required';
                      }
                      return null;
                    },
                  ),
                ] else ...[
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'TrueNAS Username',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) => _authType == AuthType.credentials && (v == null || v.trim().isEmpty) ? 'Username is required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'TrueNAS Password',
                      prefixIcon: const Icon(Icons.password_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) => _authType == AuthType.credentials && (v == null || v.isEmpty) ? 'Password is required' : null,
                  ),
                ],
                const SizedBox(height: 20),

                // 3. Test Result Alert Banner
                if (_testResult != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _testSuccess ? AppColors.healthy.withValues(alpha: 0.15) : AppColors.critical.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _testSuccess ? AppColors.healthy : AppColors.critical),
                    ),
                    child: Row(
                      children: [
                        Icon(_testSuccess ? Icons.check_circle : Icons.error_outline, color: _testSuccess ? AppColors.healthy : AppColors.critical),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(_testResult!, style: TextStyle(fontSize: 12, color: _testSuccess ? AppColors.healthy : AppColors.critical)),
                        ),
                      ],
                    ),
                  ),

                // 5. Actions: Test & Connect
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isTesting ? null : _testConnection,
                        icon: _isTesting
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.network_check),
                        label: const Text('Test Connection'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _saveAndConnect,
                        icon: const Icon(Icons.check),
                        label: Text(isEditing ? 'Save Changes' : 'Connect & Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
