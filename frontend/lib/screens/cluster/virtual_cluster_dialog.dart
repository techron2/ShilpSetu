import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/buyer_service.dart';
import '../../theme/app_theme.dart';

/// Modal dialog allowing artisans to create or join a Virtual Cluster,
/// pooling production capacity for large bulk orders.
class VirtualClusterDialog extends StatefulWidget {
  final VoidCallback? onClusterUpdated;
  const VirtualClusterDialog({super.key, this.onClusterUpdated});

  static Future<void> show(BuildContext context, {VoidCallback? onClusterUpdated}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VirtualClusterDialog(onClusterUpdated: onClusterUpdated),
    );
  }

  @override
  State<VirtualClusterDialog> createState() => _VirtualClusterDialogState();
}

class _VirtualClusterDialogState extends State<VirtualClusterDialog> {
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic>? _currentCluster;

  // Create Form
  final _nameCtrl = TextEditingController();
  final _craftCtrl = TextEditingController(text: 'Pottery & Terracotta');
  final _regionCtrl = TextEditingController(text: 'Uttar Pradesh');
  final _capacityCtrl = TextEditingController(text: '400');
  final _descCtrl = TextEditingController();

  // Join Form
  final _joinIdCtrl = TextEditingController();
  final _joinCapacityCtrl = TextEditingController(text: '300');

  int _tabIndex = 0; // 0: View/Create, 1: Join

  @override
  void initState() {
    super.initState();
    _fetchCluster();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _craftCtrl.dispose();
    _regionCtrl.dispose();
    _capacityCtrl.dispose();
    _descCtrl.dispose();
    _joinIdCtrl.dispose();
    _joinCapacityCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchCluster() async {
    final user = Provider.of<AppAuthProvider>(context, listen: false).userModel;
    final aid = user?.uid ?? 'test_artisan_phase4';

    final cluster = await BuyerService.instance.getClusterByArtisan(aid);
    if (!mounted) return;
    setState(() {
      _currentCluster = cluster;
      _isLoading = false;
    });
  }

  Future<void> _handleCreateCluster() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter cluster name')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final user = Provider.of<AppAuthProvider>(context, listen: false).userModel;
    final aid = user?.uid ?? 'test_artisan_phase4';
    final aname = user?.name ?? 'Lead Artisan';
    final cap = int.tryParse(_capacityCtrl.text.trim()) ?? 300;

    final res = await BuyerService.instance.createCluster(
      name: _nameCtrl.text.trim(),
      craftType: _craftCtrl.text.trim(),
      region: _regionCtrl.text.trim(),
      artisanId: aid,
      artisanName: aname,
      capacity: cap,
      description: _descCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (res != null) {
      setState(() => _currentCluster = res);
      widget.onClusterUpdated?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Virtual Cluster created successfully! 🎉'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create cluster')),
      );
    }
  }

  Future<void> _handleJoinCluster() async {
    final targetId = _joinIdCtrl.text.trim();
    if (targetId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Cluster ID')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final user = Provider.of<AppAuthProvider>(context, listen: false).userModel;
    final aid = user?.uid ?? 'test_artisan_phase4';
    final aname = user?.name ?? 'Artisan Member';
    final cap = int.tryParse(_joinCapacityCtrl.text.trim()) ?? 200;

    final res = await BuyerService.instance.joinCluster(
      clusterId: targetId,
      artisanId: aid,
      artisanName: aname,
      capacity: cap,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (res != null) {
      setState(() => _currentCluster = res);
      widget.onClusterUpdated?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Joined Virtual Cluster successfully! 🤝'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to join cluster. Check Cluster ID.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 20,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.hub_rounded, color: AppTheme.primaryTerracotta, size: 28),
                SizedBox(width: 10),
                Text(
                  'Virtual Artisan Cluster',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Federate with nearby artisans to pool production capacity and fulfill bulk export or corporate orders.',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B5E57)),
            ),
            const SizedBox(height: 16),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: AppTheme.primaryTerracotta),
                ),
              )
            else if (_currentCluster != null)
              _buildActiveClusterCard()
            else ...[
              _buildSegmentToggle(),
              const SizedBox(height: 16),
              if (_tabIndex == 0) _buildCreateForm() else _buildJoinForm(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActiveClusterCard() {
    final c = _currentCluster!;
    final name = c['name'] ?? 'Artisan Guild';
    final craft = c['craft_type'] ?? 'Handicrafts';
    final region = c['region'] ?? 'India';
    final cap = c['combined_capacity'] ?? 0;
    final members = (c['members'] as List?) ?? [];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF9F1DC), Color(0xFFFFFDF9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_rounded, color: Color(0xFF8C6E14), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF2C221E)),
                    ),
                    Text('$craft • $region', style: const TextStyle(fontSize: 12, color: Color(0xFF6B5E57))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEADBCE)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text('Combined Capacity', style: TextStyle(fontSize: 11, color: Color(0xFF8D7B74))),
                    const SizedBox(height: 2),
                    Text(
                      '$cap units/mo',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primaryTerracotta),
                    ),
                  ],
                ),
                Container(width: 1, height: 32, color: const Color(0xFFEDE5DF)),
                Column(
                  children: [
                    const Text('Artisan Members', style: TextStyle(fontSize: 11, color: Color(0xFF8D7B74))),
                    const SizedBox(height: 2),
                    Text(
                      '${members.length} artisans',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF2C221E)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text('Member Artisans:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          ...members.take(3).map((m) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                const Icon(Icons.person_pin_rounded, size: 16, color: AppTheme.primaryTerracotta),
                const SizedBox(width: 6),
                Text(
                  '${m['name'] ?? 'Artisan'} (${m['capacity'] ?? 0} units)',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF2C221E)),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildSegmentToggle() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _tabIndex = 0),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: _tabIndex == 0 ? AppTheme.primaryTerracotta : const Color(0xFFF3EFEA),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                '✨ Create New Cluster',
                style: TextStyle(
                  color: _tabIndex == 0 ? Colors.white : const Color(0xFF6B5E57),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _tabIndex = 1),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: _tabIndex == 1 ? AppTheme.primaryTerracotta : const Color(0xFFF3EFEA),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                '🤝 Join Existing Cluster',
                style: TextStyle(
                  color: _tabIndex == 1 ? Colors.white : const Color(0xFF6B5E57),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCreateForm() {
    return Column(
      children: [
        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Cluster / Guild Name',
            hintText: 'e.g. Gorakhpur Terracotta Collective',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _craftCtrl,
                decoration: const InputDecoration(
                  labelText: 'Craft Type',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _capacityCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Monthly Capacity',
                  suffixText: 'units',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _regionCtrl,
          decoration: const InputDecoration(
            labelText: 'Region / District',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _handleCreateCluster,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryTerracotta,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text('Create Cluster & Pool Capacity', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _buildJoinForm() {
    return Column(
      children: [
        TextField(
          controller: _joinIdCtrl,
          decoration: const InputDecoration(
            labelText: 'Cluster ID or Invite Code',
            hintText: 'e.g. cluster_gorakhpur_01',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _joinCapacityCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Your Monthly Production Capacity',
            suffixText: 'units/mo',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _handleJoinCluster,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text('Join Cluster', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}
