import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import '../widgets/refreshable_screen.dart';
import '../widgets/skeleton_layouts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../widgets/app_drawer.dart';

import '../widgets/bottom_nav_toffy_button.dart';
// Bottom nav target screens
import 'dashboard_screen.dart';
import 'leaves_screen.dart';
import 'attendance_screen.dart';
import 'payslip_screen.dart';
import '../widgets/drawer_route.dart';


class TaxDeductionScreen extends StatefulWidget {
  final String userEmail;
  final Map<String, dynamic> userData;
  final Future<Map<String, dynamic>> Function() fetchHrmsContext;

  const TaxDeductionScreen({
    Key? key,
    required this.userEmail,
    required this.userData,
    required this.fetchHrmsContext,
  }) : super(key: key);

  @override
  State<TaxDeductionScreen> createState() => _TaxDeductionScreenState();
}


class _TaxDeductionScreenState extends State<TaxDeductionScreen> {
  final supabase = Supabase.instance.client;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();


  int _bottomTabIndex = 0; // 👈 Tax screen = More section
  String? employeeId, organizationId, employeeName, employeeEmail, currentFY;
  double monthlySalary = 0.0;
  bool isLoading = true, canDeclare = true, canUploadProof = true;
  String selectedRegime = "new_regime";
  List<Map<String, dynamic>> deductionTypes = [];
  Map<String, dynamic> deductionDeclarations = {};
  Map<String, List<Map<String, dynamic>>> deductionProofs = {};
  Map<String, TextEditingController> amountControllers = {};
  Map<String, TextEditingController> notesControllers = {};
  double standardDeductionOld = 50000,
      standardDeductionNew = 75000,
      rebateLimitOld = 500000,
      rebateLimitNew = 700000;
  List<dynamic> oldRegimeSlabs = [
    {'minIncome': 0, 'maxIncome': 250000, 'rate': 0},
    {'minIncome': 250000, 'maxIncome': 500000, 'rate': 5},
    {'minIncome': 500000, 'maxIncome': 1000000, 'rate': 20},
    {'minIncome': 1000000, 'maxIncome': null, 'rate': 30},
  ];
  List<dynamic> newRegimeSlabs = [
    {'minIncome': 0, 'maxIncome': 400000, 'rate': 0},
    {'minIncome': 400000, 'maxIncome': 800000, 'rate': 5},
    {'minIncome': 800000, 'maxIncome': 1200000, 'rate': 10},
    {'minIncome': 1200000, 'maxIncome': 1600000, 'rate': 15},
    {'minIncome': 1600000, 'maxIncome': 2000000, 'rate': 20},
    {'minIncome': 2000000, 'maxIncome': 2400000, 'rate': 25},
    {'minIncome': 2400000, 'maxIncome': null, 'rate': 30},
  ];
  DateTime? declarationStart, declarationEnd, proofStart, proofEnd;
  String? errorMsg;
  Timer? _debounce;

