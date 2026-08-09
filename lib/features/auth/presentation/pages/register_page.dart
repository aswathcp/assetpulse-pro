import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/animated_gradient_background.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/widgets/pulse_loading.dart';
import '../../../../core/services/hierarchy_service.dart'; // NEW
import '../../../../core/constants/app_roles.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _employeeIdController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _selectedBusiness;
  String? _selectedPlant;
  String? _selectedUnit;
  String? _selectedRole;
  String? _selectedDepartment;
  
  List<String> _plants = [];
  List<String> _units = [];
  
  bool _isLoading = false;
  bool _isInitLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      _selectedBusiness = HierarchyService().currentBusinessId;
      await HierarchyService().refresh(businessId: _selectedBusiness);
      _plants = HierarchyService().getPlants();
    } catch (e) {
      debugPrint('Error loading initial registration data: $e');
    } finally {
      if (mounted) setState(() => _isInitLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _employeeIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      debugPrint('DEBUG: Starting Registration Flow...');
      try {
        final authService = AuthService();
        final firestoreService = FirestoreService();

        // 1. Create Auth User
        debugPrint('DEBUG: Attempting to create Auth User...');
        final userCredential = await authService.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        debugPrint('DEBUG: Auth User Created. UID: ${userCredential?.user?.uid}');

        if (userCredential?.user != null) {
          // 2. Save Profile
          debugPrint('DEBUG: Attempting to save User Profile to Firestore...');
          await firestoreService.saveUserProfile(
            user: userCredential!.user!,
            name: _nameController.text.trim(),
            employeeId: _employeeIdController.text.trim(),
            role: _selectedRole ?? 'Guest',
            department: _selectedDepartment ?? 'Unknown', // NEW
            businessId: _selectedBusiness ?? 'Unknown', // NEW
            unit: _selectedUnit ?? 'Unknown',
            plant: _selectedPlant ?? 'Unknown',
          );
          debugPrint('DEBUG: User Profile Saved Successfully.');
          
            if (mounted) {
               ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Registration Successful! Please wait for Admin approval to login.'),
                  backgroundColor: AppColors.success,
                  duration: Duration(seconds: 4),
                ),
              );
              // Force logout so AuthStream doesn't push them to Home Page
              await AuthService().signOut();
              // Navigate back to Login Page
              if (mounted) Navigator.of(context).pop(); 
            }
        }
      } catch (e) {
        debugPrint('DEBUG: Registration Error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString()),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isInitLoading 
        ? const Center(child: PulseLoading(size: 60))
        : AnimatedGradientBackground(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  Text(
                    'Create Account',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                  ).animate().fadeIn().slideY(begin: -0.2),
                  const SizedBox(height: 32),
                  GlassContainer(
                    width: double.infinity,
                    height: 760, 
                    borderRadius: 24,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                            TextFormField(
                              controller: _nameController,
                              validator: (v) => v!.isEmpty ? 'Required' : null,
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                              decoration: InputDecoration(
                                hintText: 'Name (Full Name)',
                                hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)),
                                prefixIcon: Icon(Icons.person_outline, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24))),
                              ),
                            ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _emailController,
                            validator: (v) => v!.contains('@') ? null : 'Invalid Email',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                            decoration: InputDecoration(
                              hintText: 'Email ID',
                              hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)),
                              prefixIcon: Icon(Icons.email_outlined, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24))),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _employeeIdController,
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                            decoration: InputDecoration(
                              hintText: 'Employee ID',
                              hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)),
                              prefixIcon: Icon(Icons.badge_outlined, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24))),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // --- PLANT DROPDOWN ---
                          DropdownButtonFormField<String>(
                            dropdownColor: Theme.of(context).colorScheme.surface,
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                            decoration: InputDecoration(
                              hintText: 'Select Plant', 
                              hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)),
                              prefixIcon: Icon(Icons.factory_outlined, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24))),
                            ),
                            initialValue: _selectedPlant,
                            items: _plants
                                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                .toList(),
                            onChanged: (v) {
                                setState(() {
                                  _selectedPlant = v;
                                  _selectedUnit = null; 
                                  _units = v != null ? HierarchyService().getUnitsForPlant(v) : [];
                                });
                            },
                          ),
                          if (_selectedPlant != null && _units.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              dropdownColor: Theme.of(context).colorScheme.surface,
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                              decoration: InputDecoration(
                                hintText: 'Select Unit / Shop',
                                hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)),
                                prefixIcon: Icon(Icons.settings_input_component, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24))),
                              ),
                              initialValue: _selectedUnit,
                              items: _units
                                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                  .toList(),
                              onChanged: (v) => setState(() => _selectedUnit = v),
                            ),
                          ],
                          const SizedBox(height: 16),
                            // --- DEPARTMENT DROPDOWN ---
                            DropdownButtonFormField<String>(
                              dropdownColor: Theme.of(context).colorScheme.surface,
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                              decoration: InputDecoration(
                                hintText: 'Select Department',
                                hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)),
                                prefixIcon: Icon(Icons.category_outlined, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24))),
                              ),
                              items: ['Electrical', 'Mechanical', 'Operations', 'Instrumentation', 'Safety', 'Other']
                                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                  .toList(),
                              onChanged: (v) => setState(() => _selectedDepartment = v),
                              validator: (v) => v == null ? 'Required' : null,
                            ),
                            const SizedBox(height: 16),

                            DropdownButtonFormField<String>(
                              dropdownColor: Theme.of(context).colorScheme.surface,
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                              decoration: InputDecoration(
                                hintText: 'Select Role',
                                hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)),
                                prefixIcon: Icon(Icons.work_outline, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24))),
                              ),
                              items: AppRoles.registrationRoles
                                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                  .toList(),
                              onChanged: (v) => setState(() => _selectedRole = v),
                            ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            validator: (v) => v!.length < 6 ? 'Min 6 chars' : null,
                            obscureText: true,
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                            decoration: InputDecoration(
                              hintText: 'Password',
                              hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)),
                              prefixIcon: Icon(Icons.lock_outline, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24))),
                            ),
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleRegister,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryLight,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _isLoading 
                                ? const PulseLoading(size: 24, color: Colors.white)
                                : const Text('Register', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
