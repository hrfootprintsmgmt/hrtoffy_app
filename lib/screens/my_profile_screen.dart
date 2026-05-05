// my_profile_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../widgets/skeleton_layouts.dart';
import '../widgets/refreshable_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_filex/open_filex.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../widgets/app_drawer.dart';
import '../widgets/bottom_nav_toffy_button.dart';

import 'dashboard_screen.dart';
import 'leaves_screen.dart';
import 'attendance_screen.dart';
import 'payslip_screen.dart';
import '../widgets/drawer_route.dart';
import 'package:flutter/foundation.dart';



// 🔧 FIX 1: Update MyProfileScreen widget definition

class MyProfileScreen extends StatefulWidget {
  final String email;
  final Map<String, dynamic> userData;
  final Future<Map<String, dynamic>> Function() fetchHrmsContext;

  const MyProfileScreen({
    Key? key,
    required this.email,
    required this.userData,
    required this.fetchHrmsContext,
  }) : super(key: key);

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}


class _MyProfileScreenState extends State<MyProfileScreen>
    with TickerProviderStateMixin,
        AutomaticKeepAliveClientMixin,
        RefreshableScreen<MyProfileScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();


  int _bottomTabIndex = 0;


  Map<String, dynamic>? _emp;
  Map<String, dynamic>? _manager;
  Map<String, dynamic>? _reviewer;
  Map<String, dynamic>? _org;
  String? _companyLogoUrl;

  TabController? _tabController;
  final ImagePicker _picker = ImagePicker();

  bool _hasDependenciesRunOnce = false;

  @override
  bool get wantKeepAlive => true;


  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);

    _tabController!.addListener(() {
      if (mounted) setState(() {});
    });

    startLoad(); // keep this as it is
  }



  // when screen becomes visible again in navigation tree, reload fresh data
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasDependenciesRunOnce) {
      _hasDependenciesRunOnce = true; // skip first time (initState already loaded)
      return;
    }
    startLoad(); // reload data when coming back
  }

  // Utility: detect invalid avatar URL object names (no hard-coded domains)
  bool isInvalidAvatarUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    try {
      final uri = Uri.parse(url);
      final path = uri.path; // e.g. /storage/v1/object/public/avatars/xyz.jpg
      if (!path.contains('/avatars/')) return false;
      final segs = uri.pathSegments;
      if (segs.isEmpty) return false;
      final last = segs.last.toString();
      if (last.contains('@') || last.contains('%40') || last.contains(' ')) {
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> loadData() async {
    try {
      final empResp = await supabase
          .from('employee_records')
          .select()
          .eq('email', widget.email)
          .maybeSingle();

      if (empResp == null) {
        setState(() {
          _emp = null;
          _org = null;
          _manager = null;
          _reviewer = null;
          _companyLogoUrl = null;
        });
        return;
      }

      final Map<String, dynamic> emp = Map<String, dynamic>.from(empResp);

      // --- Organization info ---
      String? orgId = emp['organization_id']?.toString();
      Map<String, dynamic>? org;
      String? companyLogoUrl;
      if (orgId != null && orgId.isNotEmpty) {
        final orgResp = await supabase
            .from('organizations')
            .select()
            .eq('id', orgId)
            .maybeSingle();
        if (orgResp != null) org = Map<String, dynamic>.from(orgResp);

        if (org != null &&
            org['logo_url'] != null &&
            org['logo_url'].toString().isNotEmpty) {
          companyLogoUrl = org['logo_url'].toString();
        } else {
          try {
            final files =
            await supabase.storage.from('company-logos').list(path: orgId);
            if (files.isNotEmpty) {
              final fileObj = files.firstWhere(
                    (f) {
                  final n =
                      (f as Map)['name']?.toString().toLowerCase() ?? '';
                  return n.endsWith('.png') ||
                      n.endsWith('.jpg') ||
                      n.endsWith('.jpeg') ||
                      n.endsWith('.webp');
                },
                orElse: () => files.first,
              );
              final fileName = (fileObj as Map)['name'];
              if (fileName != null) {
                companyLogoUrl = supabase.storage
                    .from('company-logos')
                    .getPublicUrl('$orgId/$fileName');
              }
            }
          } catch (_) {
            companyLogoUrl = null;
          }
        }
      }

      // Manager
      Map<String, dynamic>? manager;
      if (emp['manager_id'] != null) {
        final m = await supabase
            .from('employee_records')
            .select()
            .eq('id', emp['manager_id'])
            .maybeSingle();
        if (m != null) manager = Map<String, dynamic>.from(m);
      } else if (emp['manager_email'] != null) {
        final m = await supabase
            .from('employee_records')
            .select()
            .eq('email', emp['manager_email'])
            .maybeSingle();
        if (m != null) manager = Map<String, dynamic>.from(m);
      }

      // Reviewer
      Map<String, dynamic>? reviewer;
      if (emp['reviewer_id'] != null) {
        final r = await supabase
            .from('employee_records')
            .select()
            .eq('id', emp['reviewer_id'])
            .maybeSingle();
        if (r != null) reviewer = Map<String, dynamic>.from(r);
      } else if (emp['reviewer_email'] != null) {
        final r = await supabase
            .from('employee_records')
            .select()
            .eq('email', emp['reviewer_email'])
            .maybeSingle();
        if (r != null) reviewer = Map<String, dynamic>.from(r);
      }

      setState(() {
        _emp = emp;
        _org = org;
        _companyLogoUrl = companyLogoUrl;
        _manager = manager;
        _reviewer = reviewer;
      });

      debugPrint('✅ Profile data loaded successfully.');
    } catch (e, st) {
      debugPrint('fetchAll error: $e\n$st');
    }
  }

  Map<String, String> _digitalIdData() {
    return {
      'name': (_emp?['full_name'] ?? '-').toString(),
      'designation': (_emp?['designation'] ?? '-').toString(),
      'dob': _formatDate(_emp?['date_of_birth']),
      'blood': (_emp?['blood_group'] ?? '-').toString(),
      'doj': _formatDate(_emp?['date_of_joining']),
      'phone': (_emp?['phone'] ?? '-').toString(),
      'company': (_org?['name'] ?? '-').toString(),
      'location': (_org?['location'] ?? '-').toString(),
    };
  }


  // Upload avatar (sanitized + overwrite safe)
  Future<void> _pickAndUploadAvatar() async {
    try {
      if (_emp == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Employee record not loaded yet.')),
        );
        return;
      }

      final XFile? result = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (result == null) return;

      final bytes = await result.readAsBytes();

      // Sanitize filename
      String baseName;
      if (_emp?['employee_id'] != null &&
          _emp!['employee_id'].toString().isNotEmpty) {
        baseName = _emp!['employee_id'].toString();
      } else {
        baseName = (_emp?['email'] ?? widget.email).toString();
      }
      baseName = baseName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final fileName = '$baseName.jpg';

      // per-user folder
      final folderPath = supabase.auth.currentUser?.id ?? 'public';
      final filePath = '$folderPath/$fileName';

      debugPrint('Uploading avatar to: $filePath');

      // Upload to Supabase Storage (avatars bucket)
      final res = await supabase.storage.from('avatars').uploadBinary(
        filePath,
        bytes,
        fileOptions:
        const FileOptions(contentType: 'image/jpeg', upsert: true),
      );

      debugPrint('Upload result: $res');

      // Get public URL
      final publicUrl =
      supabase.storage.from('avatars').getPublicUrl(filePath);

      // Update employee record with new avatar URL
      await supabase
          .from('employee_records')
          .update({'avatar_url': publicUrl})
          .eq('id', _emp?['id']);

      await onRefresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Profile photo updated')),
      );
    } catch (e, st) {
      debugPrint('❌ upload avatar error: $e\n$st');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to upload avatar')),
      );
    }
  }

  // Delete avatar safely
  Future<void> _confirmAndDeleteAvatar() async {
    if (_emp == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Employee record not loaded yet.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Profile Photo'),
        content:
        const Text('Are you sure you want to delete your profile photo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      String baseName;
      if (_emp?['employee_id'] != null &&
          _emp!['employee_id'].toString().isNotEmpty) {
        baseName = _emp!['employee_id'].toString();
      } else {
        baseName = (_emp?['email'] ?? widget.email)
            .toString()
            .replaceAll('@', '_')
            .replaceAll('.', '_');
      }
      final fileName = '$baseName.jpg';

      final folderPath = supabase.auth.currentUser?.id ?? 'public';
      final filePath = '$folderPath/$fileName';

      await supabase.storage.from('avatars').remove([filePath]);

      await supabase
          .from('employee_records')
          .update({'avatar_url': null})
          .eq('id', _emp?['id']);

      await onRefresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo deleted successfully')),
      );
    } catch (e) {
      debugPrint('delete avatar error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete profile photo')),
      );
    }
  }

  Future<void> _generateAndSavePdfDirectly() async {
    setState(() => isLoading = true);

    try {
      final data = _digitalIdData();
      final doc = pw.Document();

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(360, 520),
          build: (_) => pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.blue),
              borderRadius: pw.BorderRadius.circular(14),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  data['company']!,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Divider(),

                pw.SizedBox(height: 12),
                pw.Container(
                  width: 64,
                  height: 64,
                  alignment: pw.Alignment.center,
                  decoration: pw.BoxDecoration(
                    shape: pw.BoxShape.circle,
                    border: pw.Border.all(color: PdfColors.grey),
                  ),
                  child: pw.Text(
                    data['name']!.isNotEmpty
                        ? data['name']![0].toUpperCase()
                        : '',
                    style: const pw.TextStyle(fontSize: 28),
                  ),
                ),


                pw.SizedBox(height: 10),
                pw.Text(
                  data['name']!,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  data['designation']!,
                  style: pw.TextStyle(color: PdfColors.blue),
                ),

                pw.Divider(),
                _pdfRow('DOB', data['dob']!),
                _pdfRow('Blood Group', data['blood']!),
                _pdfRow('DOJ', data['doj']!),
                _pdfRow('Mobile', data['phone']!),
              ],
            ),
          ),
        ),
      );


      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/ID_Card_${data['name']}.pdf');
      await file.writeAsBytes(await doc.save());

      await OpenFilex.open(file.path);
    } catch (e) {
      debugPrint('❌ PDF error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to generate digital ID')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 4,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Expanded(
            flex: 6,
            child: pw.Text(value),
          ),
        ],
      ),
    );
  }




  Future<pw.MemoryImage?> _loadNetworkImage(String? url) async {
    if (url == null || url.isEmpty) return null;
    try {
      final bytes = await HttpClient()
          .getUrl(Uri.parse(url))
          .then((r) => r.close())
          .then((r) => consolidateHttpClientResponseBytes(r));
      return pw.MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }



  String _formatDate(dynamic raw) {
    try {
      if (raw == null) return '-';
      DateTime dt;
      if (raw is DateTime) {
        dt = raw;
      } else {
        dt = DateTime.parse(raw.toString());
      }
      return DateFormat('yyyy-MM-dd').format(dt);
    } catch (e) {
      return raw?.toString() ?? '-';
    }
  }

  Widget _infoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value ?? '-',
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileDetails() {
    final name = (_emp?['full_name'] ?? '-').toString();
    final designation = (_emp?['designation'] ?? '-').toString();
    final empId = (_emp?['employee_id'] ?? '-').toString();
    final email = (_emp?['email'] ?? '-').toString();
    final phone = (_emp?['phone'] ?? '-').toString();
    final blood = (_emp?['blood_group'] ?? '-').toString();
    final dob = _formatDate(_emp?['date_of_birth']);
    final doj = _formatDate(_emp?['date_of_joining']);
    final orgName = (_org?['name'] ?? '-').toString();
    final orgLocation = (_org?['location'] ?? '-').toString();
    final managerName =
        _manager?['full_name']?.toString() ?? _emp?['manager_name']?.toString();
    final managerEmail =
        _manager?['email']?.toString() ?? _emp?['manager_email']?.toString();
    final reviewerName =
        _reviewer?['full_name']?.toString() ??
            _emp?['reviewer_name']?.toString();
    final reviewerEmail =
        _reviewer?['email']?.toString() ??
            _emp?['reviewer_email']?.toString();

    return SingleChildScrollView(
      child: Column(
        children: [
          webCard(
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    (_emp?['avatar_url'] != null &&
                        _emp!['avatar_url'].toString().isNotEmpty)
                        ? CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: CachedNetworkImageProvider(
                        _emp!['avatar_url'],
                      ),
                      onBackgroundImageError: (_, __) {
                        setState(() => _emp?['avatar_url'] = null);
                      },
                    )
                        : CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.grey.shade200,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    // --- Edit & Delete Buttons ---
                    Positioned(
                      right: -6,
                      bottom: -6,
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: _pickAndUploadAvatar,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: SvgPicture.asset(
                                  'assets/icons/edit.svg',
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: _confirmAndDeleteAvatar,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: SvgPicture.asset(
                                  'assets/icons/delete.svg',
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  ],
                ),

                const SizedBox(width: 14),

                // --- Name + Designation ---
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        designation,
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          webCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BASIC INFORMATION',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),

                _infoRow('Employee ID', empId),
                _infoRow('Email', email),
                _infoRow('Phone', phone),
                _infoRow('Blood Group', blood),
                _infoRow('Date of Birth', dob),
                _infoRow('Date of Joining', doj),
              ],
            ),
          ),
          webCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'WORK INFORMATION',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),

                _infoRow('Department', _emp?['department']?.toString()),
                _infoRow('Designation', designation),
                _infoRow('Organization', orgName),
                _infoRow('Organization Location', orgLocation),
              ],
            ),
          ),

          webCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BASIC INFORMATION',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _infoRow('Employee ID', empId),
                _infoRow('Email', email),
                _infoRow('Phone', phone),
                _infoRow('Blood Group', blood),
                _infoRow('Date of Birth', dob),
                _infoRow('Date of Joining', doj),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallLabelValue(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  Widget _buildDigitalIdFront({required double width}) {
    final name = (_emp?['full_name'] ?? '-').toString();
    final designation = (_emp?['designation'] ?? '-').toString();
    final empId = (_emp?['employee_id'] ?? '-').toString();
    final dob = _formatDate(_emp?['date_of_birth']);
    final blood = (_emp?['blood_group'] ?? '-').toString();
    final doj = _formatDate(_emp?['date_of_joining']);
    final phone = (_emp?['phone'] ?? '-').toString();

    return RepaintBoundary(

      child: Container(
        width: width,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.blueAccent, width: 1.2),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
          ],
        ),
        child: Column(
          children: [
            // 🔹 ORGANIZATION LOGO
            if (_companyLogoUrl != null)
              SizedBox(
                height: 40,
                child: CachedNetworkImage(
                  imageUrl: _companyLogoUrl!,
                  fit: BoxFit.contain,
                  errorWidget: (_, __, ___) => const SizedBox(height: 40),
                ),
              ),


            const SizedBox(height: 8),
            const Divider(),

            // 🔹 AVATAR
            const SizedBox(height: 10),
            CircleAvatar(
              radius: 36,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: (_emp?['avatar_url'] != null &&
                  _emp!['avatar_url'].toString().isNotEmpty)
                  ? CachedNetworkImageProvider(_emp!['avatar_url'])
                  : null,
              child: (_emp?['avatar_url'] == null ||
                  _emp!['avatar_url'].toString().isEmpty)
                  ? Text(
                name.isNotEmpty ? name[0].toUpperCase() : '',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
              )
                  : null,
            ),

            const SizedBox(height: 8),

            // 🔹 NAME + DESIGNATION
            Text(
              name,
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              designation,
              style: GoogleFonts.montserrat(
                fontSize: 14,
                color: Colors.blueAccent,
              ),
            ),

            const SizedBox(height: 12),
            const Divider(),

            _idRow('DOB', dob),
            _idRow('Blood Group', blood),
            _idRow('DOJ', doj),
            _idRow('Mobile', phone),
          ],
        ),
      ),
    );
  }
  Widget _idRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(value),
          ),
        ],
      ),
    );
  }



  Widget _buildDigitalIdBack({required double width}) {
    final company = (_org?['name'] ?? '-').toString();
    final location = (_org?['location'] ?? '-').toString();

    return RepaintBoundary(

      child: Container(
        width: width,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.blueAccent, width: 1.2),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              company,
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),

            const Text(
              'Corporate Office',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(location),

            const SizedBox(height: 14),

            const Text(
              'Emergency Contact',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Text('Contact not available'),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    if (_tabController == null) {
      return const SizedBox.shrink();
    }

    super.build(context);

    final cardWidth = MediaQuery.of(context).size.width - 40;

    return Scaffold(
      key: _scaffoldKey,

      endDrawer: AppDrawer(
        userEmail: widget.email,
        userData: widget.userData,                 // ✅ FIX
        fetchHrmsContext: widget.fetchHrmsContext, // ✅ FIX
        currentRoute: DrawerRoute.profile,

        companyLogoUrl: null,
      ),

      appBar: AppBar(
        title: const Text('My Profile'),
      ),

      // 🔥 BODY + TOFFY OVERLAY
      body: Stack(
        children: [
          buildRefreshable(
            skeleton: const SkeletonProfile(),
            childBuilder: () {
              if (_emp == null) {
                return const Center(child: Text("Failed to load profile."));
              }

              return Column(
                children: [
                  Container(
                    margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      controller: _tabController!,

                      tabs: const [
                        Tab(text: 'Profile Details'),
                        Tab(text: 'Digital ID'),
                      ],
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.grey,
                      indicator: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),

                  Expanded(
                    child: IndexedStack(
                      index: _tabController?.index ?? 0,

                      children: [
                        // TAB 0 — PROFILE DETAILS
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: _buildProfileDetails(),
                        ),

                        // TAB 1 — DIGITAL ID (ALWAYS RENDERED)
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              _buildDigitalIdFront(width: cardWidth),
                              const SizedBox(height: 14),
                              _buildDigitalIdBack(width: cardWidth),
                              const SizedBox(height: 16),

                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                ],
              );
            },
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
                  email: widget.email,
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
  Widget webCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12), // Light border like web
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}
