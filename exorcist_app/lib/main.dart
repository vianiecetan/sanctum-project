import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:supabase_flutter/supabase_flutter.dart'; // Add this import
import 'sanctum_screen.dart';
// Make main() asynchronous
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://rdfynlytunmdhnxkimwf.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJkZnlubHl0dW5tZGhueGtpbXdmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NTg3NzAyMSwiZXhwIjoyMDkxNDUzMDIxfQ.N_2G5Idd5cdYw8J6KKvit2gG9wOs6gYi0gIK1XitOuw',
  );

  runApp(const ExorcistApp());
}

class ExorcistApp extends StatelessWidget {
  const ExorcistApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Check if Supabase already has a saved session in the device's memory
    final session = Supabase.instance.client.auth.currentSession;

    return MaterialApp(
      title: 'Exorcist: Inner Sanctum',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0710),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFA855F7),
          secondary: Color(0xFF8B5CF6),
        ),
      ),
      // 2. The Magic Route: If a session exists, skip login. If not, show the Welcome screen.
      home: session != null ? const SanctumScreen() : const WelcomeScreen(),
    );
  }
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  // Toggle between 'intro' and 'auth' views
  bool showAuth = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Atmospheric Background Gradients
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.6, -0.8),
                  radius: 1.5,
                  colors: [
                    Color(0xFF2E1065), // Faded purple highlight
                    Color(0xFF0A0710), // Base background
                  ],
                ),
              ),
            ),
          ),

          // 2. Main Content with smooth transition
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: showAuth
                        ? AuthView(onBack: () => setState(() => showAuth = false))
                        : IntroView(onBegin: () => setState(() => showAuth = true)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- INTRO VIEW --- //

class IntroView extends StatelessWidget {
  final VoidCallback onBegin;

  const IntroView({super.key, required this.onBegin});

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('IntroView'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Glowing Shield Logo
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                blurRadius: 30,
                spreadRadius: 5,
              )
            ],
          ),
          child: Icon(
            Icons.shield_outlined,
            size: 40,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 24),

        // Titles
        const Text(
          'SANCTUM PROTOCOL · v1.0',
          style: TextStyle(fontFamily: 'monospace', fontSize: 10, letterSpacing: 3, color: Colors.white54),
        ),
        const SizedBox(height: 8),
        const Text(
          'EXORCIST',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        const SizedBox(height: 4),
        Text(
          'THE INNER SANCTUM',
          style: TextStyle(fontFamily: 'monospace', fontSize: 12, letterSpacing: 4, color: Theme.of(context).colorScheme.primary.withOpacity(0.8)),
        ),
        const SizedBox(height: 24),

        // Description
        const Text(
          'A gamified ritual for the digital age. Reclaim your mind from the endless scroll. Banish the entities. Grow.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.white70, height: 1.5),
        ),
        const SizedBox(height: 32),

        // Features List
        const FeatureCard(
          icon: Icons.shield_outlined,
          title: 'Slay Your Mind Monsters',
          desc: 'Reframe negative thoughts in your Sanctum and watch the corruption fade.',
        ),
        const SizedBox(height: 12),
        const FeatureCard(
          icon: Icons.auto_awesome,
          title: 'Level Up Your Mind',
          desc: 'Earn XP, conquer feelings, and build your Bestiary of victories.',
        ),
        const SizedBox(height: 12),
        const FeatureCard(
          icon: Icons.person_outline,
          title: 'Join a Guild',
          desc: 'Befriend fellow exorcists and grow stronger together.',
        ),
        const SizedBox(height: 32),

        // Begin Button
        NeonButton(
          text: 'BEGIN THE RITUAL',
          icon: Icons.chevron_right,
          onPressed: onBegin,
        ),

        const SizedBox(height: 24),
        const Text(
          '⌬ A safe space. Not a replacement for therapy.',
          style: TextStyle(fontFamily: 'monospace', fontSize: 10, letterSpacing: 1.5, color: Colors.white38),
        ),
      ],
    );
  }
}

// --- AUTHENTICATION VIEW --- //

class AuthView extends StatefulWidget {
  final VoidCallback onBack;
  const AuthView({super.key, required this.onBack});

  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> {
  bool isSignIn = true;
  bool obscurePassword = true;
  bool isLoading = false; // Add loading state

  // Add text controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _codenameController = TextEditingController(); // For sign up

  // Get the Supabase client
  final supabase = Supabase.instance.client;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _codenameController.dispose();
    super.dispose();
  }

  // --- AUTHENTICATION LOGIC ---

