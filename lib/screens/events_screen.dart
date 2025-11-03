import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:myapp/services/notification_service.dart';
import 'package:add_2_calendar/add_2_calendar.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  Box? chatBox;
  Box? eventsBox;
  List<Map<String, dynamic>> events = [];
  String _query = '';
  // ignore: unused_field
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _initHive();
    _initChatBox();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _initHive() async {
    if (!Hive.isBoxOpen('events')) {
      try { await Hive.initFlutter(); } catch (_) {}
      eventsBox = await Hive.openBox('events');
    } else {
      eventsBox = Hive.box('events');
    }
    _loadEvents();
  }

  Future<void> _initChatBox() async {
    try {
      if (Hive.isBoxOpen('chat')) {
        chatBox = Hive.box('chat');
      } else {
        try { await Hive.initFlutter(); } catch (_) {}
        chatBox = await Hive.openBox('chat');
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _loadEvents() {
    final raw = (eventsBox?.get('list') as List?) ?? [];
    events = raw.map<Map<String, dynamic>>((rawE) {
      final e = Map<String, dynamic>.from(rawE as Map);
      return <String, dynamic>{
        'id': e['id'] as int,
        'title': e['title'] as String,
        'description': (e['description'] ?? '') as String,
        'datetime': DateTime.fromMillisecondsSinceEpoch(e['ts'] as int),
        'recurrence': (e['recurrence'] ?? 'none') as String, // none|daily|weekly|monthly
        'offset': (e['offset'] ?? 0) as int, // minutes before
      };
    }).toList()
      ..sort((a, b) => (a['datetime'] as DateTime).compareTo(b['datetime'] as DateTime));
    setState(() {});
  }

  Future<void> _persistEvents() async {
    final list = events.map((e) => {
      'id': e['id'],
      'title': e['title'],
      'description': e['description'],
      'ts': (e['datetime'] as DateTime).millisecondsSinceEpoch,
      'recurrence': e['recurrence'] ?? 'none',
      'offset': e['offset'] ?? 0,
    }).toList();
    await eventsBox?.put('list', list);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    // Separate upcoming and past events
    List<Map<String, dynamic>> data = events;
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      data = data.where((e) =>
        (e['title'] as String).toLowerCase().contains(q) ||
        (e['description'] as String).toLowerCase().contains(q)
      ).toList();
    }
    final upcoming = data.where((e) => e["datetime"].isAfter(now)).toList();
    final past = data.where((e) => e["datetime"].isBefore(now)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Events & Reminders"),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'test_now':
                  await NotificationService.instance.triggerTestNow();
                  break;
                case 'test_5s':
                  await NotificationService.instance.triggerTestInSeconds(5);
                  break;
                case 'pending':
                  final pending = await NotificationService.instance.listPending();
                  if (!context.mounted) return;
                  showDialog(
                    context: context,
                    builder: (ctx) {
                      return AlertDialog(
                        title: const Text('Pending notifications'),
                        content: SizedBox(
                          width: double.maxFinite,
                          child: ListView(
                            shrinkWrap: true,
                            children: [
                              if (pending.isEmpty) const Text('None'),
                              ...pending.map((p) => ListTile(
                                    title: Text('ID: ${p.id}'),
                                    subtitle: Text('${p.title ?? ''}\n${p.body ?? ''}'),
                                  )),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                        ],
                      );
                    },
                  );
                  break;
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem<String>(
                value: 'test_now',
                child: Text('Test now'),
              ),
              const PopupMenuItem<String>(
                value: 'test_5s',
                child: Text('Test in 5s'),
              ),
              const PopupMenuItem<String>(
                value: 'pending',
                child: Text('Pending notifications'),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.delayed(const Duration(seconds: 1));
          _loadEvents();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Search
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search events',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
            const SizedBox(height: 12),
            const Text(
              "Upcoming Events",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...upcoming.map((e) => _buildEventCard(e, isUpcoming: true)),

            const SizedBox(height: 20),
            const Text(
              "Past Events",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...past.map((e) => _buildEventCard(e, isUpcoming: false)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addEventDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> e, {bool isUpcoming = true}) {
    final formattedTime = DateFormat('EEE, MMM d • hh:mm a').format(e["datetime"]);
    return Dismissible(
      key: ValueKey(e['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: Colors.redAccent,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete event?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                ],
              ),
            ) ?? false;
      },
      onDismissed: (_) async {
        final id = e['id'] as int;
        events.removeWhere((x) => x['id'] == id);
        setState(() {});
        await _persistEvents();
        await NotificationService.instance.cancelById(id);
      },
      child: Card(
        elevation: 3,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: Icon(
            isUpcoming ? Icons.event_available : Icons.event_busy,
            color: isUpcoming ? Colors.green : Colors.grey,
          ),
          title: Text(e["title"]),
          subtitle: Text("${e["description"]}\n$formattedTime"),
          isThreeLine: true,
          trailing: IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Add to device calendar',
            onPressed: () => _syncToCalendar(e),
          ),
          onTap: () => _editEventDialog(e),
        ),
      ),
    );
  void _syncToCalendar(Map<String, dynamic> e) {
    final event = Event(
      title: e['title'] as String,
      description: e['description'] as String,
      location: '',
      startDate: e['datetime'] as DateTime,
      endDate: (e['datetime'] as DateTime).add(const Duration(hours: 1)), // assume 1 hour
    );
    Add2Calendar.addEvent2Cal(event);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event added to calendar')),
      );
    }
  }

  // ➕ Add new event manually
  Future<void> _addEventDialog() async {
    String title = '';
    String desc = '';
    DateTime? pickedDate;
    String recurrence = 'none';
    int offset = 0; // minutes

    // Ensure events box is ready before interacting
    await _initHive();
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add New Event"),
        content: StatefulBuilder(
          builder: (context, setInnerState) => SingleChildScrollView(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              TextField(
                decoration: const InputDecoration(labelText: "Title"),
                onChanged: (v) => title = v,
              ),
              TextField(
                decoration: const InputDecoration(labelText: "Description"),
                onChanged: (v) => desc = v,
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: Text(pickedDate == null
                    ? "Pick Date & Time"
                    : DateFormat('EEE, MMM d • hh:mm a').format(pickedDate!)),
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now().subtract(const Duration(days: 1)),
                    lastDate: DateTime(2100),
                    initialDate: DateTime.now(),
                  );
                  if (date != null) {
                    if (!context.mounted) return; 
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (time != null) {
                      setInnerState(() {
                        pickedDate = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time.hour,
                          time.minute,
                        );
                      });
                    }
                  }
                },
              ),
              const SizedBox(height: 8),
              // Recurrence
              Row(
                children: [
                  const Text('Repeat: '),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: recurrence,
                    items: const [
                      DropdownMenuItem(value: 'none', child: Text('None')),
                      DropdownMenuItem(value: 'daily', child: Text('Daily')),
                      DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                      DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                    ],
                    onChanged: (v) => setInnerState(() => recurrence = v ?? 'none'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Offset
              Row(
                children: [
                  const Text('Reminder offset (min): '),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Slider(
                      value: offset.toDouble(),
                      min: 0,
                      max: 120,
                      divisions: 24,
                      label: '$offset',
                      onChanged: (v) => setInnerState(() => offset = v.toInt()),
                    ),
                  ),
                  SizedBox(
                    width: 56,
                    child: Text('$offset', textAlign: TextAlign.center),
                  )
                ],
              ),
            ],
          ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (title.isEmpty) return;
              bool added = false;
              try {
                // Default date/time: next full hour, if not chosen
                pickedDate ??= () {
                  final now = DateTime.now();
                  final nextHour = DateTime(now.year, now.month, now.day, now.hour).add(const Duration(hours: 1));
                  return nextHour;
                }();
                if (pickedDate != null) {
                  // Ensure storage is ready right before persist
                  if (eventsBox == null || !Hive.isBoxOpen('events')) {
                    try { await Hive.initFlutter(); } catch (_) {}
                    eventsBox = await Hive.openBox('events');
                  }
                  final id = DateTime.now().microsecondsSinceEpoch % 1000000000;
                  events.add({
                    'id': id,
                    "title": title,
                    "description": desc,
                    "datetime": pickedDate,
                    'recurrence': recurrence,
                    'offset': offset,
                  });
                  // keep list ordered
                  events.sort((a, b) => (a['datetime'] as DateTime).compareTo(b['datetime'] as DateTime));
                  setState(() {});
                  await _persistEvents();
                  added = true;
                  final notifOn = (chatBox?.get('settings_notificationsEnabled', defaultValue: true) as bool?) ?? true;
                  if (notifOn) {
                    final when = pickedDate!.subtract(Duration(minutes: offset));
                    if (when.isAfter(DateTime.now())) {
                      try {
                        final scheduledId = await NotificationService.instance.scheduleAt(
                          id: id,
                          title: 'Reminder',
                          body: '$title • ${desc.isEmpty ? DateFormat('EEE, MMM d • hh:mm a').format(pickedDate!) : desc}',
                          when: when,
                        );
                        if (context.mounted && scheduledId != -1) {
                          final localText = DateFormat('EEE, MMM d • hh:mm a').format(when.toLocal());
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Reminder scheduled for $localText (id: $scheduledId).'),
                          ));
                        }
                      } catch (_) {}
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Reminder time is in the past after offset; not scheduled.'),
                        ));
                      }
                    }
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Notifications are disabled in Settings; reminder not scheduled.'),
                      ));
                    }
                  }
                }
              } catch (e, st) {
                // Log details to console for diagnosis
                // ignore: avoid_print
                print('Add event error: $e');
                // ignore: avoid_print
                print(st);
                if (context.mounted) {
                  final msg = e.toString();
                  final trunc = msg.length > 120 ? '${msg.substring(0, 120)}…' : msg;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Failed to add event: $trunc'),
                  ));
                }
              } finally {
                if (added && context.mounted) {
                  Navigator.pop(context);
                }
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  Future<void> _editEventDialog(Map<String, dynamic> e) async {
    String title = e['title'] as String? ?? '';
    String desc = e['description'] as String? ?? '';
    DateTime pickedDate = e['datetime'] as DateTime;
    String recurrence = (e['recurrence'] as String?) ?? 'none';
    int offset = (e['offset'] as int?) ?? 0;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Event"),
        content: StatefulBuilder(
          builder: (context, setInnerState) => SingleChildScrollView(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              TextField(
                decoration: const InputDecoration(labelText: "Title"),
                controller: TextEditingController(text: title),
                onChanged: (v) => title = v,
              ),
              TextField(
                decoration: const InputDecoration(labelText: "Description"),
                controller: TextEditingController(text: desc),
                onChanged: (v) => desc = v,
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: Text(DateFormat('EEE, MMM d • hh:mm a').format(pickedDate)),
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now().subtract(const Duration(days: 1)),
                    lastDate: DateTime(2100),
                    initialDate: pickedDate,
                  );
                  if (date != null) {
                    if (!context.mounted) return;
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(hour: pickedDate.hour, minute: pickedDate.minute),
                    );
                    if (time != null) {
                      setInnerState(() {
                        pickedDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                      });
                    }
                  }
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Repeat: '),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: recurrence,
                    items: const [
                      DropdownMenuItem(value: 'none', child: Text('None')),
                      DropdownMenuItem(value: 'daily', child: Text('Daily')),
                      DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                      DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                    ],
                    onChanged: (v) => setInnerState(() => recurrence = v ?? 'none'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Reminder offset (min): '),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Slider(
                      value: offset.toDouble(),
                      min: 0,
                      max: 120,
                      divisions: 24,
                      label: '$offset',
                      onChanged: (v) => setInnerState(() => offset = v.toInt()),
                    ),
                  ),
                  SizedBox(
                    width: 56,
                    child: Text('$offset', textAlign: TextAlign.center),
                  )
                ],
              ),
            ],
          ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final idx = events.indexWhere((x) => x['id'] == e['id']);
              if (idx != -1 && title.isNotEmpty) {
                events[idx] = {
                  'id': e['id'],
                  'title': title,
                  'description': desc,
                  'datetime': pickedDate,
                  'recurrence': recurrence,
                  'offset': offset,
                };
                setState(() {});
                await _persistEvents();
                final notifOn = (chatBox?.get('settings_notificationsEnabled', defaultValue: true) as bool?) ?? true;
                try {
                  await NotificationService.instance.cancelById(e['id'] as int);
                } catch (_) {}
                if (notifOn) {
                  final when = pickedDate.subtract(Duration(minutes: offset));
                  if (when.isAfter(DateTime.now())) {
                    try {
                      final scheduledId = await NotificationService.instance.scheduleAt(
                        id: e['id'] as int,
                        title: 'Reminder',
                        body: '$title • ${desc.isEmpty ? DateFormat('EEE, MMM d • hh:mm a').format(pickedDate) : desc}',
                        when: when,
                      );
                      if (context.mounted && scheduledId != -1) {
                        final localText = DateFormat('EEE, MMM d • hh:mm a').format(when.toLocal());
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Reminder scheduled for $localText (id: $scheduledId).'),
                        ));
                      }
                    } catch (_) {}
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Reminder time is in the past after offset; not scheduled.'),
                      ));
                    }
                  }
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Notifications are disabled in Settings; reminder not scheduled.'),
                    ));
                  }
                }
                if (!context.mounted) {
                  return;
                }
                Navigator.pop(context);
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }
}
