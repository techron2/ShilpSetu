import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../services/buyer_service.dart';
import '../services/profile_service.dart';
import '../theme/app_theme.dart';
import '../utils/inr.dart';

/// Modal bottom sheet for collecting delivery address before placing an order.
class DeliveryAddressSheet extends StatefulWidget {
  final String productId;
  final String productTitle;
  final String artisanId;
  final int quantity;
  final double totalPrice;
  final UserModel? initialUser;

  const DeliveryAddressSheet({
    super.key,
    required this.productId,
    required this.productTitle,
    required this.artisanId,
    required this.quantity,
    required this.totalPrice,
    this.initialUser,
  });

  @override
  State<DeliveryAddressSheet> createState() => _DeliveryAddressSheetState();
}

class _DeliveryAddressSheetState extends State<DeliveryAddressSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _line1Ctrl;
  late final TextEditingController _line2Ctrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _stateCtrl;
  late final TextEditingController _pincodeCtrl;

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    final user = widget.initialUser;
    final map = user?.deliveryAddressMap;

    _nameCtrl = TextEditingController(
      text: map?['name']?.toString() ?? user?.name ?? '',
    );
    _phoneCtrl = TextEditingController(
      text: map?['phone']?.toString() ?? user?.phone ?? '',
    );
    _line1Ctrl = TextEditingController(
      text: map?['line1']?.toString() ?? (map == null ? (user?.deliveryAddress ?? '') : ''),
    );
    _line2Ctrl = TextEditingController(
      text: map?['line2']?.toString() ?? '',
    );
    _cityCtrl = TextEditingController(
      text: map?['city']?.toString() ?? '',
    );
    _stateCtrl = TextEditingController(
      text: map?['state']?.toString() ?? '',
    );
    _pincodeCtrl = TextEditingController(
      text: map?['pincode']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _line1Ctrl.dispose();
    _line2Ctrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _pincodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AppAuthProvider>();
    final user = widget.initialUser ?? auth.userModel;
    if (user == null) {
      setState(() => _errorMessage = 'Please sign in to place an order.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final addressMap = {
      'name': _nameCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'line1': _line1Ctrl.text.trim(),
      'line2': _line2Ctrl.text.trim(),
      'city': _cityCtrl.text.trim(),
      'state': _stateCtrl.text.trim(),
      'pincode': _pincodeCtrl.text.trim(),
    };

    // 1. Save / update address on buyer's profile in background
    try {
      final uid = user.uid;
      if (uid.isNotEmpty) {
        await ProfileService.instance.saveProfile(uid, {
          'delivery_address': addressMap,
        });
        final updatedUser = user.copyWith(
          deliveryAddressMap: addressMap,
        );
        auth.updateUserModel(updatedUser);
      }
    } catch (e) {
      debugPrint('[DeliveryAddressSheet] Failed to persist address to profile: $e');
    }

    if (!mounted) return;

    setState(() => _isSubmitting = false);
    Navigator.of(context).pop(addressMap);
  }

  @override
  Widget build(BuildContext context) {
    // Wrap with padding for keyboard inset
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryTerracotta.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.location_on_rounded,
                        color: AppTheme.primaryTerracotta, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Delivery Address',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.darkIndigo,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF6B7280)),
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Order Summary Pill
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.productTitle.isNotEmpty ? widget.productTitle : 'Product',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Qty: ${widget.quantity} unit${widget.quantity > 1 ? 's' : ''}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatInr(widget.totalPrice),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primaryTerracotta,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: AppTheme.borderGrey),

            // Scrollable Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.warningRed.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.warningRed.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  color: AppTheme.warningRed, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                      color: AppTheme.warningRed, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Full Name
                      _buildLabel('Full Name (Recipient)', isRequired: true),
                      TextFormField(
                        controller: _nameCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: _inputDecoration('Enter recipient full name', Icons.person_outline_rounded),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter recipient name' : null,
                      ),
                      const SizedBox(height: 12),

                      // Phone Number
                      _buildLabel('Phone Number', isRequired: true),
                      TextFormField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: _inputDecoration('10-digit mobile number', Icons.phone_outlined, prefixText: '+91 '),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Please enter phone number';
                          final digits = v.replaceAll(RegExp(r'\D'), '');
                          final tenDigits = digits.length >= 10 ? digits.substring(digits.length - 10) : digits;
                          if (tenDigits.length != 10) return 'Enter a valid 10-digit phone number';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Address Line 1
                      _buildLabel('Address Line 1', isRequired: true),
                      TextFormField(
                        controller: _line1Ctrl,
                        decoration: _inputDecoration('House/Flat/Block no., Street, Area', Icons.home_outlined),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter street address' : null,
                      ),
                      const SizedBox(height: 12),

                      // Address Line 2
                      _buildLabel('Address Line 2 (Optional)', isRequired: false),
                      TextFormField(
                        controller: _line2Ctrl,
                        decoration: _inputDecoration('Apartment, Landmark, Colony', Icons.apartment_rounded),
                      ),
                      const SizedBox(height: 12),

                      // City & State
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('City', isRequired: true),
                                TextFormField(
                                  controller: _cityCtrl,
                                  decoration: _inputDecoration('City', Icons.location_city_rounded),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter city' : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('State', isRequired: true),
                                TextFormField(
                                  controller: _stateCtrl,
                                  decoration: _inputDecoration('State', Icons.map_outlined),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter state' : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Pincode
                      _buildLabel('Pincode', isRequired: true),
                      TextFormField(
                        controller: _pincodeCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                        decoration: _inputDecoration('6-digit PIN code', Icons.pin_drop_outlined),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Enter PIN code';
                          final digits = v.replaceAll(RegExp(r'\D'), '');
                          if (digits.length != 6) return 'Enter valid 6-digit PIN code';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Proceed to Payment Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5, color: Colors.white),
                                )
                              : const Icon(Icons.arrow_forward_rounded, size: 20),
                          label: Text(
                            _isSubmitting ? 'Saving Address…' : 'Proceed to Payment',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          onPressed: _isSubmitting ? null : _submitOrder,
                          style: AppTheme.successButtonStyle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text, {required bool isRequired}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: RichText(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF374151),
          ),
          children: isRequired
              ? const [
                  TextSpan(
                    text: ' *',
                    style: TextStyle(color: AppTheme.warningRed, fontWeight: FontWeight.bold),
                  ),
                ]
              : null,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon, {String? prefixText}) {
    return InputDecoration(
      hintText: hint,
      prefixText: prefixText,
      prefixIcon: Icon(icon, size: 18, color: const Color(0xFF9CA3AF)),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.primaryTerracotta, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.warningRed),
      ),
    );
  }
}