  Future<void> handleAuth() async {
    setState(() => isLoading = true);

    try {
      if (isSignIn) {
        // Log in existing user
        await supabase.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Welcome back to the Sanctum.')),
        );

        // Navigate to the Game Page!
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const SanctumScreen()),
        );
      } else {
        // Create new user
        await supabase.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          data: {'codename': _codenameController.text.trim()}, // Save codename in user metadata
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sigil forged. Check your email to verify.')),
        );
      }
    } on AuthException catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message), backgroundColor: Colors.red),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An unexpected error occurred.'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('AuthView'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Back Button & Header
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back, size: 14, color: Colors.white54),
            label: const Text(
              'BACK',
              style: TextStyle(fontFamily: 'monospace', fontSize: 10, letterSpacing: 2, color: Colors.white54),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(Icons.shield_outlined, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            const Text(
              'EXORCIST',
              style: TextStyle(fontFamily: 'monospace', fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Custom Tabs
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => isSignIn = true),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSignIn ? Theme.of(context).colorScheme.primary.withOpacity(0.2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'SIGN IN',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        letterSpacing: 2,
                        color: isSignIn ? Theme.of(context).colorScheme.primary : Colors.white54,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => isSignIn = false),
                  child: Container(
                    decoration: BoxDecoration(
                      color: !isSignIn ? Theme.of(context).colorScheme.primary.withOpacity(0.2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'CREATE',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        letterSpacing: 2,
                        color: !isSignIn ? Theme.of(context).colorScheme.primary : Colors.white54,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Forms (Animated transition between sign in and create)
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!isSignIn) ...[
                AuthTextField(
                  label: 'CODENAME',
                  icon: Icons.person_outline,
                  placeholder: 'Choose your alias',
                  controller: _codenameController, // <--- ADDED CONTROLLER
                ),
                const SizedBox(height: 16),
              ],
              AuthTextField(
                label: 'EMAIL',
                icon: Icons.mail_outline,
                placeholder: 'exorcist@sanctum.io',
                controller: _emailController, // <--- ADDED CONTROLLER
              ),
              const SizedBox(height: 16),
              AuthTextField(
                label: 'PASSWORD',
                icon: Icons.lock_outline,
                placeholder: '••••••••',
                isPassword: true,
                obscureText: obscurePassword,
                controller: _passwordController, // <--- ADDED CONTROLLER
                onTogglePassword: () => setState(() => obscurePassword = !obscurePassword),
              ),
              const SizedBox(height: 16),

              if (isSignIn)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () {},
                    child: Text(
                      'FORGOT PASSWORD?',
                      style: TextStyle(fontFamily: 'monospace', fontSize: 10, letterSpacing: 1.5, color: Theme.of(context).colorScheme.primary.withOpacity(0.8)),
                    ),
                  ),
                ),

              if (!isSignIn)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    'By summoning your sigil, you accept the Pact & Privacy Rites.',
                    style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.white54, height: 1.5),
                  ),
                ),

              // <--- ADDED LOADING STATE AND CONNECTED handleAuth
              isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFA855F7)))
                  : NeonButton(
                text: isSignIn ? 'ENTER THE SANCTUM' : 'FORGE YOUR SIGIL',
                onPressed: handleAuth, // <--- CONNECTED TO YOUR FUNCTION
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Dividers & Social
        Row(
          children: [
            Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('OR CONTINUE WITH', style: TextStyle(fontFamily: 'monospace', fontSize: 9, letterSpacing: 2, color: Colors.white54)),
            ),
            Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
          ],
        ),
        const SizedBox(height: 24),

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.g_mobiledata, color: Colors.white),
                label: const Text('Google', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withOpacity(0.2)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.code, color: Colors.white), // Placeholder for Github
                label: const Text('GitHub', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withOpacity(0.2)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 32),
        Center(
          child: TextButton(
            onPressed: () {},
            child: const Text(
              'ENTER AS GHOST (GUEST) →',
              style: TextStyle(fontFamily: 'monospace', fontSize: 10, letterSpacing: 2, color: Colors.white54),
            ),
          ),
        ),
      ],
    );
  }
}

// --- REUSABLE COMPONENTS --- //

class FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;

  const FeatureCard({super.key, required this.icon, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
                ),
                child: Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Text(desc, style: const TextStyle(fontSize: 12, color: Colors.white60, height: 1.4)),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class AuthTextField extends StatelessWidget {
  final String label;
  final IconData icon;
  final String placeholder;
  final bool isPassword;
  final bool obscureText;
  final VoidCallback? onTogglePassword;
  final TextEditingController? controller; // <--- ADDED

  const AuthTextField({
    super.key,
    required this.label,
    required this.icon,
    required this.placeholder,
    this.isPassword = false,
    this.obscureText = false,
    this.onTogglePassword,
    this.controller, // <--- ADDED
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, letterSpacing: 2, color: Colors.white54)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: TextField(
              controller: controller, // <--- ADDED TO TEXTFIELD
              obscureText: obscureText,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
              decoration: InputDecoration(
                hintText: placeholder,
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                prefixIcon: Icon(icon, color: Colors.white54, size: 18),
                suffixIcon: isPassword
                    ? IconButton(
                  icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility, color: Colors.white54, size: 18),
                  onPressed: onTogglePassword,
                )
                    : null,
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class NeonButton extends StatelessWidget {
  final String text;
  final IconData? icon;
  final VoidCallback onPressed;

  const NeonButton({super.key, required this.text, this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(text, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
            if (icon != null) ...[
              const SizedBox(width: 8),
              Icon(icon, size: 16),
            ]
          ],
        ),
      ),
    );
  }
}