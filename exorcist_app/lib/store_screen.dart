import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:async'; // Required for timeouts
import 'package:supabase_flutter/supabase_flutter.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreItem {
  final String title;
  final String description;
  final int cost;
  final IconData icon;
  final int requiredLevel;

  _StoreItem({
    required this.title,
    required this.description,
    required this.cost,
    required this.icon,
    required this.requiredLevel,
  });
}

class _StoreScreenState extends State<StoreScreen> {
  // Player Stats
  int _insightShards = 0;
  int _userLevel = 1;
  bool _isLoading = true;

  // Carousel State
  int _focusedIndex = 0;
  final PageController _pageController = PageController(viewportFraction: 0.4);

  // Dynamic Inventory from DB
  List<_StoreItem> _inventory = [];
  List<String> _ownedItemNames = []; // Tracks what the user already bought

  // Map icon names from DB to Flutter Icons
  final Map<String, IconData> _iconMap = {
    'security': Icons.security,
    'api_rounded': Icons.api_rounded,
    'insights': Icons.insights,
    'settings_voice': Icons.settings_voice,
    'architecture': Icons.architecture,
  };

  @override
  void initState() {
    super.initState();
    _initializeStore();
  }

  Future<void> _initializeStore() async {
    try {
      debugPrint("--- Booting Armory ---");
      await _fetchUserStats();
      await _fetchArmoryCatalog();
      await _fetchUserInventory();
      debugPrint("--- Armory Boot Complete ---");
    } catch (e) {
      debugPrint('Initialization Error: $e');
      _showFeedback("NETWORK TIMEOUT. SIGNAL LOST.", isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false); // Force spinner to stop no matter what
      }
    }
  }

  Future<void> _fetchUserStats() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      // Added a 7-second timeout guard
      final data = await Supabase.instance.client
          .from('player_profiles')
          .select('insight_shards, experience_points')
          .eq('user_id', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 7));

      if (data != null && mounted) {
        setState(() {
          _insightShards = data['insight_shards'] ?? 0;
          int xp = data['experience_points'] ?? 0;
          _userLevel = (xp / 1000).floor() + 1;
        });
      }
    } catch (e) {
      debugPrint('Stats Error: $e');
      rethrow; // Pass error to initialization block
    }
  }

  Future<void> _fetchArmoryCatalog() async {
    try {
      final response = await Supabase.instance.client
          .from('armory_catalog')
          .select()
          .order('required_level', ascending: true)
          .timeout(const Duration(seconds: 7));

      if (mounted) {
        setState(() {
          _inventory = (response as List).map((item) {
            return _StoreItem(
              title: item['title'] ?? 'Unknown Item',
              description: item['description'] ?? '',
              cost: item['cost'] ?? 0,
              requiredLevel: item['required_level'] ?? 1,
              icon: _iconMap[item['icon_name']] ?? Icons.help_outline,
            );
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Catalog Error: $e');
      rethrow;
    }
  }

  Future<void> _fetchUserInventory() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final data = await Supabase.instance.client
          .from('user_inventory')
          .select('item_name')
          .eq('user_id', user.id)
          .timeout(const Duration(seconds: 7));

      if (mounted) {
        setState(() {
          _ownedItemNames = (data as List).map((item) => item['item_name'] as String).toList();
        });
      }
    } catch (e) {
      debugPrint('Inventory Error: $e');
    }
  }

  Future<void> _purchaseItem() async {
    if (_inventory.isEmpty) return;

    final item = _inventory[_focusedIndex];
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null || _userLevel < item.requiredLevel) return;

    if (_insightShards < item.cost) {
      _showFeedback("INSUFFICIENT SHARDS.", isError: true);
      return;
    }

    try {
      // 1. Deduct Shards
      await supabase
          .from('player_profiles')
          .update({'insight_shards': _insightShards - item.cost})
          .eq('user_id', user.id);

      // 2. Upsert Inventory
      final existing = await supabase
          .from('user_inventory')
          .select()
          .eq('user_id', user.id)
          .eq('item_name', item.title)
          .maybeSingle();

      if (existing == null) {
        await supabase.from('user_inventory').insert({
          'user_id': user.id,
          'item_name': item.title,
          'quantity': 1,
        });
      } else {
        await supabase.from('user_inventory').update({
          'quantity': (existing['quantity'] as int) + 1,
        }).eq('user_id', user.id).eq('item_name', item.title);
      }

      // 3. Update UI to reflect ownership instantly
      setState(() {
        _insightShards -= item.cost;
        _ownedItemNames.add(item.title);
      });
      _showFeedback("${item.title} ACQUIRED.", isError: false);
    } catch (e) {
      _showFeedback("TRANSACTION FAILED.", isError: true);
    }
  }

  void _showFeedback(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'monospace')),
        backgroundColor: isError ? Colors.redAccent : Colors.deepPurple,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0710),
      body: Stack(
        children: [
          _buildBackground(),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
          else if (_inventory.isEmpty)
            _buildEmptyState()
          else
            SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 40),
                  const Text(
                    'CHOOSE WEAPONS',
                    style: TextStyle(fontFamily: 'monospace', fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2),
                  ),
                  const SizedBox(height: 60),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (i) => setState(() => _focusedIndex = i),
                      itemCount: _inventory.length,
                      itemBuilder: (context, index) => _buildWeaponCard(index),
                    ),
                  ),
                  _buildFooter(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, color: Colors.white24, size: 40),
          const SizedBox(height: 16),
          const Text('ARMORY CATALOG EMPTY OR SIGNAL LOST', style: TextStyle(color: Colors.white54, fontFamily: 'monospace')),
          const SizedBox(height: 20),
          _buildSystemButton('BACK', () => Navigator.pop(context)),
        ],
      ),
    );
  }

  Widget _buildWeaponCard(int index) {
    if (index >= _inventory.length) return const SizedBox();

    bool isFocused = _focusedIndex == index;
    final item = _inventory[index];
    final bool isLocked = _userLevel < item.requiredLevel;

    return AnimatedScale(
      scale: isFocused ? 1.0 : 0.8,
      duration: const Duration(milliseconds: 300),
      child: AnimatedOpacity(
        opacity: isFocused ? 1.0 : 0.4,
        duration: const Duration(milliseconds: 300),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 40),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.05),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isLocked ? Colors.white10 : (isFocused ? Colors.deepPurple : Colors.purple.withOpacity(0.3)),
              width: 2,
            ),
            boxShadow: isFocused && !isLocked ? [BoxShadow(color: Colors.deepPurple.withOpacity(0.2), blurRadius: 20, spreadRadius: 5)] : [],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ImageFiltered(
                    imageFilter: isLocked ? ImageFilter.blur(sigmaX: 6, sigmaY: 6) : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                    child: Icon(item.icon, size: 80, color: Colors.white.withOpacity(0.9)),
                  ),
                  if (isFocused && !isLocked) ...[
                    const SizedBox(height: 20),
                    Text(item.title, style: const TextStyle(fontFamily: 'monospace', color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(item.description, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.white60)),
                    ),
                  ]
                ],
              ),
              if (isLocked)
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_outline, color: Colors.purpleAccent, size: 40),
                    const SizedBox(height: 8),
                    Text('LVL ${item.requiredLevel} REQUIRED', style: const TextStyle(fontFamily: 'monospace', fontSize: 9, color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    if (_inventory.isEmpty || _focusedIndex >= _inventory.length) return const SizedBox();

    final item = _inventory[_focusedIndex];
    final bool isLocked = _userLevel < item.requiredLevel;
    final bool isOwned = _ownedItemNames.contains(item.title); // Check if owned

    return Padding(
      padding: const EdgeInsets.all(30.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildSystemButton('BACK', () => Navigator.pop(context)),
          _buildSystemButton(
            isLocked ? 'LOCKED' : (isOwned ? 'ACQUIRED' : 'ACQUIRE ${item.cost}'),
            (isLocked || isOwned) ? null : _purchaseItem, // Disable button if locked or owned
            isAction: !isLocked && !isOwned,
            isOwned: isOwned, // Pass property to style it grey
          ),
        ],
      ),
    );
  }

  Widget _buildSystemButton(String label, VoidCallback? onTap, {bool isAction = false, bool isOwned = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
        decoration: BoxDecoration(
          color: isOwned
              ? Colors.white10
              : (isAction ? Colors.purpleAccent.withOpacity(0.8) : Colors.deepPurple.withOpacity(0.2)),
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(15), bottomRight: Radius.circular(15)),
          border: Border.all(color: isOwned ? Colors.white24 : Colors.purpleAccent),
        ),
        child: Text(
          label,
          style: TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              color: isOwned ? Colors.white54 : (isAction ? Colors.black : Colors.white),
              letterSpacing: 1,
              fontSize: 12
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('OPERATOR LEVEL', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: Colors.white54)),
              Text('LVL $_userLevel', style: const TextStyle(fontFamily: 'monospace', fontSize: 16, color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.diamond_outlined, color: Colors.purpleAccent, size: 18),
              const SizedBox(width: 8),
              Text('$_insightShards SHARDS', style: const TextStyle(fontFamily: 'monospace', fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
            ],
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