// events_calendar_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/refreshable_screen.dart';
import '../widgets/skeleton_layouts.dart';
import '../widgets/bottom_nav_toffy_button.dart';

import '../widgets/app_drawer.dart';
import '../widgets/drawer_route.dart';
import 'dashboard_screen.dart';
import 'leaves_screen.dart';
import 'attendance_screen.dart';
import 'payslip_screen.dart';


class EventsCalendarScreen extends StatefulWidget {
  final String email;
  final Map<String, dynamic> userData;
  final Future<Map<String, dynamic>> Function() fetchHrmsContext;

  const EventsCalendarScreen({
    Key? key,
    required this.email,
    required this.userData,
    required this.fetchHrmsContext,
  }) : super(key: key);

  @override
  State<EventsCalendarScreen> createState() => _EventsCalendarScreenState();
}

class _EventsCalendarScreenState extends State<EventsCalendarScreen>
    with TickerProviderStateMixin {

  final supabase = Supabase.instance.client;
  // 🔑 STEP 2 — ADD HERE
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();



  int _bottomTabIndex = 0;
// 🔑 STEP 2 — END

  Map<DateTime, List<dynamic>> _eventsByDate = {};
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<dynamic> _selectedEvents = [];
  bool loading = true;

  bool showEventForm = false;
  Map<String, dynamic>? editingEvent;

  late TabController _tabController;
  List<Map<String, dynamic>> createdEvents = [];
  String? _employeeId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchAllEvents();
  }

  Future<void> _fetchAllEvents() async {
    setState(() => loading = true);

    try {
      final emp = await supabase
          .from('employee_records')
          .select('id, organization_id')
          .eq('email', widget.email)
          .maybeSingle();

      if (emp == null) throw Exception("User not found");

      _employeeId = emp['id'].toString();
      final orgId = emp['organization_id'];

      final events = await supabase
          .from('events')
          .select()
          .eq('organization_id', orgId)
          .order('event_date', ascending: true);

      Map<DateTime, List<dynamic>> byDate = {};

      for (final e in events) {
        DateTime d = DateTime.tryParse(e['event_date']) ?? DateTime.now();
        DateTime key = DateTime(d.year, d.month, d.day);
        byDate.putIfAbsent(key, () => []).add(e);
      }

      final created = (events ?? []).where((e) {
        return (e['created_by'] ?? '').toString() == _employeeId;
      }).toList();

      setState(() {
        _eventsByDate = byDate;
        createdEvents =
            created.map((e) => Map<String, dynamic>.from(e)).toList();
        _selectedDay = _focusedDay;
        _selectedEvents =
            _eventsByDate[_selectedDay?.copyWith(hour: 0) ?? DateTime.now()] ??
                [];
        loading = false;
      });
    } catch (e) {
      loading = false;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  List<dynamic> _getEventsOn(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _eventsByDate[key] ?? [];
  }

  void _onDaySelected(DateTime sel, DateTime foc) {
    setState(() {
      _selectedDay = sel;
      _focusedDay = foc;
      _selectedEvents = _getEventsOn(sel);
    });
  }

  void _showAddEvent([Map<String, dynamic>? edit]) {
    setState(() {
      editingEvent = edit;
      showEventForm = true;
    });
  }

  void _hideForm() {
    setState(() => showEventForm = false);
    _fetchAllEvents();
  }

  Future<void> _deleteEvent(String id) async {
    try {
      final res = await supabase.from('events').delete().eq('id', id);
      if (res != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Event deleted')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }

    _fetchAllEvents();
  }

  // -------------------------------------------------------------
  // UI HELPERS
  // -------------------------------------------------------------

  BoxDecoration _cardBox() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE5E7EB)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 10,
          spreadRadius: 1,
          offset: Offset(0, 2),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,

      endDrawer: AppDrawer(
        userEmail: widget.email,
        userData: widget.userData,                 // ✅ FIX
        fetchHrmsContext: widget.fetchHrmsContext, // ✅ FIX
        currentRoute: DrawerRoute.events,
        companyLogoUrl: null,
      ),

      appBar: AppBar(
        title: const Text("Events and Meetings"),
        actions: [
          if (!showEventForm)
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 22),
              ),
              onPressed: () => _showAddEvent(),
            ),
          if (showEventForm)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.black),
              onPressed: _hideForm,
            ),

          // ☰ MENU — ALWAYS VISIBLE
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              _scaffoldKey.currentState?.openEndDrawer();
            },
          ),
        ],
      ),

      // 🔥 BODY WITH TOFFY OVERLAY
      body: Stack(
        children: [
          // MAIN CONTENT
          loading
              ? Column(
            children: [
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    eventsCalendarSkeleton(),
                    eventsCreatedSkeleton(),
                  ],
                ),
              )
            ],
          )
              : _buildMainContent(),

          // 👉 EVENT FORM OVERLAY (THIS WAS MISSING)
          if (showEventForm)
            EventFormModal(
              email: widget.email,
              editingEvent: editingEvent,
              onClose: () {
                setState(() {
                  showEventForm = false;
                  editingEvent = null;
                });
                _fetchAllEvents(); // refresh list
              },
            ),

          // 🤖 TOFFY CHAT

        ],
      ),


      // 👇 ADD THIS (NEXT STEP)
      bottomNavigationBar: _buildBottomNav(context),
    );

  }
  // =======================================================
