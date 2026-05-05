import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/refreshable_screen.dart';
import '../widgets/skeleton_layouts.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../widgets/app_drawer.dart';

import '../widgets/bottom_nav_toffy_button.dart';
import '../widgets/drawer_route.dart';
import 'dashboard_screen.dart';
import 'leaves_screen.dart';
import 'attendance_screen.dart';
import 'payslip_screen.dart';


class FaqsScreen extends StatefulWidget {
  final String organizationId;
  final String userEmail;
  final Map<String, dynamic> userData;
  final Future<Map<String, dynamic>> Function() fetchHrmsContext;

  const FaqsScreen({
    Key? key,
    required this.organizationId,
    required this.userEmail,
    required this.userData,
    required this.fetchHrmsContext,
  }) : super(key: key);

  @override
  State<FaqsScreen> createState() => _FaqsScreenState();
}

class _FaqsScreenState extends State<FaqsScreen> {
  final supabase = Supabase.instance.client;
  // 🔑 STEP 2 — REQUIRED FOR BOTTOM NAV + TOFFY
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();


  int _bottomTabIndex = 0;
  // 🔑 STEP 2 — END

  List<Map<String, dynamic>> faqs = [];
  bool loading = true;
  String selectedCategory = 'All Categories';
  String search = '';

  final List<String> allCategories = [
    'All Categories',
    'General',
    'Leave',
    'Attendance',
    'Payroll',
    'Policies',
    'Benefits',
    'Performance',
    'Training',
  ];

  @override
  void initState() {
    super.initState();
    fetchFaqs();
  }

  Future<void> fetchFaqs() async {
    setState(() => loading = true);
    final results = await supabase
        .from('faqs')
        .select()
        .eq('organization_id', widget.organizationId)
        .eq('is_active', true)
        .order('category')
        .order('created_at', ascending: false);

    setState(() {
      faqs = (results as List<dynamic>)
          .map((faq) => Map<String, dynamic>.from(faq)).toList();
      loading = false;
    });
  }

  List<Map<String, dynamic>> filteredFaqs() {
    final q = search.trim().toLowerCase();
    return faqs.where((faq) {
      final question = (faq['question'] ?? '').toString().toLowerCase();
      final answer = (faq['answer'] ?? '').toString().toLowerCase();
      final category = (faq['category'] ?? '').toString().toLowerCase();
      if (q.isNotEmpty) {
        return question.contains(q) ||
            answer.contains(q) ||
            category.contains(q);
      } else {
        return selectedCategory == 'All Categories' ||
            category == selectedCategory.toLowerCase();
      }
    }).toList();
  }

