// surveys_screen.dart
// Full updated file — supports rating, yes-no, text, multiple-choice (single-select),
// and checkbox (multi-select). Robust parsing for stringified JSON and multiple option shapes.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/refreshable_screen.dart';
import '../widgets/skeleton_layouts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../widgets/app_drawer.dart';

import '../widgets/bottom_nav_toffy_button.dart';
// Screens used by bottom nav
import 'dashboard_screen.dart';
import 'leaves_screen.dart';
import 'attendance_screen.dart';
import 'payslip_screen.dart';
import '../widgets/drawer_route.dart';


class SurveysScreen extends StatefulWidget {
  final String userEmail;
  final Map<String, dynamic> userData;
  final Future<Map<String, dynamic>> Function() fetchHrmsContext;

  const SurveysScreen({
    Key? key,
    required this.userEmail,
    required this.userData,
    required this.fetchHrmsContext,
  }) : super(key: key);

  @override
  State<SurveysScreen> createState() => _SurveysScreenState();
}


class _SurveysScreenState extends State<SurveysScreen>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();


  int _bottomTabIndex = 0;
  bool loading = true;
  String? errorMsg;
  Map<String, dynamic>? employeeData;
  List<Map<String, dynamic>> activeSurveys = [];
  List<Map<String, dynamic>> completedSurveys = [];
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    fetchEmployeeAndSurveys();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  /// Robust parse for questions field: accepts List, Map-with-questions,
  /// or stringified JSON of list/map.
  List<Map<String, dynamic>> parseQuestionsField(dynamic raw) {
    if (raw == null) return [];

    try {
      // If already a List of maps
      if (raw is List) {
        return raw
            .where((e) => e != null)
            .map<Map<String, dynamic>>((e) {
          if (e is Map<String, dynamic>) return e;
          if (e is Map) return Map<String, dynamic>.from(e);
          if (e is String) {
            final decoded = jsonDecode(e);
            if (decoded is Map) return Map<String, dynamic>.from(decoded);
          }
          return <String, dynamic>{};
        }).where((m) => m.isNotEmpty).toList();
      }

      // If stored as stringified JSON
      if (raw is String) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded
              .map<Map<String, dynamic>>((e) =>
          e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})
              .where((m) => m.isNotEmpty)
              .toList();
        } else if (decoded is Map) {
          // maybe shape: { "questions": [...] } or single question object
          if (decoded['questions'] is List) {
            return (decoded['questions'] as List).map((e) {
              if (e is Map) return Map<String, dynamic>.from(e);
              return <String, dynamic>{};
            }).where((m) => m.isNotEmpty).toList();
          }
          return [Map<String, dynamic>.from(decoded)];
        }
      }

      // If raw is Map that contains questions array
      if (raw is Map) {
        if (raw['questions'] is List) {
          return (raw['questions'] as List).map((e) {
            if (e is Map) return Map<String, dynamic>.from(e);
            return <String, dynamic>{};
          }).where((m) => m.isNotEmpty).toList();
        }
      }
    } catch (e) {
      // ignore parse errors, return empty
      debugPrint('parseQuestionsField error: $e');
    }

    return [];
  }

  bool matchesLocation(dynamic metadata, String? entityId, String? branchId) {
    try {
      if (metadata == null) return true;
      if (metadata is String && metadata.trim().isEmpty) return true;

      dynamic md = metadata;
      if (metadata is String) {
        md = jsonDecode(metadata);
      }

      if (md is Map) {
        if (md.containsKey('entity_id')) {
          final target = md['entity_id']?.toString();
          if (target != null && target.isNotEmpty) {
            return target == entityId;
          }
        }
        if (md.containsKey('branch_id')) {
          final target = md['branch_id']?.toString();
          if (target != null && target.isNotEmpty) {
            return target == branchId;
          }
        }
        if (md.containsKey('target_location')) {
          final loc = md['target_location']?.toString();
          if (loc == null || loc.isEmpty) return true;

          if (loc.startsWith('branch:')) {
            final bid = loc.split(':')[1];
            return bid == branchId;
          }

          if (loc.startsWith('entity:')) {
            final eid = loc.split(':')[1];
            return eid == entityId;
          }

          return loc == 'company';
        }
      }
    } catch (e) {}
    return true;
  }

  Future<void> fetchEmployeeAndSurveys() async {
    setState(() {
      loading = true;
      errorMsg = null;
    });

    try {
      final emp = await supabase
          .from('employee_records')
          .select()
          .eq('email', widget.userEmail)
          .maybeSingle();

      if (emp == null) {
        setState(() {
          errorMsg = "Employee record not found.";
          loading = false;
        });
        return;
      }

      employeeData = Map<String, dynamic>.from(emp as Map);
      final orgId = emp['organization_id'];

      final allSurveysRaw = await supabase
          .from('surveys')
          .select()
          .eq('organization_id', orgId)
          .eq('status', 'active');

      final myResponsesRaw = await supabase
          .from('survey_responses')
          .select('survey_id')
          .eq('employee_id', emp['id']);

      final completedIds = <String>{};
      if (myResponsesRaw is List) {
        for (final r in myResponsesRaw) {
          if (r['survey_id'] != null) {
            completedIds.add(r['survey_id'].toString());
          }
        }
      }

      List<Map<String, dynamic>> actives = [];
      List<Map<String, dynamic>> completeds = [];

      if (allSurveysRaw is List) {
        for (final surveyRaw in allSurveysRaw) {
          final survey = Map<String, dynamic>.from(surveyRaw);
          survey['questions'] = parseQuestionsField(survey['questions']);

          dynamic metadata = survey['metadata'];
          if (metadata is String && metadata.trim().isNotEmpty) {
            try {
              metadata = jsonDecode(metadata);
            } catch (_) {}
          }
          survey['metadata'] = metadata;

          if (!matchesLocation(
              survey['metadata'],
              emp['entity_id']?.toString(),
              emp['branch_id']?.toString())) continue;

          if (survey['target_audience'] == "department") {
            final targets = survey['target_departments'] ?? [];
            if (targets is List && emp['department'] != null) {
              if (!targets.contains(emp['department'])) continue;
            }
          }

          if (completedIds.contains(survey['id'].toString())) {
            completeds.add(survey);
          } else {
            actives.add(survey);
          }
        }
      }

      setState(() {
        activeSurveys = actives;
        completedSurveys = completeds;
        loading = false;
      });
    } catch (e) {
      setState(() {
        errorMsg = e.toString();
        loading = false;
      });
    }
  }

  Widget buildSurveyList(List<Map<String, dynamic>> list,
      {required bool showParticipate}) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              "assets/icons/surveys.svg",
              height: 120,
              width: 120,
              color: Colors.blueGrey, // soft muted color
            ),
            const SizedBox(height: 12),
            Text(
              showParticipate ? "No active surveys yet" : "No completed surveys yet",
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) =>
          buildSurveyCard(list[index], showParticipate: showParticipate),
    );
  }

  Widget buildSurveyCard(Map<String, dynamic> survey,
      {required bool showParticipate}) {
    final isSurvey = (survey['survey_type'] ?? 'survey') == "survey";
    String? endsAt;

    try {
      if (survey['ends_at'] != null) {
        final dt = survey['ends_at'] is String
            ? DateTime.parse(survey['ends_at'])
            : survey['ends_at'];
        endsAt = DateFormat('d/M/y').format(dt);
      }
    } catch (_) {}

    final questions = survey['questions'] is List ? survey['questions'] : [];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    survey['title'] ?? "",
                    style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: isSurvey ? Colors.blue.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Text(
                    isSurvey ? "survey" : "poll",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSurvey ? Colors.blue.shade700 : Colors.green.shade700,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (!showParticipate)
                  Container(
                    margin: const EdgeInsets.only(left: 7),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    child: Text(
                      "Completed",
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              survey['description'] ?? "",
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Icon(Icons.list_alt, size: 17, color: Colors.grey.shade500),
                const SizedBox(width: 5),
                Text(
                  "${questions.length} question${questions.length == 1 ? '' : 's'}",
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
                if (endsAt != null) ...[
                  const SizedBox(width: 16),
                  Icon(Icons.schedule, size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 3),
                  Text(
                    "Ends $endsAt",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ]
              ],
            ),
            if (showParticipate)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 7.5),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.blue.shade600,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(7)),
                    ),
                    onPressed: employeeData == null
                        ? null
                        : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SurveyResponseForm(
                            survey: survey,
                            employeeId: employeeData!['id'].toString(),
                            onCompleted: fetchEmployeeAndSurveys,
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      "Participate",
                      style:
                      TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,

      // ✅ END DRAWER (MORE)
      endDrawer: AppDrawer(
        userEmail: widget.userEmail,
        userData: widget.userData,                 // ✅ FIX
        fetchHrmsContext: widget.fetchHrmsContext, // ✅ FIX
        currentRoute: DrawerRoute.surveys,

        companyLogoUrl: null,
      ),

      appBar: AppBar(
        title: const Text('Surveys & Polls'),
      ),

      // 🔥 BODY + TOFFY OVERLAY
      body: Stack(
        children: [
          loading
              ? surveysListSkeleton()
              : (errorMsg != null)
              ? Center(child: Text(errorMsg!))
              : Column(
            children: [
              // SEGMENTED TABS
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            _tabController!.animateTo(0);
                            setState(() {});
                          },
                          child: Container(
                            height: 45,
                            decoration: BoxDecoration(
                              color: _tabController!.index == 0
                                  ? Colors.blue
                                  : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              "Active (${activeSurveys.length})",
                              style: TextStyle(
                                color: _tabController!.index == 0
                                    ? Colors.white
                                    : Colors.black87,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            _tabController!.animateTo(1);
                            setState(() {});
                          },
                          child: Container(
                            height: 45,
                            decoration: BoxDecoration(
                              color: _tabController!.index == 1
                                  ? Colors.blue
                                  : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              "Completed (${completedSurveys.length})",
                              style: TextStyle(
                                color: _tabController!.index == 1
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
                ),
              ),

              // TAB CONTENT
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    buildSurveyList(activeSurveys,
                        showParticipate: true),
                    buildSurveyList(completedSurveys,
                        showParticipate: false),
                  ],
                ),
              ),
            ],
          ),

          // 🤖 TOFFY CHAT OVERLAY
        ],
      ),

      // ✅ BOTTOM NAVIGATION (SVG ICONS)
      bottomNavigationBar: BottomNavigationBar(
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
                  email: widget.userEmail,
                  employeeId: employeeData?['id'] ?? '',
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
                  email: widget.userEmail,
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
                  userEmail: widget.userEmail,
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
                  userEmail: widget.userEmail,
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

          // 🤖 TOFFY


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
      ),
    );

  }
}