// STEP 4 — BOTTOM NAVIGATION (ADD BELOW build() METHOD)
// =======================================================

  Widget _buildBottomNav(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      selectedFontSize: 10,
      unselectedFontSize: 9,
      currentIndex: _bottomTabIndex,
      selectedItemColor: Colors.blueAccent,
      unselectedItemColor: Colors.grey,
      showSelectedLabels: true,
      showUnselectedLabels: true,

      onTap: (index) async {
        if (index == 0) {
          setState(() => _bottomTabIndex = 0);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => DashboardScreen(
                email: widget.email,
                employeeId: _employeeId ?? '',
              ),
            ),
          );
          return;
        }

        if (index == 1) {
          setState(() => _bottomTabIndex = 1);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LeavesScreen(
                email: widget.email,
                userData: widget.userData,
                fetchHrmsContext: widget.fetchHrmsContext,
              ),

            ),
          );
          return;
        }

        if (index == 2) {
          setState(() => _bottomTabIndex = 2);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TimeAttendanceScreen(
                userEmail: widget.email,
                userData: widget.userData,                 // ✅ FIX
                fetchHrmsContext: widget.fetchHrmsContext, // ✅ FIX
              ),
            ),
          );
          return;
        }

        if (index == 3) {
          setState(() => _bottomTabIndex = 3);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PayslipScreen(
                userEmail: widget.email,
                userData: widget.userData,
                fetchHrmsContext: widget.fetchHrmsContext,
              ),

            ),
          );
          return;
        }

        if (index == 4) {
          _scaffoldKey.currentState?.openEndDrawer();
          return;
        }

        // 🤖 TOFFY BUTTON


      },

      items: [
        BottomNavigationBarItem(
          icon: SvgPicture.asset(
            "assets/icons/dashboard.svg",
            width: 22,
            color: _bottomTabIndex == 0
                ? Colors.blueAccent
                : Colors.grey,
          ),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(
          icon: SvgPicture.asset(
            "assets/icons/leaves.svg",
            width: 22,
            color: _bottomTabIndex == 1
                ? Colors.blueAccent
                : Colors.grey,
          ),
          label: 'Leave',
        ),
        BottomNavigationBarItem(
          icon: SvgPicture.asset(
            "assets/icons/attendance.svg",
            width: 22,
            color: _bottomTabIndex == 2
                ? Colors.blueAccent
                : Colors.grey,
          ),
          label: 'Attendance',
        ),
        BottomNavigationBarItem(
          icon: SvgPicture.asset(
            "assets/icons/payroll.svg",
            width: 22,
            color: _bottomTabIndex == 3
                ? Colors.blueAccent
                : Colors.grey,
          ),
          label: 'Payslip',
        ),
        BottomNavigationBarItem(
          icon: SvgPicture.asset(
            "assets/icons/menu.svg",
            width: 22,
            color: Colors.grey,
          ),
          label: 'More',
        ),

      ],
    );
  }



  // -------------------------------------------------------------
  // MAIN CONTENT WITH TABS
  // -------------------------------------------------------------

  Widget _buildMainContent() {
    return Column(
      children: [
        _buildTabs(),

        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildCalendarView(),
              _buildCreatedEventsList(),
            ],
          ),
        ),


      ],
    );
  }

  // -------------------------------------------------------------
  // CALENDAR TAB
  // -------------------------------------------------------------

  Widget _buildCalendarView() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Calendar box
          Container(
            margin: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: _cardBox(),
            child: TableCalendar(
              firstDay: DateTime(DateTime.now().year - 1, 1, 1),
              lastDay: DateTime(DateTime.now().year + 1, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
              calendarFormat: CalendarFormat.month,
              availableCalendarFormats: const {CalendarFormat.month: "Month"},
              eventLoader: _getEventsOn,
              onDaySelected: _onDaySelected,
              calendarStyle: CalendarStyle(
                markerDecoration: const BoxDecoration(
                    color: Colors.blue, shape: BoxShape.circle),
                selectedDecoration: BoxDecoration(
                    color: Colors.blue[300], shape: BoxShape.circle),
              ),
              onPageChanged: (d) => _focusedDay = d,
            ),
          ),

          // Title: Events for date
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Events for ${DateFormat.yMMMMd().format(_selectedDay ?? DateTime.now())}",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),

          // Empty State
          if (_selectedEvents.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  SvgPicture.asset(
                    "assets/icons/events.svg",
                    height: 100,
                    width: 100,
                    color: Colors.blueGrey,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "No events scheduled for this date",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

          // Listed Events
          if (_selectedEvents.isNotEmpty)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _selectedEvents.length,
              itemBuilder: (ctx, i) => EventCard(
                event: _selectedEvents[i],
                showActions: false,
                onEdit: (ev) => _showAddEvent(ev),
                onDelete: _deleteEvent,
              ),
            ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // CREATED EVENTS TAB
  // -------------------------------------------------------------

  Widget _buildCreatedEventsList() {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: createdEvents.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              "assets/icons/events.svg",
              height: 120,
              width: 120,
              color: Colors.blueGrey,
            ),
            const SizedBox(height: 12),
            const Text(
              "No events created yet",
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      )
          : ListView.builder(
        itemCount: createdEvents.length,
        itemBuilder: (ctx, i) => EventCard(
          event: createdEvents[i],
          showActions: true,
          onEdit: (ev) => _showAddEvent(ev),
          onDelete: _deleteEvent,
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // TABS (Calendar / Created)
  // -------------------------------------------------------------

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tabController.index = 0),
              child: Container(
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _tabController.index == 0
                      ? Colors.blue
                      : Color(0xFFE5E5E5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "Calendar View",
                  style: TextStyle(
                    color: _tabController.index == 0
                        ? Colors.white
                        : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tabController.index = 1),
              child: Container(
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _tabController.index == 1
                      ? Colors.blue
                      : Color(0xFFE5E5E5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "Events Created",
                  style: TextStyle(
                    color: _tabController.index == 1
                        ? Colors.white
                        : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

//
// -------------------------------------------------------------
// EVENT CARD WITH SHADOW & CLEAN UI
// -------------------------------------------------------------

class EventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final bool showActions;
  final void Function(Map<String, dynamic>) onEdit;
  final void Function(String) onDelete;

  const EventCard({
    Key? key,
    required this.event,
    required this.showActions,
    required this.onEdit,
    required this.onDelete,
  }) : super(key: key);

  BoxDecoration _cardBox() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE5E7EB)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
          spreadRadius: 1,
          offset: Offset(0, 2),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardBox(),
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + Badges
          Row(
            children: [
              Expanded(
                child: Text(
                  event['title'] ?? '',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87),
                ),
              ),
              _categoryBadge(event['event_category'] ?? 'other'),
              SizedBox(width: 6),
              _visibilityBadge(event['visibility'] ?? 'private'),
            ],
          ),

          SizedBox(height: 6),

          Text(
            _formatTime(event['start_time'], event['end_time']),
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),

          Text(
            event['location'] ?? '',
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),

          if ((event['description'] ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                event['description'],
                style: TextStyle(fontSize: 14, color: Colors.grey[800]),
              ),
            ),

          if (showActions)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                    icon: Icon(Icons.edit_outlined),
                    onPressed: () => onEdit(event)),
                IconButton(
                    icon: Icon(Icons.delete_forever, color: Colors.red),
                    onPressed: () => onDelete(event['id'])),
              ],
            ),
        ],
      ),
    );
  }

  String _formatTime(String? start, String? end) {
    if (start == null) return '';
    String st = start;
    String et = end ?? '';
    return "Time: $st${et.isNotEmpty ? ' - $et' : ''}";
  }

  Widget _categoryBadge(String c) {
    final colors = {
      'meeting': Colors.blue,
      'holiday': Colors.green,
      'training': Colors.deepOrange,
      'company_event': Colors.purple,
      'birthday': Colors.pink,
      'anniversary': Colors.indigo,
      'deadline': Colors.red,
      'other': Colors.grey,
    };
    final color = colors[c] ?? Colors.grey;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
      BoxDecoration(color: color, borderRadius: BorderRadius.circular(7)),
      child: Text(
        c.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(color: Colors.white, fontSize: 11),
      ),
    );
  }

  Widget _visibilityBadge(String v) {
    final labels = {
      'private': 'Private',
      'team': 'Team',
      'department': 'Dept.',
      'branch': 'Branch',
      'entity': 'Entity',
      'company_wide': 'Company'
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
          color: Colors.black45, borderRadius: BorderRadius.circular(7)),
      child: Text(
        labels[v] ?? v,
        style: TextStyle(color: Colors.white, fontSize: 10),
      ),
    );
  }
}