  Map<String, List<Map<String, dynamic>>> groupFaqsByCategory(List<Map<String, dynamic>> faqList) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var faq in faqList) {
      final cat = faq['category'] ?? 'General';
      grouped.putIfAbsent(cat, () => []).add(faq);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = filteredFaqs();
    final groupedFaqs = groupFaqsByCategory(filtered);

    return Scaffold(
      key: _scaffoldKey,

      // 🔹 STEP 3.1 — ADD DRAWER
      endDrawer: AppDrawer(
        userEmail: '', // FAQ screen doesn’t have email
        userData: widget.userData,                 // ✅ FIX
        fetchHrmsContext: widget.fetchHrmsContext, // ✅ FIX
        currentRoute: DrawerRoute.faqs,

        companyLogoUrl: null,
      ),

      appBar: AppBar(
        title: const Text('Frequently Asked Questions'),
        elevation: 0,
      ),

      // 🔹 STEP 3.2 — BODY MUST BE STACK
      body: Stack(
        children: [
          // 🔸 MAIN FAQ CONTENT
          loading
              ? SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                faqSearchSkeleton(),
                const SizedBox(height: 18),
                faqCategorySkeleton(),
                faqCategorySkeleton(),
                faqCategorySkeleton(),
              ],
            ),
          )
              : SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Find quick answers to common questions',
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
                const SizedBox(height: 20),

                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        TextField(
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText:
                            'Search questions, answers or categories...',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (val) {
                            setState(() => search = val.trim());
                          },
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: selectedCategory,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            labelText: 'All Categories',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          items: allCategories
                              .map(
                                (cat) => DropdownMenuItem<String>(
                              value: cat,
                              child: Text(cat),
                            ),
                          )
                              .toList(),
                          onChanged: (v) => setState(() =>
                          selectedCategory =
                              v ?? 'All Categories'),
                          isExpanded: true,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 18.0),
                    child: Center(
                      child: Text(
                        'No FAQs found. Try another query or category.',
                        style:
                        TextStyle(color: Colors.grey[700]),
                      ),
                    ),
                  )
                else
                  ...groupedFaqs.entries.map((entry) {
                    final String category =
                        entry.key[0].toUpperCase() +
                            entry.key.substring(1).toLowerCase();
                    final questionsList = entry.value;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 20),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 12),
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '$category Questions',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius:
                                    BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 9, vertical: 5),
                                  child: Text(
                                    '${questionsList.length} question${questionsList.length > 1 ? 's' : ''}',
                                    style: TextStyle(
                                      color:
                                      Colors.blue.shade700,
                                      fontWeight:
                                      FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...questionsList.map(
                                  (faq) => FaqExpansionTile(
                                question:
                                faq['question'] ?? '',
                                answer: faq['answer'] ?? '',
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  color: Colors.grey.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            color: Colors.blue.shade500,
                            size: 36),
                        const SizedBox(height: 8),
                        const Text(
                          'Still need help?',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Try asking the HRMS chatbot or contact your HR team for personalized assistance.',
                          style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 🔹 STEP 3.3 — TOFFY CHAT OVERLAY

        ],
      ),

      // 🔹 STEP 3.4 — BOTTOM NAV
      bottomNavigationBar: _buildBottomNav(context),
    );
  }
  // =======================================================
// STEP 4 — BOTTOM NAVIGATION
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
                email: '',
                employeeId: '',
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
                userEmail: '',
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

        // 🤖 TOFFY BUTTON
        // 👉 Handle Toffy icon tap (FULL PAGE)


      },

      items: [
        BottomNavigationBarItem(
          icon: SvgPicture.asset(
            "assets/icons/dashboard.svg",
            width: 22,
            color:
            _bottomTabIndex == 0 ? Colors.blueAccent : Colors.grey,
          ),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(
          icon: SvgPicture.asset(
            "assets/icons/leaves.svg",
            width: 22,
            color:
            _bottomTabIndex == 1 ? Colors.blueAccent : Colors.grey,
          ),
          label: 'Leave',
        ),
        BottomNavigationBarItem(
          icon: SvgPicture.asset(
            "assets/icons/attendance.svg",
            width: 22,
            color:
            _bottomTabIndex == 2 ? Colors.blueAccent : Colors.grey,
          ),
          label: 'Attendance',
        ),
        BottomNavigationBarItem(
          icon: SvgPicture.asset(
            "assets/icons/payroll.svg",
            width: 22,
            color:
            _bottomTabIndex == 3 ? Colors.blueAccent : Colors.grey,
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

}

class FaqExpansionTile extends StatefulWidget {
  final String question;
  final String answer;
  const FaqExpansionTile({required this.question, required this.answer, Key? key}) : super(key: key);

  @override
  State<FaqExpansionTile> createState() => _FaqExpansionTileState();
}

class _FaqExpansionTileState extends State<FaqExpansionTile> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      onExpansionChanged: (v) => setState(() => expanded = v),
      leading: Icon(Icons.question_answer_rounded, color: expanded ? Colors.blue : Colors.grey),
      title: Text(widget.question, style: const TextStyle(fontSize: 15)),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
          child: Align(
              alignment: Alignment.centerLeft,
              child: Text(widget.answer, style: const TextStyle(fontSize: 14))),
        ),
      ],
    );
  }
}
