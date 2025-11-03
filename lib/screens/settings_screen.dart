import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:myapp/providers/theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Box box;
  bool autoFollowUps = true;
  bool idleNudges = true;
  double idleMinutes = 7;
  double nudgeProbability = 25; // percent
  bool notificationsEnabled = true;
  bool morningNudge = false;
  bool eveningNudge = true;
  TimeOfDay morningTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay eveningTime = const TimeOfDay(hour: 19, minute: 0);
  double contentMixFunny = 40; // 0..100 funny bias

  @override
  void initState() {
    super.initState();
    box = Hive.box('chat');
    autoFollowUps = box.get('settings_autoFollowUps', defaultValue: autoFollowUps) as bool;
    idleNudges   = box.get('settings_idleNudges',    defaultValue: idleNudges) as bool;
    idleMinutes  = (box.get('settings_idleMinutes',  defaultValue: idleMinutes.toInt()) as int).toDouble();
    nudgeProbability = (box.get('settings_nudgeProbability', defaultValue: nudgeProbability.toInt()) as int).toDouble();
    notificationsEnabled = box.get('settings_notificationsEnabled', defaultValue: notificationsEnabled) as bool;
    morningNudge = box.get('settings_morningNudge', defaultValue: morningNudge) as bool;
    eveningNudge = box.get('settings_eveningNudge', defaultValue: eveningNudge) as bool;
    final mh = box.get('settings_morningHour', defaultValue: morningTime.hour) as int;
    final mm = box.get('settings_morningMinute', defaultValue: morningTime.minute) as int;
    final eh = box.get('settings_eveningHour', defaultValue: eveningTime.hour) as int;
    final em = box.get('settings_eveningMinute', defaultValue: eveningTime.minute) as int;
    morningTime = TimeOfDay(hour: mh, minute: mm);
    eveningTime = TimeOfDay(hour: eh, minute: em);
    contentMixFunny = (box.get('settings_nudgeContentMixFunny', defaultValue: contentMixFunny.toInt()) as int).toDouble();
  }

  Future<void> _save() async {
    await box.put('settings_autoFollowUps', autoFollowUps);
    await box.put('settings_idleNudges', idleNudges);
    await box.put('settings_idleMinutes', idleMinutes.toInt());
    await box.put('settings_nudgeProbability', nudgeProbability.toInt());
    await box.put('settings_notificationsEnabled', notificationsEnabled);
    await box.put('settings_morningNudge', morningNudge);
    await box.put('settings_eveningNudge', eveningNudge);
    await box.put('settings_morningHour', morningTime.hour);
    await box.put('settings_morningMinute', morningTime.minute);
    await box.put('settings_eveningHour', eveningTime.hour);
    await box.put('settings_eveningMinute', eveningTime.minute);
    await box.put('settings_nudgeContentMixFunny', contentMixFunny.toInt());
  }

  void _resetDefaults() {
    setState(() {
      autoFollowUps = true;
      idleNudges = true;
      idleMinutes = 7;
      nudgeProbability = 25;
      notificationsEnabled = true;
      morningNudge = false;
      eveningNudge = true;
      morningTime = const TimeOfDay(hour: 9, minute: 0);
      eveningTime = const TimeOfDay(hour: 19, minute: 0);
      contentMixFunny = 40;
    });
    _save();
  }

  String _previewText() {
    final idle = idleMinutes.toInt();
    final prob = nudgeProbability.toInt();
    final follow = autoFollowUps ? 'on' : 'off';
    final nudges = idleNudges ? 'enabled' : 'disabled';
    final notif = notificationsEnabled ? 'enabled' : 'disabled';
    final morning = morningNudge ? '${morningTime.format(context)} on' : 'off';
    final evening = eveningNudge ? '${eveningTime.format(context)} on' : 'off';
    final line1 = 'Idle nudges: $nudges — after ~$idle min, chance $prob%';
    final line2 = 'Auto follow-ups after replies: $follow';
    final line3 = 'Notifications: $notif';
    final line4 = 'Daily nudges: morning $morning, evening $evening';
    final line5 = 'Content mix (funny→helpful): ${contentMixFunny.toInt()}%';
    return '$line1\n$line2\n$line3\n$line4\n$line5';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          Builder(
            builder: (context) {
              final fg = Theme.of(context).appBarTheme.foregroundColor ?? Theme.of(context).colorScheme.onPrimary;
              return TextButton(
                onPressed: _resetDefaults,
                style: TextButton.styleFrom(foregroundColor: fg),
                child: const Text('RESET'),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Switch between light and dark themes'),
            value: context.watch<ThemeProvider>().isDarkMode,
            onChanged: (v) => context.read<ThemeProvider>().toggleTheme(),
          ),
          const SizedBox(height: 8),
          Card(
            color: Colors.blueGrey.withValues(alpha:0.08),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.visibility, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _previewText(),
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.88),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Notifications'),
            subtitle: const Text('Show alerts when AI messages arrive while chat is closed'),
            value: notificationsEnabled,
            onChanged: (v) {
              setState(() => notificationsEnabled = v);
              _save();
            },
          ),
          const Padding(
            padding: EdgeInsets.only(left: 16, right: 16, bottom: 8),
            child: Text(
              'When OFF, the app will not show local notifications for new AI messages.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          SwitchListTile(
            title: const Text('Occasional auto follow-ups'),
            subtitle: const Text('Short extra message after the AI replies'),
            value: autoFollowUps,
            onChanged: (v) {
              setState(() => autoFollowUps = v);
              _save();
            },
          ),
          const Padding(
            padding: EdgeInsets.only(left: 16, right: 16, bottom: 8),
            child: Text(
              'When ON, the AI may sometimes add a small follow-up message after its reply to keep the chat flowing.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          SwitchListTile(
            title: const Text('Proactive idle nudges'),
            subtitle: const Text('AI may ping after you are inactive for a while'),
            value: idleNudges,
            onChanged: (v) {
              setState(() => idleNudges = v);
              _save();
            },
          ),
          const Padding(
            padding: EdgeInsets.only(left: 16, right: 16, bottom: 8),
            child: Text(
              'When ON, the AI can occasionally send a friendly check‑in after some inactivity.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          const Text('Daily notification nudges'),
          SwitchListTile(
            title: const Text('Morning nudge'),
            subtitle: Text('Time: ${"${morningTime.hour.toString().padLeft(2,'0')}:${morningTime.minute.toString().padLeft(2,'0')}"}'),
            value: morningNudge,
            onChanged: (v) {
              setState(() => morningNudge = v);
              _save();
            },
          ),
          ListTile(
            leading: const Icon(Icons.access_time),
            title: const Text('Pick morning time'),
            subtitle: Text(morningTime.format(context)),
            onTap: () async {
              final picked = await showTimePicker(context: context, initialTime: morningTime);
              if (picked != null) {
                setState(() => morningTime = picked);
                _save();
              }
            },
          ),
          SwitchListTile(
            title: const Text('Evening nudge'),
            subtitle: Text('Time: ${"${eveningTime.hour.toString().padLeft(2,'0')}:${eveningTime.minute.toString().padLeft(2,'0')}"}'),
            value: eveningNudge,
            onChanged: (v) {
              setState(() => eveningNudge = v);
              _save();
            },
          ),
          ListTile(
            leading: const Icon(Icons.access_time),
            title: const Text('Pick evening time'),
            subtitle: Text(eveningTime.format(context)),
            onTap: () async {
              final picked = await showTimePicker(context: context, initialTime: eveningTime);
              if (picked != null) {
                setState(() => eveningTime = picked);
                _save();
              }
            },
          ),
          const SizedBox(height: 12),
          Text('Content mix (funny → helpful): ${contentMixFunny.toInt()}%'),
          Slider(
            value: contentMixFunny,
            min: 0,
            max: 100,
            divisions: 20,
            label: '${contentMixFunny.toInt()}%',
            onChanged: (v) => setState(() => contentMixFunny = v),
            onChangeEnd: (_) => _save(),
          ),
          const Divider(),
          Text('Idle minutes: ${idleMinutes.toInt()}'),
          Slider(
            value: idleMinutes,
            min: 3,
            max: 30,
            divisions: 27,
            label: idleMinutes.toInt().toString(),
            onChanged: (v) => setState(() => idleMinutes = v),
            onChangeEnd: (_) => _save(),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 16, right: 16, bottom: 8),
            child: Text(
              'How long to wait before the AI considers sending a proactive nudge.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 12),
          Text('Nudge probability: ${nudgeProbability.toInt()}%'),
          Slider(
            value: nudgeProbability,
            min: 0,
            max: 100,
            divisions: 20,
            label: '${nudgeProbability.toInt()}%',
            onChanged: (v) => setState(() => nudgeProbability = v),
            onChangeEnd: (_) => _save(),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 16, right: 16, bottom: 8),
            child: Text(
              'Chance that a proactive nudge is sent once the idle time passes (0% = never, 100% = always).',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
