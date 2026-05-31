import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ProfileAnalyticsScreen extends StatefulWidget {
  const ProfileAnalyticsScreen({super.key});

  @override
  State<ProfileAnalyticsScreen> createState() => _ProfileAnalyticsScreenState();
}

class _ProfileAnalyticsScreenState extends State<ProfileAnalyticsScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _summary = {};
  List<dynamic> _emotionBreakdown = [];

  @override
  void initState() {
    super.initState();
    _fetchAnalyticsData();
  }

  Future<void> _fetchAnalyticsData() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      // Replace with your local network IP or your production URL once deployed
      final response = await http.get(
        Uri.parse('https://sanctum-api.vercel.app/api/analytics/$userId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _summary = data['summary'];
          _emotionBreakdown = data['emotionBreakdown'];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Analytics UI Error: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0710),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('NEURAL DIAGNOSTICS', style: TextStyle(fontFamily: 'monospace', fontSize: 16, letterSpacing: 2)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatGrid(primaryColor),
            const SizedBox(height: 30),
            const Text('EMOTIONAL TRIGGER FREQUENCY', style: TextStyle(fontFamily: 'monospace', fontSize: 12, letterSpacing: 2, color: Colors.white54)),
            const SizedBox(height: 15),
            _emotionBreakdown.isEmpty
                ? const Text('No neural logs recorded yet.', style: TextStyle(color: Colors.white30, fontFamily: 'monospace'))
                : _buildEmotionList(primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildStatGrid(Color primaryColor) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      childAspectRatio: 1.4,
      children: [
        _buildStatCard('ENTITIES BANISHED', '${_summary['totalBanished'] ?? 0}', primaryColor),
        _buildStatCard('STRIKE SUCCESS', '${_summary['successRate'] ?? 0}%', Colors.tealAccent),
        _buildStatCard('TOTAL ENCOUNTERS', '${_summary['totalEncounters'] ?? 0}', Colors.amberAccent),
        _buildStatCard('ACTIVE ANOMALIES', '${_summary['activeThreats'] ?? 0}', Colors.redAccent),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontFamily: 'monospace', fontSize: 9, color: Colors.white54, letterSpacing: 1)),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontFamily: 'monospace', fontSize: 24, fontWeight: FontWeight.bold, color: color, shadows: [Shadow(color: color.withOpacity(0.3), blurRadius: 8)])),
        ],
      ),
    );
  }

  Widget _buildEmotionList(Color primaryColor) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _emotionBreakdown.length,
      itemBuilder: (context, index) {
        final item = _emotionBreakdown[index];
        final String emotion = item['emotion'].toString().toUpperCase();
        final int count = item['count'];

        // Find maximum count for proportional bar layouts
        final int maxCount = _emotionBreakdown.first['count'];
        double ratio = maxCount > 0 ? count / maxCount : 0.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(emotion, style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold)),
                  Text('$count logs', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: primaryColor)),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 4,
                  backgroundColor: Colors.white.withOpacity(0.05),
                  color: primaryColor.withOpacity(0.7),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}