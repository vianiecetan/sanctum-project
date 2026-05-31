import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart'; // Add this
import 'dart:convert';

class RitualsScreen extends StatefulWidget {
  const RitualsScreen({super.key});

  @override
  State<RitualsScreen> createState() => _RitualsScreenState();
}

class _RitualTask {
  final String title;
  final String description;
  final int reward;
  final IconData icon;
  bool isCompleted;

  _RitualTask({
    required this.title,
    required this.description,
    required this.reward,
    required this.icon,
    this.isCompleted = false, // Default to false
  });
}

class _RitualsScreenState extends State<RitualsScreen> {
  int _insightShards = 0; // Initialize at 0
  bool _quoteDecoded = false;
  bool _isLoading = true;
  String _dailyTransmission = "Establishing secure connection...";

  final List<_RitualTask> _rituals = [
    _RitualTask(
      title: 'COGNITIVE OVERRIDE',
      description: 'Break the autopilot. Solve today’s Sanctum Riddle to earn shards.',
      reward: 50,
      icon: Icons.extension,
    ),
    _RitualTask(
      title: 'THE DIGITAL FAST',
      description: 'Defeat the doomscroll. Leave the Sanctum for 60 minutes.',
      reward: 100,
      icon: Icons.timer_off_outlined,
    ),
    _RitualTask(
      title: 'THE AUDIT',
      description: 'Face the Terminal. Log an emotion and attempt a reframe.',
      reward: 30,
      icon: Icons.terminal,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeRituals();
  }

  Future<void> _initializeRituals() async {
    await _fetchUserStats();
    await _fetchRandomTransmission();
    setState(() => _isLoading = false);
  }

  // Fetch real shards and check for daily reset
  Future<void> _fetchUserStats() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final data = await Supabase.instance.client
          .from('player_profiles')
          .select('insight_shards, last_ritual_date')
          .eq('user_id', user.id)
          .maybeSingle(); // Use maybeSingle to prevent crashes

      if (data == null) {
        // Create the profile if it doesn't exist
        await Supabase.instance.client.from('player_profiles').insert({
          'user_id': user.id,
          'insight_shards': 200, // Starting shards
        });
        setState(() => _insightShards = 200);
      } else {
        setState(() {
          _insightShards = data['insight_shards'] ?? 0;
          final String? lastDateStr = data['last_ritual_date'];
          final today = DateTime.now().toIso8601String().split('T')[0];

          if (lastDateStr == today) {
            for (var ritual in _rituals) {
              ritual.isCompleted = true;
            }
          }
        });
      }
    } catch (e) {
      debugPrint("Rituals Error: $e");
      // Force loading to stop even if there is an error
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchRandomTransmission() async {
    try {
      final response = await http.get(Uri.parse('http://10.0.2.2:3000/api/daily-transmission'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => _dailyTransmission = data['message']);
      }
    } catch (e) {
      setState(() => _dailyTransmission = "Signal lost. The Sanctum remains quiet.");
    }
  }

  void _claimReward(int index) {
    if (_rituals[index].title == 'COGNITIVE OVERRIDE') {
      _showRiddleDialog(index);
      return;
    }
    _grantShards(index);
  }

  Future<void> _grantShards(int index) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final today = DateTime.now().toIso8601String().split('T')[0];

    try {
      // Update Database
      await Supabase.instance.client.from('player_profiles').update({
        'insight_shards': _insightShards + _rituals[index].reward,
        'last_ritual_date': today, // Mark today as completed
      }).eq('user_id', user.id);

      setState(() {
        _rituals[index].isCompleted = true;
        _insightShards += _rituals[index].reward;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('+${_rituals[index].reward} Shards synced with Neural Link.',
              style: const TextStyle(fontFamily: 'monospace')),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    } catch (e) {
      print("Error syncing rewards: $e");
    }
  }

  void _showRiddleDialog(int index) {
    final TextEditingController answerController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B4B),
        title: const Text('SYSTEM CHECK: SPEED BUMP',
            style: TextStyle(fontFamily: 'monospace', color: Colors.white, fontSize: 14)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('I have keys but open no doors. I have space but no room. What am I?',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 20),
            TextField(
              controller: answerController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(hintText: 'Enter solution...', hintStyle: TextStyle(color: Colors.white24)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ABORT')),
          ElevatedButton(
            onPressed: () {
              if (answerController.text.toLowerCase().contains('keyboard')) {
                Navigator.pop(context);
                _grantShards(index);
              }
            },
            child: const Text('SUBMIT'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0710),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(primaryColor),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildTransmissionCard(primaryColor),
                        const SizedBox(height: 32),
                        const Text('DAILY PROTOCOLS', style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.white54)),
                        const SizedBox(height: 16),
                        ...List.generate(_rituals.length, (index) => _buildRitualCard(_rituals[index], index, primaryColor)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Sub-widgets extracted for cleanliness ---
  Widget _buildBackground() {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(center: Alignment(0.8, -0.5), radius: 1.5, colors: [Color(0xFF2E1065), Color(0xFF0A0710)]),
        ),
      ),
    );
  }

  Widget _buildHeader(Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white54), onPressed: () => Navigator.pop(context)),
          Row(children: [
            Icon(Icons.diamond_outlined, color: primaryColor, size: 18),
            const SizedBox(width: 8),
            Text('$_insightShards SHARDS', style: const TextStyle(fontFamily: 'monospace', color: Colors.white)),
          ]),
        ],
      ),
    );
  }

  Widget _buildTransmissionCard(Color primaryColor) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            border: Border.all(color: primaryColor.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.satellite_alt, color: primaryColor, size: 16),
                const SizedBox(width: 8),
                const Text('ENCRYPTED TRANSMISSION', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.white54)),
              ]),
              const SizedBox(height: 16),
              AnimatedCrossFade(
                firstChild: GestureDetector(
                  onTap: () => setState(() => _quoteDecoded = true),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(8)),
                    child: const Center(child: Text('TAP TO DECODE', style: TextStyle(fontFamily: 'monospace', color: Colors.white54))),
                  ),
                ),
                secondChild: Text('"$_dailyTransmission"', style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.white)),
                crossFadeState: _quoteDecoded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRitualCard(_RitualTask task, int index, Color primaryColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(task.isCompleted ? 0.02 : 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(task.icon, color: task.isCompleted ? Colors.white24 : primaryColor),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.title, style: TextStyle(fontFamily: 'monospace', color: task.isCompleted ? Colors.white24 : Colors.white)),
                Text(task.description, style: TextStyle(fontSize: 11, color: task.isCompleted ? Colors.white10 : Colors.white60)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: task.isCompleted ? null : () => _claimReward(index),
            child: Text(task.isCompleted ? 'DONE' : '+${task.reward}'),
          ),
        ],
      ),
    );
  }
}