import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
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


final supabase = Supabase.instance.client;
final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();


int _bottomTabIndex = 0;


class OvertimeScreen extends StatefulWidget {
  final String email;
  final Map<String, dynamic> userData;
  final Future<Map<String, dynamic>> Function() fetchHrmsContext;

  const OvertimeScreen({
    Key? key,
    required this.email,
    required this.userData,
    required this.fetchHrmsContext,
  }) : super(key: key);

  @override
  State<OvertimeScreen> createState() => _OvertimeScreenState();
}


class _OvertimeScreenState extends State<OvertimeScreen> {
  String? employeeUuid;
  bool loading = true;
  List<Map<String, dynamic>> otRecords = [];

  @override
  void initState() {
    super.initState();
    _initUser();
  }

  Future<void> _initUser() async {
    setState(() => loading = true);
    try {
      final profile = await supabase
          .from('employee_records')
          .select('*')
          .eq('email', widget.email)
          .maybeSingle();
      if (profile != null) {
        employeeUuid = profile['id'];
        await fetchOTRecords();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    setState(() => loading = false);
  }

  Future<void> fetchOTRecords() async {
    try {
      final res = await supabase
          .from('overtime_records')
          .select()
          .eq('employee_id', employeeUuid!)
          .order('ot_date', ascending: false);
      otRecords = List<Map<String, dynamic>>.from(res);
    } catch (e) {
      otRecords = [];
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fetch Error: $e')));
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,

      // ✅ END DRAWER (MORE)
      endDrawer: AppDrawer(
        userEmail: widget.email,
        userData: widget.userData,                 // ✅ FIX
        fetchHrmsContext: widget.fetchHrmsContext, // ✅ FIX
        currentRoute: DrawerRoute.overtime,

        companyLogoUrl: null,
      ),

      appBar: AppBar(
        title: Text(
          'Overtime Management',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
        ),
        elevation: 1,
      ),

      // 🔥 BODY + TOFFY OVERLAY
      body: Stack(
        children: [
          loading
              ? const SkeletonOTRecords()
              : MyOTRecordsTab(records: otRecords),

          // 🤖 TOFFY CHAT

        ],
      ),

      // ✅ BOTTOM NAVIGATION (SVG ICONS – SAME AS OTHERS)
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
                  email: widget.email,
                  employeeId: employeeUuid ?? '',
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
                )

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
      ),
    );
  }
}

class MyOTRecordsTab extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  const MyOTRecordsTab({required this.records});

  String _dateFmt(String iso) =>
      DateFormat('dd MMM yyyy').format(DateTime.parse(iso));
  String _hourFmt(num hrs) =>
      hrs.toStringAsFixed(2).endsWith('.00') ? hrs.toStringAsFixed(0) : hrs.toStringAsFixed(2);

  String _rateFmt(dynamic rate) => rate == null ? '-' : "${rate.toString()}x";
  String _amountFmt(dynamic amt) {
    if (amt == null) return "-";
    final n = num.tryParse(amt.toString());
    return n == null ? amt.toString() : "₹${NumberFormat('#,##,###').format(n)}";
  }

  Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved': return Color(0xFF1E88E5);
      case 'pending': return Colors.orange;
      case 'rejected': return Colors.red;
      case 'paid': return Colors.purple;
      default: return Colors.grey;
    }
  }

  String statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'approved': return "APPROVED";
      case 'pending': return "PENDING";
      case 'rejected': return "REJECTED";
      case 'paid': return "PAID";
      case 'draft': return "DRAFT";
      default: return status.toUpperCase();
    }
  }
  @override
  Widget build(BuildContext context) {
    // ⭐ SHOW SVG + TEXT WHEN NO OT RECORDS FOUND
    if (records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              "assets/icons/overtime.svg",
              width: 120,
              height: 120,
            ),
            SizedBox(height: 16),
            Text(
              "No OT records found",
              style: GoogleFonts.montserrat(
                fontSize: 16,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      );
    }
    // ⭐ TABLE WHEN RECORDS AVAILABLE
    return SingleChildScrollView(
      padding: EdgeInsets.all(14),
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: 650),
        child: DataTable(
          columns: [
            DataColumn(label: Text("Date", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold))),
            DataColumn(label: Text("Hours", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold))),
            DataColumn(label: Text("Type", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold))),
            DataColumn(label: Text("Rate", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold))),
            DataColumn(label: Text("Amount", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold))),
            DataColumn(label: Text("Status", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold))),
          ],
          rows: records.map((r) {
            final status = (r['status'] ?? '').toString();
            return DataRow(
              cells: [
                DataCell(Text(_dateFmt(r['ot_date']))),
                DataCell(Text('${_hourFmt(r['total_hours'] ?? 0)} hrs')),
                DataCell(Text(r['ot_type']?.toString().replaceAll('_', ' ').capitalize() ?? '')),
                DataCell(Text(_rateFmt(r['rate_multiplier']))),
                DataCell(Text(_amountFmt(r['ot_amount']))),
                DataCell(
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor(status).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusLabel(status),
                      style: GoogleFonts.montserrat(
                          color: statusColor(status),
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
          dataRowHeight: 50,
          headingRowHeight: 46,
          columnSpacing: 18,
        ),
      ),
    );
  }
}
extension StringExtension on String {
  String capitalize() => this.isEmpty
      ? this
      : '${this[0].toUpperCase()}${this.substring(1).toLowerCase()}';
}