  get typeId_ => null;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    amountControllers.forEach((_, c) => c.dispose());
    notesControllers.forEach((_, c) => c.dispose());
    _debounce?.cancel();
    super.dispose();
  }

  // ---------- SHARED UI HELPERS (C1 cards + TF1 inputs) ----------

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE5E7EB)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 3),
        )
      ],
    );
  }

  InputDecoration _inputDecoration(String label,
      {String? prefixText, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixText: prefixText,
      filled: true,
      fillColor: Colors.white,
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // ~42px
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFF1E90FF), width: 1.2),
      ),
    );
  }

  // ---------------------------------------------------------------

  String getCurrentFY() {
    var now = DateTime.now();
    int y = now.year;
    return now.month >= 4 ? "$y-${y + 1}" : "${y - 1}-$y";
  }

  Future<void> _initData() async {
    setState(() {
      isLoading = true;
      errorMsg = null;
    });
    try {
      currentFY = getCurrentFY();
      final emp = await supabase
          .from('employee_records')
          .select('id, organization_id, full_name, email')

          .eq('email', widget.userEmail)
          .maybeSingle();
      if (emp == null) {
        setState(() {
          errorMsg = "Employee record not found.";
          isLoading = false;
        });
        return;
      }
      employeeId = emp['id'].toString();
      organizationId = emp['organization_id'].toString();
      employeeName = emp['full_name'].toString();
      employeeEmail = emp['email'].toString();

      final salaryRes = await supabase
          .rpc('get_employee_salary', params: {
        'p_employee_id': employeeId,
      });

      monthlySalary = (salaryRes ?? 0).toDouble();


      var config = await supabase
          .from('income_tax_config')
          .select()
          .eq('organization_id', organizationId!)
          .eq('financial_year', currentFY!)
          .maybeSingle();
      if (config != null) {
        standardDeductionOld =
            (config['standard_deduction_old_regime'] ?? 50000).toDouble();
        standardDeductionNew =
            (config['standard_deduction_new_regime'] ?? 75000).toDouble();
        rebateLimitOld =
            (config['rebate_limit_old_regime'] ?? 500000).toDouble();
        rebateLimitNew =
            (config['rebate_limit_new_regime'] ?? 700000).toDouble();
        if (config['old_regime_slabs'] != null) {
          oldRegimeSlabs = config['old_regime_slabs'];
        }
        if (config['new_regime_slabs'] != null) {
          newRegimeSlabs = config['new_regime_slabs'];
        }
      }

      var window = await supabase
          .from('tax_submission_windows')
          .select()
          .eq('organization_id', organizationId!)
          .eq('financial_year', currentFY!)
          .maybeSingle();
      if (window != null) {
        var now = DateTime.now();
        declarationStart =
            DateTime.tryParse(window['declaration_start_date'] ?? '');
        declarationEnd =
            DateTime.tryParse(window['declaration_end_date'] ?? '');
        proofStart =
            DateTime.tryParse(window['proof_submission_start_date'] ?? '');
        proofEnd =
            DateTime.tryParse(window['proof_submission_end_date'] ?? '');
        canDeclare = declarationStart != null &&
            declarationEnd != null &&
            now.isAfter(declarationStart!) &&
            now.isBefore(declarationEnd!);
        canUploadProof = proofStart != null &&
            proofEnd != null &&
            now.isAfter(proofStart!) &&
            now.isBefore(proofEnd!);
      }

      var regime = await supabase
          .from('tax_regime_selections')
          .select('regime_type')
          .eq('employee_id', employeeId!)
          .eq('financial_year', currentFY!)
          .maybeSingle();
      if (regime != null) {
        selectedRegime = regime['regime_type'] ?? 'new_regime';
      }

      await _fetchDeductionTypes();
      await _fetchDeclarations();
    } catch (e) {
      errorMsg = "$e";
    }
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _fetchDeductionTypes() async {
    List<Map<String, dynamic>> types = [];
    if (selectedRegime == "old_regime") {
      final q = await supabase
          .from('tax_deduction_types')
          .select()
          .contains('applies_to_regime', ['old_regime'])
          .eq('is_active', true)
          .order('code');
      types = List<Map<String, dynamic>>.from(q);
    }
    setState(() {
      deductionTypes = types;
      for (final t in deductionTypes) {
        amountControllers.putIfAbsent(
            t['id'], () => TextEditingController());
        notesControllers.putIfAbsent(
            t['id'], () => TextEditingController());
      }
    });
  }

  Future<void> _fetchDeclarations() async {
    final res = await supabase
        .from('tax_declarations')
        .select()
        .eq('employee_id', employeeId!)
        .eq('financial_year', currentFY!);
    deductionDeclarations.clear();
    for (final dec in res) {
      deductionDeclarations[dec['deduction_type_id']] = dec;
      if (amountControllers.containsKey(dec['deduction_type_id'])) {
        amountControllers[dec['deduction_type_id']]!.text =
            (dec['declared_amount'] ?? '').toString();
      }
      if (notesControllers.containsKey(dec['deduction_type_id'])) {
        notesControllers[dec['deduction_type_id']]!.text =
            (dec['employee_notes'] ?? '').toString();
      }
    }
    await _fetchAllProofs();
    setState(() {});
  }

  Future<void> _fetchAllProofs() async {
    deductionProofs.clear();
    var valuesList = List.from(deductionDeclarations.values);
    for (final declaration in valuesList) {
      if (declaration['id'] == null) continue;
      final proofs = await supabase
          .from('tax_proofs')
          .select()
          .eq('declaration_id', declaration['id'])
          .order('uploaded_at');
      deductionProofs[declaration['deduction_type_id']] =
      List<Map<String, dynamic>>.from(proofs);
    }
    setState(() {});
  }

  Future<void> _saveRegimeSelection() async {
    if (!canDeclare) return;
    await supabase.from('tax_regime_selections').upsert(
      {
        'employee_id': employeeId!,
        'organization_id': organizationId!,
        'financial_year': currentFY!,
        'regime_type': selectedRegime,
        'selected_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'employee_id,financial_year',
    );
    await _initData();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text("Regime selection updated."),
        backgroundColor: Colors.green));
  }

  Future<void> _onDeductionToggle(String typeId, bool checked) async {
    if (!canDeclare) return;
    double amount =
        double.tryParse(amountControllers[typeId]?.text ?? "0") ?? 0;
    await supabase.from('tax_declarations').upsert(
      {
        'employee_id': employeeId!,
        'organization_id': organizationId!,
        'financial_year': currentFY!,
        'deduction_type_id': typeId,
        'is_claimed': checked,
        'declared_amount': checked ? amount : 0,
        'employee_notes': notesControllers[typeId]?.text ?? '',
        'status': 'draft',
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'employee_id,financial_year,deduction_type_id',
    );
    setState(() {
      deductionDeclarations[typeId] ??= {};
      deductionDeclarations[typeId]['is_claimed'] = checked;
    });
  }

  void _onAmountOrNoteChanged(String typeId) {
    setState(() {});
  }

  Future<void> _uploadProof(String typeId) async {
    if (!canUploadProof) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Proof upload window is closed'),
        ),
      );
      return;
    }


    // 1️⃣ Pick file
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      allowMultiple: false,
    );

    if (result == null) return;

    final file = File(result.files.single.path!);
    final int size = await file.length();

    if (size > 10 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File too large (max 10MB)')),
      );
      return;
    }

    // 2️⃣ ENSURE tax_declarations ROW EXISTS (THIS WAS MISSING)
    var declaration = deductionDeclarations[typeId];

    if (declaration == null || declaration['id'] == null) {
      final inserted = await supabase
          .from('tax_declarations')
          .upsert(
        {
          'employee_id': employeeId!,
          'organization_id': organizationId!,
          'financial_year': currentFY!,
          'deduction_type_id': typeId,
          'is_claimed': true,
          'declared_amount':
          double.tryParse(amountControllers[typeId]?.text ?? '0') ?? 0,
          'employee_notes': notesControllers[typeId]?.text ?? '',
          'status': 'draft',
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'employee_id,financial_year,deduction_type_id',
      )
          .select()
          .single();

      declaration = inserted;
      deductionDeclarations[typeId] = inserted;
    }

    // 3️⃣ Upload file to storage
    final fileName =
        '${employeeId!}_${typeId}_${DateTime.now().millisecondsSinceEpoch}.${file.path.split('.').last}';
    final storagePath = '${organizationId!}/$currentFY/$fileName';

    try {
      await supabase.storage.from('tax-proofs').upload(storagePath, file);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
      return;
    }


    final pub =
    supabase.storage.from('tax-proofs').getPublicUrl(storagePath);

    // 4️⃣ 🔥 ADD THIS CODE HERE (YOU ASKED THIS)
    await supabase.from('tax_proofs').insert({
      'declaration_id': declaration['id'],   // ✅ required
      'deduction_type_id': typeId,            // ✅ column EXISTS
      'file_url': pub,                        // ✅ required
      'file_name': fileName,                  // ✅ required
      'file_size': size,                      // ✅ required
      'file_type': file.path.split('.').last, // ✅ required
      'uploaded_by': employeeId!,             // ✅ NOT NULL column
      'uploaded_at': DateTime.now().toIso8601String(),
    });


    // 5️⃣ Refresh UI
    await _fetchAllProofs();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Document uploaded successfully')),
    );
  }


  Future<void> _saveAllDeclarations({bool submit = false}) async {
    if (!canDeclare) return;
    for (final type in deductionTypes) {
      final typeId = type['id'];
      final controller = amountControllers[typeId];
      final notesController = notesControllers[typeId];
      double amount = double.tryParse(controller?.text ?? "0") ?? 0;
      bool checked = amount > 0;
      await supabase.from('tax_declarations').upsert(
        {
          'employee_id': employeeId!,
          'organization_id': organizationId!,
          'financial_year': currentFY!,
          'deduction_type_id': typeId,
          'is_claimed': checked,
          'declared_amount': checked ? amount : 0,
          'employee_notes': notesController?.text ?? '',
          'status': submit ? 'submitted' : 'draft',
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'employee_id,financial_year,deduction_type_id',
      );
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(submit
            ? "Declarations submitted!"
            : "Declarations saved as draft."),
        backgroundColor: submit ? Colors.blue : Colors.grey));
    await _fetchDeclarations();
  }

  // --------------------------- BUILD ---------------------------

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tax Declaration')),
        body: const SkeletonTaxDeclarationPage(),
      );
    }
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF3F4F6),

      // ✅ RIGHT SIDE MENU (MORE)
      endDrawer: AppDrawer(
        userEmail: widget.userEmail,
        userData: widget.userData,                 // ✅ FIX
        fetchHrmsContext: widget.fetchHrmsContext, // ✅ FIX
        currentRoute: DrawerRoute.tax,

        companyLogoUrl: null,
      ),

      appBar: AppBar(
        title: const Text('Tax Declaration'),
        backgroundColor: const Color(0xFF1E90FF),
        elevation: 1,
      ),

      // 🔥 BODY + TOFFY OVERLAY
      body: Stack(
        children: [
          isLoading
              ? const SkeletonTaxDeclarationPage()
              : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildEmployeeInfo(),
                const SizedBox(height: 12),
                _buildRegimeSelection(context),

                if (errorMsg != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      errorMsg!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                const SizedBox(height: 12),
                _buildTaxSummary(),

                if (selectedRegime == "old_regime" &&
                    deductionTypes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: _buildAvailableDeductions(),
                  ),

                const SizedBox(height: 24),

                if (selectedRegime == "old_regime")
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed:
                          !canDeclare ? null : () => _saveAllDeclarations(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[200],
                            foregroundColor: Colors.black,
                            padding:
                            const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text("Save Declaration"),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: !canDeclare
                              ? null
                              : () =>
                              _saveAllDeclarations(submit: true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                            const Color(0xFF1E90FF),
                            foregroundColor: Colors.white,
                            padding:
                            const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text("Submit for Review"),
                        ),
                      ),
                    ],
                  ),

                if (selectedRegime == "new_regime")
                  ElevatedButton(
                    onPressed: _saveRegimeSelection,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                      const Color(0xFF1E90FF),
                      foregroundColor: Colors.white,
                      minimumSize:
                      const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Padding(
                      padding:
                      EdgeInsets.symmetric(vertical: 14),
                      child: Text("Confirm Regime"),
                    ),
                  ),
              ],
            ),
          ),

          // 🤖 TOFFY CHAT OVERLAY
        ],
      ),

      // 🔥 SVG BOTTOM NAVIGATION (SAME AS OTHER SCREENS)
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _bottomTabIndex,
        selectedFontSize: 10,
        unselectedFontSize: 9,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        showSelectedLabels: true,
        showUnselectedLabels: true,

        onTap: (index) {
          setState(() => _bottomTabIndex = index);

          switch (index) {
            case 0:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => DashboardScreen(
                    email: widget.userEmail,
                    employeeId: employeeId ?? '',
                  ),
                ),
              );
              break;

            case 1:
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
              break;

            case 2:
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
              break;

            case 3:
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
              break;

            case 4:
              _scaffoldKey.currentState?.openEndDrawer();
              break;



          }
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

  // ------------------------- UI SECTIONS -------------------------

  Widget _buildEmployeeInfo() {
    return Container(
      decoration: _cardDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person, color: Color(0xFF1E90FF)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    employeeName ?? '',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.email,
                    size: 16, color: Color(0xFF888888)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    employeeEmail ?? '',
                    style: const TextStyle(color: Color(0xFF888888)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.currency_rupee,
                    size: 16, color: Color(0xFF888888)),
                const SizedBox(width: 8),
                Text(
                  'Monthly CTC: ₹${NumberFormat('#,##,###').format(monthlySalary)}',
                  style: const TextStyle(color: Color(0xFF888888)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildRegimeSelection(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tax Regime Selection',
                style:
                TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            RadioListTile<String>(
              title: Text(
                  'New Regime (Rebate: ₹${(rebateLimitNew / 100000).toInt()}L)'),
              subtitle: const Text('Limited deductions, lower tax rates'),
              value: 'new_regime',
              groupValue: selectedRegime,
              activeColor: const Color(0xFF1E90FF),
              onChanged: !canDeclare
                  ? null
                  : (v) {
                if (v != null) setState(() => selectedRegime = v);
                _fetchDeductionTypes();
              },
            ),
            RadioListTile<String>(
              title: Text(
                  'Old Regime (Rebate: ₹${(rebateLimitOld / 100000).toInt()}L)'),
              subtitle: const Text('Multiple deductions available'),
              value: 'old_regime',
              groupValue: selectedRegime,
              activeColor: const Color(0xFF1E90FF),
              onChanged: !canDeclare
                  ? null
                  : (v) {
                if (v != null) setState(() => selectedRegime = v);
                _fetchDeductionTypes();
              },
            ),
          ],
        ),
      ),
    );
  }
  Map<String, double> _calculateTaxSummary() {
    double grossSalary = monthlySalary * 12;
    double stdDed = selectedRegime == 'new_regime'
        ? standardDeductionNew
        : standardDeductionOld;
    double otherDeductions = 0.0;
    deductionTypes.forEach((type) {
      var typeId = type['id'];
      if ((deductionDeclarations[typeId]?['is_claimed'] ?? false)) {
        double value =
            double.tryParse(amountControllers[typeId]?.text ?? "0") ?? 0;
        otherDeductions += value;
      }
    });

    double taxable =
    (grossSalary - stdDed - otherDeductions).clamp(0, double.infinity);

    List<dynamic> slabs =
    selectedRegime == 'new_regime' ? newRegimeSlabs : oldRegimeSlabs;
    double incomeTax = 0.0;
    for (final slab in slabs) {
      double min = (slab['minIncome'] ?? 0).toDouble();
      double? max = slab['maxIncome']?.toDouble();
      double rate = (slab['rate'] ?? 0).toDouble();
      if (taxable > min) {
        double slabAmt = max != null ? min - min : taxable - min;
        if (slabAmt > 0) {
          incomeTax += slabAmt * rate / 100.0;
        }
      }
    }
    double rebateLimit =
    selectedRegime == 'new_regime' ? rebateLimitNew : rebateLimitOld;
    if (taxable <= rebateLimit) incomeTax = 0;
    double cess = incomeTax * 0.04;
    double totalTax = (incomeTax + cess).roundToDouble();
    double monthlyTDS = (totalTax / 12).ceilToDouble();

    return {
      'grossSalary': grossSalary,
      'standardDeduction': stdDed,
      'otherDeductions': otherDeductions,
      'taxableIncome': taxable,
      'annualTaxLiability': totalTax,
      'monthlyTDS': monthlyTDS,
    };
  }

  Widget _buildTaxSummary() {
    var m = _calculateTaxSummary();
    return Container(
      decoration: _cardDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tax Summary',
                style:
                TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(
              'Regime Selected: ${selectedRegime == 'new_regime' ? 'New Regime' : 'Old Regime'}',
              style: const TextStyle(color: Color(0xFF1E90FF)),
            ),
            const SizedBox(height: 12),
            _summaryRow('Gross Salary', m['grossSalary']!),
            _summaryRow('Standard Deduction', m['standardDeduction']!),
            _summaryRow('Other Deductions', m['otherDeductions']!),
            const Divider(),
            _summaryRow('Taxable Income', m['taxableIncome']!),
            _summaryRow('Annual Tax Liability', m['annualTaxLiability']!,
                isHighlight: true),
            const Divider(),
            _summaryRow('Monthly TDS', m['monthlyTDS']!,
                isHighlight: true),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, double amount,
      {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight:
                  isHighlight ? FontWeight.bold : FontWeight.normal,
                  color:
                  isHighlight ? const Color(0xFF1E90FF) : null)),
          Text(
            '₹${NumberFormat('#,##,###').format(amount.toInt())}',
            style: TextStyle(
              fontWeight:
              isHighlight ? FontWeight.bold : FontWeight.normal,
              color: isHighlight ? const Color(0xFF1E90FF) : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableDeductions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Available Deductions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...deductionTypes.map((type) => _buildDeductionCard(type)).toList(),
      ],
    );
  }

  Widget _buildDeductionCard(Map<String, dynamic> type) {
    String typeId = type['id'];
    String name = type['name'] ?? '';
    String code = type['code'] ?? '';
    double maxAmount = (type['max_amount'] ?? 0).toDouble();
    bool requiresProof = type['requires_proof'] ?? false;
    var declaration = deductionDeclarations[typeId];
    bool isClaimed = (declaration?['is_claimed'] ?? false);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: _cardDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: isClaimed,
                  onChanged: !canDeclare
                      ? null
                      : (value) async {
                    await _onDeductionToggle(
                        typeId, value ?? false);
                  },
                  activeColor: const Color(0xFF1E90FF),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E90FF)
                                  .withOpacity(0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              code,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E90FF)),
                            ),
                          ),
                        ],
                      ),
                      if (maxAmount > 0)
                        Text(
                          'Max: ₹${NumberFormat('#,##,###').format(maxAmount)}',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF888888)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (isClaimed) ...[
              const SizedBox(height: 12),
              TextField(
                controller: amountControllers[typeId],
                enabled: canDeclare,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: false),
                onChanged: (v) => _onAmountOrNoteChanged(typeId),
                decoration:
                _inputDecoration('Declared Amount (₹)', prefixText: '₹ '),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesControllers[typeId],
                enabled: canDeclare,
                onChanged: (v) => _onAmountOrNoteChanged(typeId),
                maxLines: 2,
                decoration:
                _inputDecoration('Notes (Optional)', hint: 'Add note'),
              ),
              if (requiresProof) ...[
                const SizedBox(height: 12),
                const Text('Upload Proof (Required)',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (!isClaimed)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Text(
                      'Select deduction to upload proof',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),

                OutlinedButton.icon(
                  onPressed: (!isClaimed)
                      ? null
                      : () => _uploadProof(typeId),

                  icon: const Icon(Icons.upload_file),
                  label: const Text('Add Document'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                if (deductionProofs[typeId]?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 8),
                  ...deductionProofs[typeId]!
                      .map((proof) => _buildProofTile(proof))
                      .toList(),
                ],
              ]
            ],
            if ((declaration?['status'] ?? '') == 'submitted')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('Submitted',
                      style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold)),
                ),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildProofTile(Map<String, dynamic> proof) {
    String fileName = proof['file_name'] ?? '';
    int fileSize = proof['file_size'] ?? 0;
    return ListTile(
      dense: true,
      leading: const Icon(Icons.attach_file, size: 16),
      title: Text(fileName, style: const TextStyle(fontSize: 12)),
      subtitle: Text('${(fileSize / 1024).round()} KB'),
      trailing: IconButton(
        icon: const Icon(Icons.open_in_new, size: 16),
        onPressed: () {
          // optionally open document
        },
      ),
    );
  }
}
