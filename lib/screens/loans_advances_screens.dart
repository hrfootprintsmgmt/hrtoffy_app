import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/skeleton_layouts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../widgets/app_drawer.dart';
import '../widgets/bottom_nav_toffy_button.dart';

import 'dashboard_screen.dart';
import 'leaves_screen.dart';
import 'attendance_screen.dart';
import 'payslip_screen.dart';
import '../widgets/drawer_route.dart';


// 🔧 FIX 1: Update LoansAdvancesScreen widget definition

class LoansAdvancesScreen extends StatefulWidget {
  final String userEmail;
  final Map<String, dynamic> userData;
  final Future<Map<String, dynamic>> Function() fetchHrmsContext;

  const LoansAdvancesScreen({
    Key? key,
    required this.userEmail,
    required this.userData,
    required this.fetchHrmsContext,
  }) : super(key: key);

  @override
  State<LoansAdvancesScreen> createState() => _LoansAdvancesScreenState();
}


class _LoansAdvancesScreenState extends State<LoansAdvancesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _bottomTabIndex = 0;

  @override
  void initState() {
    super.initState();

    /// Only TWO tabs now: My Loans, EMI Schedule
    _tabController = TabController(length: 2, vsync: this, initialIndex: 0);

    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Pill Tab Widget
  Widget _buildSegmentTab(String title, int index) {
    final bool isActive = _tabController.index == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => _tabController.animateTo(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? Colors.blue : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isActive
                ? [
              BoxShadow(
                color: Colors.blue.withOpacity(0.25),
                blurRadius: 6,
                offset: Offset(0, 2),
              )
            ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: isActive ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,

      // ✅ Drawer (opened from "More")
      endDrawer: AppDrawer(
        userEmail: widget.userEmail,
        userData: widget.userData,                 // ✅ FIX
        fetchHrmsContext: widget.fetchHrmsContext, // ✅ FIX
        currentRoute: DrawerRoute.loans,
        companyLogoUrl: null,
      ),

      appBar: AppBar(
        title: const Text('Loans & Advances'),
        elevation: 1,

        /// BLUE CIRCULAR PLUS BUTTON
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: GestureDetector(
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ApplyLoanPage()),
                );

                if (result == true) {
                  setState(() {}); // 🔥 forces FutureBuilder to re-run
                }

              },
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ),
          ),
          // ☰ MENU (APP DRAWER)
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              _scaffoldKey.currentState?.openEndDrawer();
            },
          ),
        ],
      ),

      // 🔥 BODY + TOFFY OVERLAY
      body: Stack(
        children: [
          Column(
            children: [
              // Segmented Tabs
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    _buildSegmentTab('My Loans', 0),
                    const SizedBox(width: 10),
                    _buildSegmentTab('EMI Schedule', 1),
                  ],
                ),
              ),

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    MyLoansTab(),
                    EMIScheduleTab(),
                  ],
                ),
              ),
            ],
          ),

          // 🤖 TOFFY CHAT OVERLAY
        ],
      ),

      // ✅ BOTTOM NAVIGATION
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
                // 🔧 FIX 2: Replace PayslipScreen navigation in loans_advances_screens.dart

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

/// =====================================================
/// MY LOANS TAB
/// =====================================================
class MyLoansTab extends StatelessWidget {
  final SupabaseClient supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> fetchLoans(BuildContext context) async {
    final screen = context.findAncestorWidgetOfExactType<LoansAdvancesScreen>();
    final email = screen?.userEmail ?? supabase.auth.currentUser?.email;

    if (email == null) return [];

    final emp = await supabase
        .from('employee_records')
        .select('id')
        .eq('email', email)
        .maybeSingle();

    if (emp == null) return [];

    final res = await supabase
        .from('loans_advances')
        .select()
        .eq('employee_id', emp['id'])
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(res as List);
  }

