import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:supabase_flutter/supabase_flutter.dart';

class BestiaryScreen extends StatefulWidget {
  const BestiaryScreen({super.key});

  @override
  State<BestiaryScreen> createState() => _BestiaryScreenState();
}

class _BestiaryScreenState extends State<BestiaryScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _defeatedEntities = [];

  @override
  void initState() {
    super.initState();
    _fetchDefeatedEntities();
  }

  Future<void> _fetchDefeatedEntities() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final response = await Supabase.instance.client
          .from('user_encounters')
          .select('*, monsters_dictionary(name, asset_url)') // <--- FIXED
          .eq('user_id', user.id)
          .eq('status', 'defeated')
          .order('updated_at', ascending: false); // Most recent kills first

      if (mounted) {
        setState(() {
          _defeatedEntities = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Archive Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0710),
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                const Text(
                  'NEURAL ARCHIVES',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2),
                ),
                const SizedBox(height: 10),
                const Text(
                  'A history of anomalies you have successfully dismantled.',
                  style: TextStyle(fontSize: 12, color: Colors.white54),
                ),
                const SizedBox(height: 30),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
                      : _defeatedEntities.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    itemCount: _defeatedEntities.length,
                    itemBuilder: (context, index) => _buildTrophyCard(_defeatedEntities[index], primaryColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrophyCard(Map<String, dynamic> encounter, Color primaryColor) {
    final visualData = encounter['monsters_dictionary'];
    final String originalThought = encounter['original_thought'] ?? 'Unknown Anomaly';
    final String rawReframes = encounter['reframe_used'] ?? 'No data recovered.';

    // Split the hidden delimiter to get a list of all attempts
    final List<String> reframeAttempts = rawReframes.split('||');

    // Format the date
    final DateTime defeatDate = DateTime.parse(encounter['updated_at']).toLocal();
    final String formattedDate = "${defeatDate.year}-${defeatDate.month.toString().padLeft(2, '0')}-${defeatDate.day.toString().padLeft(2, '0')}";

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- CARD HEADER (Date & Monster Name) ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.military_tech, color: primaryColor, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          (visualData?['name'] ?? 'UNKNOWN ENTITY').toString().toUpperCase(),
                          style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1),
                        ),
                      ],
                    ),
                    Text(
                      formattedDate,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.white54),
                    ),
                  ],
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(color: Colors.white10, height: 1),
                ),

                // --- INFECTED THOUGHT ---
                const Text('INFECTED THOUGHT:', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.redAccent, letterSpacing: 1)),
                const SizedBox(height: 8),
                Text(
                  '"$originalThought"',
                  style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.white70, fontSize: 14),
                ),

                const SizedBox(height: 24),

                // --- THE STRIKES (Reframes) ---
                const Text('COGNITIVE STRIKES LOGGED:', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.cyanAccent, letterSpacing: 1)),
                const SizedBox(height: 12),

                // Generate a row for every single reframe attempt
                ...List.generate(reframeAttempts.length, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('0${index + 1}.', style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: primaryColor)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            reframeAttempts[index],
                            style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, color: Colors.white.withOpacity(0.2), size: 60),
          const SizedBox(height: 20),
          const Text('ARCHIVES EMPTY', style: TextStyle(fontFamily: 'monospace', color: Colors.white54, letterSpacing: 2)),
          const SizedBox(height: 8),
          const Text('No entities have been fully dismantled yet.', style: TextStyle(fontSize: 12, color: Colors.white38)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white54),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: NetworkImage('https://images.unsplash.com/photo-1550745165-9bc0b252726f?q=80&w=2070&auto=format&fit=crop'),
          fit: BoxFit.cover,
          opacity: 0.05,
        ),
      ),
    );
  }
}