// ---------------- SurveyResponseForm ----------------
class SurveyResponseForm extends StatefulWidget {
  final Map<String, dynamic> survey;
  final String employeeId;
  final VoidCallback onCompleted;

  const SurveyResponseForm({
    Key? key,
    required this.survey,
    required this.employeeId,
    required this.onCompleted,
  }) : super(key: key);

  @override
  State<SurveyResponseForm> createState() => _SurveyResponseFormState();
}

class _SurveyResponseFormState extends State<SurveyResponseForm> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  Map<String, dynamic> answers = {};
  bool submitting = false;

  List<Map<String, dynamic>> questions = [];

  @override
  void initState() {
    super.initState();

    final qRaw = widget.survey['questions'];

    if (qRaw is List) {
      questions = qRaw.map((q) => Map<String, dynamic>.from(q)).toList();
    } else {
      // Try to parse stringified or nested JSON (defensive)
      questions = _parseQuestionsField(qRaw);
    }

    // initialize answers with canonical types
    for (var q in questions) {
      final qId = q['id']?.toString() ?? UniqueKey().toString();

      final rawType = (q['type'] ?? '').toString().toLowerCase();
      // normalize types
      String type;
      if (rawType == 'rating') type = 'rating';
      else if (rawType == 'text') type = 'text';
      else if (rawType == 'yes-no' || rawType == 'yesno' || rawType == 'yes_no')
        type = 'yes-no';
      else if (['multiple-choice', 'multiple_choice', 'multiplechoice', 'choice', 'mcq', 'single-choice', 'single_choice', 'singlechoice']
          .contains(rawType)) {
        type = 'multiple-choice';
      } else if (['checkbox', 'multi-select', 'multiselect', 'multi_select'].contains(rawType)) {
        type = 'checkbox';
      } else {
        // default fallback to text
        type = 'text';
      }

      q['__canonical_type'] = type;

      if (type == 'rating') {
        answers[qId] = q.containsKey('default') ? (q['default'] ?? 0) : 0;
      } else if (type == 'checkbox') {
        answers[qId] = <String>[];
      } else {
        answers[qId] = q.containsKey('default') ? q['default'] : null;
      }
    }
  }

  // Reuse earlier parsing logic but isolated to this class too
  List<Map<String, dynamic>> _parseQuestionsField(dynamic raw) {
    if (raw == null) return [];

    try {
      if (raw is List) {
        return raw
            .where((e) => e != null)
            .map<Map<String, dynamic>>((e) {
          if (e is Map<String, dynamic>) return e;
          if (e is Map) return Map<String, dynamic>.from(e);
          if (e is String) {
            final decoded = jsonDecode(e);
            if (decoded is Map) return Map<String, dynamic>.from(decoded);
          }
          return <String, dynamic>{};
        }).where((m) => m.isNotEmpty).toList();
      }

      if (raw is String) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded
              .map<Map<String, dynamic>>((e) =>
          e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})
              .where((m) => m.isNotEmpty)
              .toList();
        } else if (decoded is Map) {
          if (decoded['questions'] is List) {
            return (decoded['questions'] as List).map((e) {
              if (e is Map) return Map<String, dynamic>.from(e);
              return <String, dynamic>{};
            }).where((m) => m.isNotEmpty).toList();
          }
          return [Map<String, dynamic>.from(decoded)];
        }
      }

      if (raw is Map) {
        if (raw['questions'] is List) {
          return (raw['questions'] as List).map((e) {
            if (e is Map) return Map<String, dynamic>.from(e);
            return <String, dynamic>{};
          }).where((m) => m.isNotEmpty).toList();
        }
      }
    } catch (e) {
      debugPrint('_parseQuestionsField error: $e');
    }

    return [];
  }

  // normalize options to List<String> from multiple shapes
  List<String> _normalizeOptions(dynamic rawOptions) {
    if (rawOptions == null) return <String>[];

    try {
      if (rawOptions is List) {
        return rawOptions.map<String>((e) {
          if (e == null) return '';
          if (e is String) return e;
          if (e is Map) {
            final possible =
                e['label'] ?? e['value'] ?? e['text'] ?? e['option'] ?? e.toString();
            return possible?.toString() ?? e.toString();
          }
          return e.toString();
        }).where((s) => s.isNotEmpty).toList();
      }

      if (rawOptions is String) {
        final decoded = jsonDecode(rawOptions);
        return _normalizeOptions(decoded);
      }
    } catch (e) {
      debugPrint('_normalizeOptions error: $e');
    }
    return <String>[];
  }

  Widget buildQuestion(Map<String, dynamic> q, int idx) {
    final qId = q['id']?.toString() ?? idx.toString();
    final qText = q['question']?.toString() ?? q['text']?.toString() ?? 'Question';
    final qType = (q['__canonical_type'] ?? q['type'] ?? 'text').toString();

    Widget control;

    switch (qType) {
      case 'rating':
        final int scale = (q['scale'] is int)
            ? q['scale'] as int
            : (int.tryParse(q['scale']?.toString() ?? '') ?? 5);
        final int rating = (answers[qId] is int) ? answers[qId] as int : 0;
        control = Row(
          children: List.generate(scale, (star) {
            final value = star + 1;
            return IconButton(
              onPressed: () => setState(() => answers[qId] = value),
              icon: Icon(
                Icons.star_rounded,
                size: 30,
                color:
                value <= rating ? Colors.amber.shade700 : Colors.grey.shade300,
              ),
            );
          }),
        );
        break;

      case 'yes-no':
        final yesNoOptions = ['Yes', 'No'];
        control = Column(
          children: yesNoOptions.map<Widget>((option) {
            return RadioListTile<String>(
              value: option,
              groupValue: answers[qId],
              onChanged: (val) => setState(() => answers[qId] = val),
              title: Text(option, style: const TextStyle(fontSize: 16)),
            );
          }).toList(),
        );
        break;

      case 'multiple-choice':
        final options =
        _normalizeOptions(q['options'] ?? q['choices'] ?? q['items']);
        control = Column(
          children: options.map<Widget>((option) {
            return RadioListTile<String>(
              value: option,
              groupValue: answers[qId],
              onChanged: (val) => setState(() => answers[qId] = val),
              title: Text(option, style: const TextStyle(fontSize: 16)),
            );
          }).toList(),
        );
        break;

      case 'checkbox':
        final options =
        _normalizeOptions(q['options'] ?? q['choices'] ?? q['items']);
        final List<String> selected =
        List<String>.from(answers[qId] ?? <String>[]);
        control = Column(
          children: options.map<Widget>((option) {
            final isChecked = selected.contains(option);
            return CheckboxListTile(
              value: isChecked,
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    selected.add(option);
                  } else {
                    selected.remove(option);
                  }
                  answers[qId] = selected;
                });
              },
              title: Text(option, style: const TextStyle(fontSize: 16)),
              controlAffinity: ListTileControlAffinity.leading,
            );
          }).toList(),
        );
        break;

      case 'text':
      default:
        control = TextFormField(
          initialValue: answers[qId]?.toString(),
          onChanged: (v) => answers[qId] = v,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey.shade100,
            hintText: "Write your answer",
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          maxLines: q['multiline'] == true ? null : 1,
        );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            qText,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 12),
          control,
        ],
      ),
    );
  }


  Future<void> handleSubmit() async {
    // validate required questions
    for (var q in questions) {
      final qId = q['id']?.toString();
      if (qId == null) continue;
      if (q['required'] == true) {
        final val = answers[qId];
        final type = q['__canonical_type'] ?? q['type'] ?? 'text';
        if (type == 'rating') {
          if (val == null || (val is int && val == 0)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(backgroundColor: Colors.red, content: Text('Please answer: ${q['question'] ?? q['text']}')),
            );
            return;
          }
        } else if (type == 'checkbox') {
          if (val == null || (val is List && val.isEmpty)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(backgroundColor: Colors.red, content: Text('Please answer: ${q['question'] ?? q['text']}')),
            );
            return;
          }
        } else {
          if (val == null || (val is String && val.trim().isEmpty)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(backgroundColor: Colors.red, content: Text('Please answer: ${q['question'] ?? q['text']}')),
            );
            return;
          }
        }
      }
    }

    setState(() => submitting = true);

    final responses = <Map<String, dynamic>>[];

    for (var q in questions) {
      final qId = q['id']?.toString() ?? '';
      final type = q['__canonical_type'] ?? q['type'] ?? 'text';
      var ans = answers[qId];

      // keep list answers as-is (for checkbox)
      // rating is int, multiple-choice & yes-no are string
      responses.add({
        'question_id': qId,
        'question_text': q['question'] ?? q['text'] ?? '',
        'type': type,
        'answer': ans,
      });
    }

    try {
      await supabase.from('survey_responses').insert({
        'survey_id': widget.survey['id'],
        'employee_id': widget.employeeId,
        'responses': responses,
        'submitted_at': DateTime.now().toIso8601String(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.green, content: Text('Survey response submitted!')),
      );

      widget.onCompleted();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text('Submit failed: $e')),
      );
      setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Take Survey')),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // TITLE
              Text(widget.survey['title'] ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 20)),
              const SizedBox(height: 6),

              // DESCRIPTION
              if ((widget.survey['description'] ?? '').toString().isNotEmpty)
                Text(widget.survey['description'], style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 12),

              // QUESTIONS
              for (var i = 0; i < questions.length; i++) buildQuestion(questions[i], i),

              const SizedBox(height: 18),

              // SUBMIT BUTTON
              ElevatedButton(
                onPressed: submitting ? null : handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                ),
                child: submitting
                    ? const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                )
                    : const Text(
                  "Submit Response",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(height: 22),
            ],
          ),
        ),
      ),
    );
  }
}
