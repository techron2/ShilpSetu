import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'artisan/photo_capture_screen.dart';

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

  final List<Map<String, dynamic>> _catalogItems = const [
    {
      "id": "item_1",
      "title": "हाथ से बनी टेराकोटा कुल्हड़ (Chai Kulhad Set)",
      "craft": "Clay Pottery (गोरखपुर)",
      "price": "₹ 350",
      "stock": "18 सेट उपलब्ध",
      "icon": Icons.coffee_rounded,
      "color": Color(0xFFD97706),
    },
    {
      "id": "item_2",
      "title": "दाबू ब्लॉक प्रिंट कॉटन स्टोल (Dabu Print Stole)",
      "craft": "Hand Block Print (बागरू)",
      "price": "₹ 890",
      "stock": "12 पीस उपलब्ध",
      "icon": Icons.dry_cleaning_rounded,
      "color": Color(0xFF2563EB),
    },
    {
      "id": "item_3",
      "title": "ढोकरा ब्रास नंदी मूर्ति (Dhokra Tribal Figurine)",
      "craft": "Lost-wax Casting (बस्तर)",
      "price": "₹ 2,100",
      "stock": "4 पीस उपलब्ध",
      "icon": Icons.pets_rounded,
      "color": Color(0xFFD97706),
    },
    {
      "id": "item_4",
      "title": "ब्लू पॉटरी सजावटी फूलदान (Blue Pottery Vase)",
      "craft": "Jaipur Blue Pottery",
      "price": "₹ 1,250",
      "stock": "7 पीस उपलब्ध",
      "icon": Icons.yard_rounded,
      "color": Color(0xFF0D9488),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Big AI Camera Scan Action Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.secondaryOchre, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.secondaryOchre.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryOchre.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_enhance_rounded,
                          color: AppTheme.secondaryOchre,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              "स्मार्ट AI कैमरा स्कैन",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.darkIndigo,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              "शिल्प की फोटो खींचें, विवरण AI खुद भरेगा",
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryTerracotta,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    icon: const Icon(Icons.add_a_photo, size: 22),
                    label: const Text(
                      "फोटो खींचकर नया उत्पाद जोड़ें",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PhotoCaptureScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "आपकी शिल्प सूची (Your Catalog)",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.darkIndigo,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTerracotta.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "${_catalogItems.length} उत्पाद",
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryTerracotta,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Product Cards List
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _catalogItems.length,
              itemBuilder: (context, index) {
                final item = _catalogItems[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: (item['color'] as Color).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            item['icon'] as IconData,
                            color: item['color'] as Color,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['title'],
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.darkIndigo,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item['craft'],
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B7280),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text(
                                    item['price'],
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: AppTheme.primaryTerracotta,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.green.shade200),
                                    ),
                                    child: Text(
                                      item['stock'],
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.green.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
