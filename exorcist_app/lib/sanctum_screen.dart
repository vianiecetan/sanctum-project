import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'rituals_screen.dart';
import 'main.dart';
import 'store_screen.dart';
import 'bestiary_screen.dart';
import 'profile_analytics_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SanctumScreen extends StatefulWidget {
  const SanctumScreen({super.key});

  @override
  State<SanctumScreen> createState() => _SanctumScreenState();
}

class _SanctumScreenState extends State<SanctumScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _terminalController = TextEditingController();

  // Game State Variables
  bool _hasActiveMonster = false;
  List<Map<String, dynamic>> _activeEncounters = [];
  int _currentSwipeIndex = 0;
  List<Map<String, dynamic>> _monsterDictionary = [];

  // Player Stats for HUD
  int _playerLevel = 1;
  int _playerXP = 0;

  // --- INVENTORY STATE ---
  List<Map<String, dynamic>> _myItems = [];
  String? _activePowerUp; // Tracks what is currently "armed"

  // Map to convert DB names back to icons
  final Map<String, IconData> _iconMap = {
    'COGNITIVE SHIELD': Icons.security,
    'LOGIC BOMB': Icons.api_rounded,
    'CLARITY STIM': Icons.insights,
    'ECHO CANCELLER': Icons.settings_voice,
    'LOGIC GATE': Icons.architecture,
  };

  final PageController _pageController = PageController(viewportFraction: 0.75);
  late final AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    _fetchPlayerStats(); // Load HUD stats
    _fetchMonsters();
    _fetchActiveEncounters();
    _loadInventory(); // Load weapons

    _floatController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _terminalController.dispose();
    _floatController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // --- DATABASE LOGIC --- //

  Future<void> _fetchPlayerStats() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final data = await Supabase.instance.client
          .from('player_profiles')
          .select('experience_points')
          .eq('user_id', user.id)
          .maybeSingle();

      if (data != null && mounted) {
        setState(() {
          _playerXP = data['experience_points'] ?? 0;
          _playerLevel = (_playerXP / 1000).floor() + 1;
        });
      }
    } catch (e) {
      print('Stats Error: $e');
    }
  }

  Future<void> _loadInventory() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final data = await Supabase.instance.client
          .from('user_inventory')
          .select()
          .eq('user_id', user.id)
          .gt('quantity', 0); // Only fetch items you actually have

      if (mounted) {
        setState(() {
          _myItems = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      print('Inventory Load Error: $e');
    }
  }

  Future<void> _consumeItem(String itemName) async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final existing = await supabase.from('user_inventory')
          .select('quantity').eq('user_id', userId).eq('item_name', itemName).single();

      int newQty = existing['quantity'] - 1;

      if (newQty <= 0) {
        await supabase.from('user_inventory').delete()
            .eq('user_id', userId).eq('item_name', itemName);
      } else {
        await supabase.from('user_inventory').update({'quantity': newQty})
            .eq('user_id', userId).eq('item_name', itemName);
      }

      _loadInventory(); // Refresh the visual list
      setState(() => _activePowerUp = null); // Disarm after use
    } catch (e) {
      print('Error consuming item: $e');
    }
  }

  Future<void> _fetchMonsters() async {
    try {
      final response = await Supabase.instance.client.from('monsters_dictionary').select();
      setState(() => _monsterDictionary = List<Map<String, dynamic>>.from(response));
    } catch (error) {
      print('SANCTUM DATABASE ERROR: $error');
    }
  }

  Future<void> _fetchActiveEncounters() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final response = await Supabase.instance.client
          .from('user_encounters')
          .select('*, monsters_dictionary(name, asset_url)')
          .eq('user_id', userId)
          .eq('status', 'active')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _activeEncounters = List<Map<String, dynamic>>.from(response);
          _hasActiveMonster = _activeEncounters.isNotEmpty;
          _currentSwipeIndex = 0;
        });
      }
    } catch (e) {
      print('Error fetching encounters: $e');
    }
  }

  // --- COMBAT ENGINE --- //

  Future<void> _submitTerminal() async {
    final thought = _terminalController.text.trim();
    if (thought.isEmpty) return;

    _terminalController.clear();
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;

    if (userId == null) return;

    if (!_hasActiveMonster) {
      // --- SPAWN PHASE ---
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Analyzing entity signature...', style: TextStyle(fontFamily: 'monospace'))));

      try {
        final response = await http.post(
          Uri.parse('https://sanctum-api.vercel.app/api/analyze'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'rawThought': thought}),
        );

        if (response.statusCode == 200) {
          final result = jsonDecode(response.body)['data'];
          final String emotion = result['primary_emotion'];
          final int intensity = result['intensity'];

          final matchedMonster = _monsterDictionary.firstWhere(
                (monster) => monster['emotion_trigger'] == emotion,
            orElse: () => _monsterDictionary.first,
          );

          await supabase.from('user_encounters').insert({
            'user_id': userId,
            'monster_id': matchedMonster['id'],
            'original_thought': thought,
            'current_health': intensity,
            'status': 'active'
          });

          await _fetchActiveEncounters();
        }
      } catch (e) {
        print('Spawn Error: $e');
      }
    } else {
      // --- COMBAT / REFRAME PHASE ---
      if (_activeEncounters.isEmpty) return;

      final targetedEncounter = _activeEncounters[_currentSwipeIndex];
      final String encounterId = targetedEncounter['id'];
      final String originalThought = targetedEncounter['original_thought'];
      final int currentHealth = targetedEncounter['current_health'];

      final String existingReframes = targetedEncounter['reframe_used'] ?? '';
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Executing cognitive strike...', style: TextStyle(fontFamily: 'monospace'))));

      try {
        final response = await http.post(
          Uri.parse('https://sanctum-api.vercel.app/api/evaluate-reframe'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'originalThought': originalThought, 'reframeAttempt': thought}),
        );

        if (response.statusCode == 200) {
          final result = jsonDecode(response.body)['data'];
          final int baseDamage = result['damage_dealt'];
          String combatLog = result['combat_log']; // Made this mutable so we can append to it

          int finalDamage = baseDamage;

          // --- 1. INVENTORY MULTIPLIERS (Overrides AI decisions) ---
          if (_activePowerUp != null) {
            if (_activePowerUp == 'LOGIC BOMB') {
              finalDamage += 50; // Guaranteed +50 damage no matter what
              combatLog = "LOGIC BOMB DETONATED! " + combatLog;
            }
            else if (_activePowerUp == 'CLARITY STIM') {
              // If base damage was 0, force it to 30. Otherwise, multiply by 1.5.
              finalDamage = finalDamage > 0 ? (finalDamage * 1.5).round() : 30;
              combatLog = "STIM INJECTED! " + combatLog;
            }
            else if (_activePowerUp == 'COGNITIVE SHIELD') {
              // Absolutely prevents negative damage (monster healing)
              if (finalDamage <= 0) {
                finalDamage = 0;
                combatLog = "SHIELD DEPLOYED: Rebound nullified. " + combatLog;
              }
            }

            // Safely burn the item without crashing combat if the network blips
            try {
              await _consumeItem(_activePowerUp!);
            } catch(e) {
              debugPrint("Failed to consume item: $e");
            }
          }

          // --- 2. PENALTY LOGIC ---
          // Only penalize them if their damage is still 0 after all weapons are applied
          if (finalDamage == 0 && _activePowerUp != 'COGNITIVE SHIELD') {
            finalDamage = -15; // Monster heals/recovers
          }

          // --- 3. APPLY HEALTH UPDATE ---
          int newHealth = currentHealth - finalDamage;
          if (newHealth > 100) newHealth = 100; // Cap health at 100%

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(combatLog, style: const TextStyle(fontFamily: 'monospace')),
              backgroundColor: finalDamage > 0 ? const Color(0xFF8B5CF6) : Colors.redAccent,
              duration: const Duration(seconds: 3), // Make it last longer so they can read it
            ),
          );

          final String updatedReframes = existingReframes.isEmpty
              ? thought
              : '$existingReframes||$thought';

          if (newHealth <= 0) {
            // MONSTER DEFEATED: Save health 0, status defeated, AND all reframes
            await supabase.from('user_encounters').update({
              'current_health': 0,
              'status': 'defeated',
              'reframe_used': updatedReframes
            }).eq('id', encounterId);

            // REWARD LOGIC: Grant XP and Shards
            try {
              final profile = await supabase.from('player_profiles').select().eq('user_id', userId).maybeSingle();
              if (profile != null) {
                int currentXP = profile['experience_points'] ?? 0;
                int currentShards = profile['insight_shards'] ?? 0;

                await supabase.from('player_profiles').update({
                  'experience_points': currentXP + 500,
                  'insight_shards': currentShards + 100,
                }).eq('user_id', userId);

                _fetchPlayerStats(); // Refresh HUD
              }
            } catch (e) {
              debugPrint("Reward Error: $e");
            }

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('ENTITY BANISHED. +500 XP | +100 SHARDS', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                backgroundColor: Colors.amber,
              ),
            );
          } else {
            // MONSTER SURVIVED: Update health AND save the reframe attempt
            await supabase.from('user_encounters').update({
              'current_health': newHealth,
              'reframe_used': updatedReframes
            }).eq('id', encounterId);
          }
          await _fetchActiveEncounters();
        }
      } catch (e) {
        print('Combat Error: $e');
      }
    }
  }

  // --- BUILD METHDODS --- //

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0710),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.2),
                  radius: 1.2,
                  colors: [
                    _hasActiveMonster ? const Color(0xFF4C1D95).withOpacity(0.4) : const Color(0xFF2E1065).withOpacity(0.3),
                    const Color(0xFF0A0710),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHUD(primaryColor),
                Expanded(
                  child: Center(
                    child: _hasActiveMonster ? _buildMonsterArena(primaryColor) : _buildEmptySanctum(primaryColor),
                  ),
                ),
                _buildSideMenu(primaryColor),
                // INVENTORY BAR ADDED HERE
                _buildInventoryBar(primaryColor),
                _buildTerminal(primaryColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryBar(Color primaryColor) {
    if (_myItems.isEmpty || !_hasActiveMonster) return const SizedBox.shrink();

    return Container(
      height: 50,
      margin: const EdgeInsets.only(left: 20, right: 20, bottom: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _myItems.length,
        itemBuilder: (context, index) {
          final item = _myItems[index];
          final itemName = item['item_name'];
          final isArmed = _activePowerUp == itemName;

          return GestureDetector(
            onTap: () {
              setState(() => _activePowerUp = isArmed ? null : itemName);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(isArmed ? 'WEAPON DISARMED' : '$itemName ARMED.', style: const TextStyle(fontFamily: 'monospace')),
                  backgroundColor: isArmed ? Colors.grey[800] : primaryColor,
                  duration: const Duration(milliseconds: 1000),
                ),
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isArmed ? primaryColor.withOpacity(0.3) : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isArmed ? primaryColor : Colors.white10,
                  width: isArmed ? 2 : 1,
                ),
                boxShadow: isArmed ? [BoxShadow(color: primaryColor.withOpacity(0.4), blurRadius: 10)] : [],
              ),
              child: Row(
                children: [
                  Icon(_iconMap[itemName] ?? Icons.bolt, size: 16, color: isArmed ? Colors.white : Colors.white54),
                  const SizedBox(width: 8),
                  Text('x${item['quantity']}', style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: isArmed ? Colors.white : Colors.white54, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHUD(Color primaryColor) {
    // Calculate progress to next level
    double xpProgress = (_playerXP % 1000) / 1000;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryColor.withOpacity(0.1),
                  border: Border.all(color: primaryColor.withOpacity(0.3)),
                ),
                child: const Icon(Icons.person, color: Colors.white70, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Lvl $_playerLevel · Exorcist', style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.white54, letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 100,
                        height: 4,
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(2)),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: xpProgress, // Dynamic XP bar
                          child: Container(
                            decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(2), boxShadow: [BoxShadow(color: primaryColor, blurRadius: 4)]),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('$_playerXP XP', style: const TextStyle(fontFamily: 'monospace', fontSize: 9, color: Colors.white)),
                    ],
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white54),
                tooltip: 'The Armory',
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const StoreScreen())).then((_) => _loadInventory()), // Refresh inventory when returning
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.menu_book, color: Colors.white54),
                tooltip: 'Daily Protocols',
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const RitualsScreen())),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white54),
                tooltip: 'Disconnect',
                onPressed: () async {
                  await Supabase.instance.client.auth.signOut();
                  if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const WelcomeScreen()));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
  // --- ADD THIS ENTIRE WIDGET BLOCK ---
  Widget _buildSideMenu(Color primaryColor) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 20.0, bottom: 10.0),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Keeps the buttons tight together
          children: [
            // 1. NEURAL DIAGNOSTICS (Analytics)
            _buildFloatingIcon(
              icon: Icons.radar, // A cool tech-radar icon for analytics
              tooltip: 'Neural Diagnostics',
              primaryColor: primaryColor,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const ProfileAnalyticsScreen()),
                );
              },
            ),

            const SizedBox(height: 16), // Space between the two buttons

            // 2. NEURAL ARCHIVES (Bestiary)
            _buildFloatingIcon(
              icon: Icons.library_books,
              tooltip: 'Neural Archives',
              primaryColor: primaryColor,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const BestiaryScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // A helper function so both buttons share the exact same glassmorphic styling
  Widget _buildFloatingIcon({required IconData icon, required String tooltip, required Color primaryColor, required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: primaryColor.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(color: primaryColor.withOpacity(0.15), blurRadius: 15, spreadRadius: 2),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white70),
        tooltip: tooltip,
        onPressed: onTap,
      ),
    );
  }

  Widget _buildEmptySanctum(Color primaryColor) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_outlined, size: 64, color: primaryColor.withOpacity(0.2)),
          const SizedBox(height: 16),
          const Text('THE SANCTUM IS QUIET', style: TextStyle(fontFamily: 'monospace', fontSize: 12, letterSpacing: 4, color: Colors.white54)),
        ],
      ),
    );
  }

  Widget _buildMonsterArena(Color primaryColor) {
    if (_activeEncounters.isEmpty) return const SizedBox.shrink();

    return PageView.builder(
      controller: _pageController,
      physics: const BouncingScrollPhysics(),
      onPageChanged: (index) => setState(() => _currentSwipeIndex = index),
      itemCount: _activeEncounters.length,
      itemBuilder: (context, index) {
        final encounter = _activeEncounters[index];
        final visualData = encounter['monsters_dictionary'];
        final int currentHealth = encounter['current_health'];
        final String originalThought = encounter['original_thought'];

        return AnimatedBuilder(
          animation: _pageController,
          builder: (context, child) {
            double pageOffset = 0;
            if (_pageController.position.haveDimensions) {
              pageOffset = _pageController.page! - index;
            } else {
              pageOffset = (0 - index).toDouble();
            }
            double scale = (1 - (pageOffset.abs() * 0.25)).clamp(0.75, 1.0);
            double opacity = (1 - (pageOffset.abs() * 0.6)).clamp(0.2, 1.0);

            return Transform.scale(
              scale: Curves.easeOut.transform(scale),
              child: Opacity(opacity: opacity, child: child),
            );
          },
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Text('"$originalThought"', style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.white70, fontSize: 14), textAlign: TextAlign.center),
                ),
                const SizedBox(height: 40),
                AnimatedBuilder(
                  animation: _floatController,
                  builder: (context, child) {
                    return Transform.translate(offset: Offset(0, math.sin(_floatController.value * 2 * math.pi) * 15), child: child);
                  },
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primaryColor.withOpacity(0.05),
                      boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.2), blurRadius: 40, spreadRadius: 10)],
                    ),
                    child: visualData != null && visualData['asset_url'] != null
                        ? Padding(padding: const EdgeInsets.all(20.0), child: Image.asset(visualData['asset_url'], fit: BoxFit.contain))
                        : const Icon(Icons.coronavirus_outlined, size: 80, color: Colors.redAccent),
                  ),
                ),
                const SizedBox(height: 50),
                SizedBox(
                  width: 180,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('ENTITY INTEGRITY', style: TextStyle(fontFamily: 'monospace', fontSize: 10, letterSpacing: 2, color: Colors.white54)),
                          Text('$currentHealth%', style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.redAccent)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: currentHealth / 100,
                          minHeight: 6,
                          backgroundColor: Colors.white.withOpacity(0.05),
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTerminal(Color primaryColor) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1)))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _hasActiveMonster ? 'INITIATE REFRAME SEQUENCE' : 'TERMINAL ENTRY',
                style: TextStyle(fontFamily: 'monospace', fontSize: 10, letterSpacing: 2, color: _hasActiveMonster ? primaryColor : Colors.white54),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('>', style: TextStyle(fontFamily: 'monospace', fontSize: 16, color: Colors.white54)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _terminalController,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 300, // <-- 1. PREVENTS TOKEN OVERLOAD ALERTS
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      textCapitalization: TextCapitalization.sentences, // <-- 2. Auto-capitalizes for better AI reading
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 14, color: Colors.white),
                      decoration: InputDecoration(
                        hintText: _hasActiveMonster ? 'Challenge the thought...' : 'Log a thought to begin...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                        border: InputBorder.none,
                        counterText: "", // <-- 3. Hides the "0/300" text to keep your UI clean
                      ),
                    ),
                  ),
                  IconButton(icon: Icon(Icons.send, color: primaryColor), onPressed: _submitTerminal)
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}