  String formatCurrency(dynamic value) {
    if (value == null) return '';
    return '₹${value.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
    )}';
  }

  Color statusColor(String s) {
    switch (s) {
      case "approved":
        return Colors.green;
      case "pending":
        return Colors.orange;
      case "active":
        return Colors.blue;
      case "closed":
        return Colors.grey;
      case "rejected":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: fetchLoans(context),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SkeletonLoansMyLoans();
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                // SVG Icon for Loans
                SvgPicture.asset(
                  "assets/icons/loans.svg",
                  height: 110,
                  width: 110,
                  color: Colors.blueGrey,   // optional tint
                ),

                const SizedBox(height: 20),

                Text(
                  "No loans and advances yet",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  "Apply for a loan using the + button",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          );
        }
        final loans = snapshot.data!;
        return ListView.separated(
          padding: const EdgeInsets.all(14),
          itemCount: loans.length,
          separatorBuilder: (_, __) => const SizedBox(height: 20),
          itemBuilder: (context, i) {
            final loan = loans[i];
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(loan['loan_number'] ?? "",
                      style:
                      const TextStyle(fontWeight: FontWeight.bold)),

                  SizedBox(height: 6),
                  Text("Category: ${loan['loan_category'] ?? '-'}"),
                  Text("Amount: ${formatCurrency(loan['requested_amount'])}"),
                  Text("Tenure: ${loan['tenure_months']} months"),

                  SizedBox(height: 6),

                  /// Status pill
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor(loan['status']).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      (loan['status'] ?? "").toUpperCase(),
                      style: TextStyle(
                          color: statusColor(loan['status']),
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// =====================================================
/// EMI SCHEDULE TAB
/// =====================================================
class EMIScheduleTab extends StatelessWidget {
  final supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> fetchEMI() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    final res = await supabase
        .from('loan_emi_schedule')
        .select('*, loans_advances(loan_number)')
        .eq('employee_id', user.id)
        .order('due_date', ascending: true);

    return List<Map<String, dynamic>>.from(res as List);
  }

  Color statusColor(String s) {
    switch (s) {
      case "paid":
        return Colors.green;
      case "partial":
        return Colors.orange;
      case "missed":
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: fetchEMI(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return SkeletonLoansEMISchedule();

        final emis = snapshot.data!;
        if (emis.isEmpty) {
          return const Center(child: Text("No EMI schedules found."));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(14),
          itemCount: emis.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final emi = emis[i];

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Loan: ${emi['loans_advances']['loan_number']}",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 6),
                  Text("Due: ${emi['due_date'].toString().substring(0, 10)}"),
                  Text("EMI Amount: ₹${emi['emi_amount']}"),
                  Text("Outstanding: ₹${emi['outstanding_principal']}"),

                  SizedBox(height: 6),

                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor(emi['status']).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      (emi['status'] ?? "").toUpperCase(),
                      style: TextStyle(
                          color: statusColor(emi['status']),
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// =====================================================
/// NEW PAGE: APPLY LOAN FORM
/// =====================================================
///
final TextEditingController _amountController = TextEditingController();

class ApplyLoanPage extends StatefulWidget {
  @override
  State<ApplyLoanPage> createState() => _ApplyLoanPageState();
}

class _ApplyLoanPageState extends State<ApplyLoanPage> {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;

  String? _loanCategory;
  double? _requestedAmount;
  int tenure = 3;
  String? _purpose;

  bool submitting = false;

  final List<String> categories = [
    "salary_advance",
    "personal_loan",
    "emergency_loan",
    "education_loan",
    "vehicle_loan",
  ];

  /// Convert snake_case → Capitalized Words
  String prettify(String text) {
    return text
        .split('_')
        .map((e) => e[0].toUpperCase() + e.substring(1).toLowerCase())
        .join(' ');
  }

  Future<void> submitLoan() async {
    if (!_formKey.currentState!.validate()) return;

    _formKey.currentState!.save();

    final amountText = _amountController.text.trim();
    final requestedAmount = double.tryParse(amountText);

    if (_loanCategory == null || requestedAmount == null || _purpose == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("All fields are required"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => submitting = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw "User not logged in";

      final emp = await supabase
          .from('employee_records')
          .select('id, organization_id')
          .eq('email', user.email!)
          .single();

      final loanNum = "LOAN-${DateTime.now().millisecondsSinceEpoch}";

      await supabase.from('loans_advances').insert({
        "loan_number": loanNum,
        "employee_id": emp["id"],
        "organization_id": emp["organization_id"],
        "loan_category": _loanCategory,
        "requested_amount": requestedAmount, // ✅ NEVER NULL
        "tenure_months": tenure,
        "purpose": _purpose,
        "status": "pending",
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Loan request submitted successfully"),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Application failed: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => submitting = false);
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Apply for Loan"),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "Loan Category"),
                value: _loanCategory,
                items: categories
                    .map((c) =>
                    DropdownMenuItem(value: c, child: Text(prettify(c))))
                    .toList(),
                onChanged: (v) => setState(() => _loanCategory = v),
                onSaved: (v) => _loanCategory = v, // ✅ REQUIRED
                validator: (v) => v == null ? "Select category" : null,
              ),


              const SizedBox(height: 12),

              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: "Requested Amount (₹)"),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final value = double.tryParse(v ?? "");
                  if (value == null || value <= 0) {
                    return "Enter valid amount";
                  }
                  return null;
                },
              ),



              const SizedBox(height: 12),

              TextFormField(
                decoration: InputDecoration(labelText: "Purpose"),
                minLines: 2,
                maxLines: 4,
                validator: (v) =>
                (v == null || v.isEmpty) ? "Purpose required" : null,
                onSaved: (v) => _purpose = v,
              ),

              const SizedBox(height: 20),

              submitting
                  ? CircularProgressIndicator()
                  : ElevatedButton(
                onPressed: submitLoan,
                style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 48)),
                child: const Text("Submit Loan Request"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
