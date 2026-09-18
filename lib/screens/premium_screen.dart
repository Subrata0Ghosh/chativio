import 'package:flutter/material.dart';
import '../services/subscription_service.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  int _selectedPlanIndex =
      1; // 0 = Weekly, 1 = Yearly (Best Value), 2 = Lifetime
  bool _isProcessing = false;

  final List<Map<String, dynamic>> _plans = [
    {
      "id": "weekly",
      "title": "Weekly Pass",
      "price": "\$2.99 / week",
      "subtitle": "Billed weekly, cancel anytime",
      "badge": null,
      "trial": "3 Days Free Trial",
    },
    {
      "id": "yearly",
      "title": "Yearly Pro",
      "price": "\$39.99 / year",
      "subtitle": "Only \$3.33 / month (Save 60%)",
      "badge": "BEST VALUE 🔥",
      "trial": "3 Days Free Trial",
    },
    {
      "id": "lifetime",
      "title": "Lifetime VIP",
      "price": "\$79.99 once",
      "subtitle": "One-time payment, forever yours",
      "badge": "LIFETIME 👑",
      "trial": "Instant Lifetime Access",
    },
  ];

  final List<Map<String, dynamic>> _features = [
    {
      "icon": Icons.all_inclusive,
      "title": "Unlimited AI Chats",
      "desc": "No daily limits or message caps",
    },
    {
      "icon": Icons.phone_in_talk,
      "title": "Realtime Voice Calls",
      "desc": "Speak hands-free with your AI friend anytime",
    },
    {
      "icon": Icons.camera_alt,
      "title": "Photo & Vision Intelligence",
      "desc": "Analyze homework, recipes, outfits, and scenes",
    },
    {
      "icon": Icons.psychology,
      "title": "All 5 AI Personas",
      "desc": "Wellness Coach, Productivity Mentor, Career Advisor & more",
    },
    {
      "icon": Icons.insights,
      "title": "Deep Mood Analytics",
      "desc": "Weekly wellness reports and psychological insights",
    },
    {
      "icon": Icons.bolt,
      "title": "Ultra-Fast Response Speed",
      "desc": "Priority server routing with zero wait time",
    },
  ];

  Future<void> _handlePurchase() async {
    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(milliseconds: 1200));

    final selected = _plans[_selectedPlanIndex];
    final tier = selected["id"] as String;
    Duration? dur;
    if (tier == 'weekly') {
      dur = const Duration(days: 7);
    } else if (tier == 'yearly') {
      dur = const Duration(days: 365);
    }

    await SubscriptionService.instance.upgradeToPro(tier, duration: dur);

    if (!mounted) return;
    setState(() => _isProcessing = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("🎉 Welcome to Chativio Pro! All features unlocked."),
        backgroundColor: Colors.green,
      ),
    );

    Navigator.pop(context, true);
  }

  void _showPromoCodeDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.redeem, color: Color(0xFF667EEA)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                "Redeem Promo Code",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Enter your VIP promo code to unlock Pro for free (try VIPPRO):",
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: "e.g. VIPPRO",
                prefixIcon: Icon(Icons.vpn_key),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = controller.text.trim();
              final success = await SubscriptionService.instance
                  .redeemPromoCode(code);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);

              if (success) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "✨ Promo code applied! Chativio Pro is active.",
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
                Navigator.pop(context, true);
              } else {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Invalid or expired promo code."),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: const Text("Redeem"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF0F172A),
                  Color(0xFF1E1B4B),
                  Color(0xFF2E1065),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Top Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                      ),
                      TextButton(
                        onPressed: () async {
                          await SubscriptionService.instance.restorePurchases();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Purchases restored."),
                            ),
                          );
                        },
                        child: const Text(
                          "Restore",
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),

                // Main Content
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      // Badge & Header
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.workspace_premium,
                                color: Colors.white,
                                size: 16,
                              ),
                              SizedBox(width: 6),
                              Text(
                                "CHATIVIO PRO",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      const Text(
                        "Experience AI Without Boundaries",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "Voice calls, vision intelligence, unlimited messaging & exclusive companion personas.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),

                      const SizedBox(height: 24),

                      // Feature Cards Grid/List
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          children: _features.map((f) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF667EEA,
                                      ).withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      f["icon"] as IconData,
                                      color: const Color(0xFF818CF8),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          f["title"] as String,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          f["desc"] as String,
                                          style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Plan Selection
                      ...List.generate(_plans.length, (index) {
                        final plan = _plans[index];
                        final isSelected = _selectedPlanIndex == index;
                        final hasBadge = plan["badge"] != null;

                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedPlanIndex = index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(
                                      0xFF667EEA,
                                    ).withValues(alpha: 0.18)
                                  : Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF818CF8)
                                    : Colors.white12,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  color: isSelected
                                      ? const Color(0xFF818CF8)
                                      : Colors.white38,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        spacing: 6,
                                        runSpacing: 2,
                                        children: [
                                          Text(
                                            plan["title"] as String,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (hasBadge)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                gradient: const LinearGradient(
                                                  colors: [
                                                    Color(0xFFF59E0B),
                                                    Color(0xFFEF4444),
                                                  ],
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                plan["badge"] as String,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        plan["subtitle"] as String,
                                        style: const TextStyle(
                                          color: Colors.white60,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  plan["price"] as String,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),

                      // Promo Code link
                      Center(
                        child: TextButton.icon(
                          onPressed: _showPromoCodeDialog,
                          icon: const Icon(
                            Icons.local_offer_outlined,
                            size: 16,
                            color: Color(0xFF818CF8),
                          ),
                          label: const Text(
                            "Have a promo code? Enter here",
                            style: TextStyle(
                              color: Color(0xFF818CF8),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),

                // CTA Button
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isProcessing ? null : _handlePurchase,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF667EEA),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                          ),
                          child: _isProcessing
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _plans[_selectedPlanIndex]["trial"] as String,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Cancel anytime in Google Play / App Store settings. Safe & encrypted.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
