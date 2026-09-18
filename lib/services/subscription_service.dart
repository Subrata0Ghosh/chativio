import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SubscriptionService extends ChangeNotifier {
  SubscriptionService._();
  static final SubscriptionService instance = SubscriptionService._();

  bool _isPro = false;
  String _planTier = 'free'; // 'free', 'weekly', 'yearly', 'lifetime'
  DateTime? _proUntil;
  int _messagesSentToday = 0;
  String _lastMessageDate = '';
  static const int dailyFreeLimit = 20;

  bool get isPro => _isPro;
  String get planTier => _planTier;
  DateTime? get proUntil => _proUntil;
  int get messagesSentToday => _messagesSentToday;
  int get remainingFreeMessages {
    if (_isPro) return 999999;
    final left = dailyFreeLimit - _messagesSentToday;
    return left > 0 ? left : 0;
  }

  bool get canSendMessage {
    if (_isPro) return true;
    return remainingFreeMessages > 0;
  }

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isPro = prefs.getBool('sub_is_pro') ?? false;
      _planTier = prefs.getString('sub_plan_tier') ?? 'free';
      final proUntilMs = prefs.getInt('sub_pro_until');
      if (proUntilMs != null) {
        _proUntil = DateTime.fromMillisecondsSinceEpoch(proUntilMs);
        if (_proUntil!.isBefore(DateTime.now())) {
          _isPro = false;
          _planTier = 'free';
          await prefs.setBool('sub_is_pro', false);
          await prefs.setString('sub_plan_tier', 'free');
        }
      }

      // Reset daily counter if a new day has started
      final todayStr = _formatDate(DateTime.now());
      _lastMessageDate = prefs.getString('sub_last_msg_date') ?? '';
      if (_lastMessageDate != todayStr) {
        _messagesSentToday = 0;
        _lastMessageDate = todayStr;
        await prefs.setString('sub_last_msg_date', todayStr);
        await prefs.setInt('sub_msgs_today', 0);
      } else {
        _messagesSentToday = prefs.getInt('sub_msgs_today') ?? 0;
      }
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint("SubscriptionService init error: $e");
    }
  }

  Future<void> recordMessageSent() async {
    if (_isPro) return;
    final prefs = await SharedPreferences.getInstance();
    final todayStr = _formatDate(DateTime.now());
    if (_lastMessageDate != todayStr) {
      _messagesSentToday = 1;
      _lastMessageDate = todayStr;
      await prefs.setString('sub_last_msg_date', todayStr);
    } else {
      _messagesSentToday++;
    }
    await prefs.setInt('sub_msgs_today', _messagesSentToday);
    notifyListeners();
  }

  Future<bool> upgradeToPro(String tier, {Duration? duration}) async {
    final prefs = await SharedPreferences.getInstance();
    _isPro = true;
    _planTier = tier;
    if (duration != null) {
      _proUntil = DateTime.now().add(duration);
      await prefs.setInt('sub_pro_until', _proUntil!.millisecondsSinceEpoch);
    } else {
      _proUntil = null;
      await prefs.remove('sub_pro_until');
    }

    await prefs.setBool('sub_is_pro', true);
    await prefs.setString('sub_plan_tier', tier);
    notifyListeners();
    return true;
  }

  Future<bool> redeemPromoCode(String rawCode) async {
    final code = rawCode.trim().toUpperCase();
    if (code == 'VIPPRO' || code == 'SUPERUSER') {
      await upgradeToPro('lifetime');
      return true;
    } else if (code == 'CHATIVIO2026' || code == 'PROMO100') {
      await upgradeToPro('yearly', duration: const Duration(days: 365));
      return true;
    } else if (code == 'TRIAL3' || code == 'WELCOMEPRO') {
      await upgradeToPro('trial', duration: const Duration(days: 30));
      return true;
    }
    return false;
  }

  Future<void> restorePurchases() async {
    // In production, syncs with Google Play / Apple StoreKit receipts
    await init();
  }

  String _formatDate(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
}