//
// -------------------------------------------------------------
// FULL-PAGE EVENT FORM
// -------------------------------------------------------------

class EventFormModal extends StatefulWidget {
  final String email;
  final Map<String, dynamic>? editingEvent;
  final VoidCallback onClose;

  const EventFormModal({
    Key? key,
    required this.email,
    required this.editingEvent,
    required this.onClose,
  }) : super(key: key);

  @override
  State<EventFormModal> createState() => _EventFormModalState();
}

class _EventFormModalState extends State<EventFormModal> {
  final supabase = Supabase.instance.client;

  final _formKey = GlobalKey<FormState>();

  TextEditingController titleCtrl = TextEditingController();
  TextEditingController descCtrl = TextEditingController();
  TextEditingController locationCtrl = TextEditingController();

  DateTime eventDate = DateTime.now();
  TimeOfDay? startTime, endTime;

  String eventCategory = 'other';
  String visibility = 'private';

  bool loading = false;

  @override
  void initState() {
    super.initState();

    if (widget.editingEvent != null) {
      final ev = widget.editingEvent!;
      titleCtrl.text = ev['title'] ?? '';
      descCtrl.text = ev['description'] ?? '';
      eventDate = DateTime.tryParse(ev['event_date']) ?? DateTime.now();

      startTime = _parseTime(ev['start_time']);
      endTime = _parseTime(ev['end_time']);

      locationCtrl.text = ev['location'] ?? '';
      eventCategory = ev['event_category'] ?? 'other';
      visibility = ev['visibility'] ?? 'private';
    }
  }

  TimeOfDay? _parseTime(String? t) {
    if (t == null || t.isEmpty) return null;
    final s = t.split(":");
    return TimeOfDay(hour: int.parse(s[0]), minute: int.parse(s[1]));
  }

  String _formatTime(TimeOfDay? t) {
    if (t == null) return "--:--";
    return "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";
  }
  String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }


  Future<void> submitEvent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => loading = true);

    final emp = await supabase
        .from('employee_records')
        .select('id, organization_id')
        .eq('email', widget.email)
        .maybeSingle();

    if (emp == null) return;

    final data = {
      "title": titleCtrl.text.trim(),
      "description": descCtrl.text.trim(),
      "event_date": DateFormat("yyyy-MM-dd").format(eventDate),
      "start_time": _formatTime(startTime),
      "end_time": _formatTime(endTime),
      "location": locationCtrl.text.trim(),
      "visibility": visibility,
      "event_category": eventCategory,
      "organization_id": emp['organization_id'],
      "created_by": emp['id'],
    };

    try {
      if (widget.editingEvent != null) {
        await supabase
            .from('events')
            .update(data)
            .eq('id', widget.editingEvent!['id']);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Event updated")));
      } else {
        await supabase.from('events').insert(data);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Event created")));
      }

      widget.onClose();
    } catch (e) {
      loading = false;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white, // FULL SCREEN
      width: double.infinity,
      height: double.infinity,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Text(
                    widget.editingEvent != null
                        ? "Edit Event"
                        : "Create New Event",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: widget.onClose,
                  ),
                ],
              ),

              SizedBox(height: 16),

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: titleCtrl,
                      decoration: InputDecoration(labelText: "Event title"),
                      validator: (v) =>
                      v == null || v.trim().isEmpty ? "Required" : null,
                    ),

                    SizedBox(height: 14),

                    ListTile(
                      leading: Icon(Icons.calendar_today),
                      title: Text(DateFormat("MMMM dd, yyyy").format(eventDate)),
                      onTap: () async {
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: eventDate,
                          firstDate:
                          DateTime.now().subtract(Duration(days: 365)),
                          lastDate:
                          DateTime.now().add(Duration(days: 365 * 2)),
                        );
                        if (picked != null) setState(() => eventDate = picked);
                      },
                    ),

                    Row(
                      children: [
                        Expanded(
                          child: ListTile(
                            leading: Icon(Icons.access_time),
                            title: Text(_formatTime(startTime)),
                            subtitle: Text("Start Time"),
                            onTap: () async {
                              TimeOfDay? t = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay(hour: 9, minute: 0),
                              );
                              if (t != null) setState(() => startTime = t);
                            },
                          ),
                        ),
                        Expanded(
                          child: ListTile(
                            leading: Icon(Icons.access_time),
                            title: Text(_formatTime(endTime)),
                            subtitle: Text("End Time"),
                            onTap: () async {
                              TimeOfDay? t = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay(hour: 10, minute: 0),
                              );
                              if (t != null) setState(() => endTime = t);
                            },
                          ),
                        ),
                      ],
                    ),

                    TextFormField(
                      controller: locationCtrl,
                      decoration:
                      InputDecoration(labelText: "Event location"),
                    ),

                    SizedBox(height: 12),

                    TextFormField(
                      controller: descCtrl,
                      minLines: 1,
                      maxLines: 3,
                      decoration:
                      InputDecoration(labelText: "Event description"),
                    ),

                    SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: eventCategory,
                      decoration: InputDecoration(labelText: "Category"),
                      items: [
                        'meeting',
                        'holiday',
                        'training',
                        'company_event',
                        'birthday',
                        'anniversary',
                        'deadline',
                        'other'
                      ]
                          .map((v) => DropdownMenuItem<String>(
                        value: v,
                        child: Text(
                          _toTitleCase(v.replaceAll('_', ' ')),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400, // normal weight
                          ),
                        ),
                      ))
                          .toList(),

                      onChanged: (v) =>
                          setState(() => eventCategory = v ?? 'other'),
                    ),

                    SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: visibility,
                      decoration: InputDecoration(
                          labelText: "Who can see this event?"),
                      items: [
                        {'private': "Private (Only Me)"},
                        {'team': "My Team"},
                        {'department': "My Department"},
                        {'branch': "My Branch"},
                        {'entity': "My Entity"},
                        {'company_wide': "Entire Company"}
                      ]
                          .map((kv) => DropdownMenuItem<String>(
                        value: kv.keys.first,
                        child: Text(
                          kv.values.first,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400, // normal weight
                          ),
                        ),
                      ))
                          .toList(),

                      onChanged: (v) =>
                          setState(() => visibility = v ?? 'private'),
                    ),

                    SizedBox(height: 20),

                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: widget.onClose,
                          child: Text("Cancel"),
                        ),
                        SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: loading ? null : submitEvent,
                          child: Text(widget.editingEvent != null
                              ? "Update Event"
                              : "Create Event"),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
