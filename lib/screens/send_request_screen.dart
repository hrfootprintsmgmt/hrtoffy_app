import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SendRequestScreen extends StatefulWidget {
  final String employeeEmail;
  const SendRequestScreen({super.key, required this.employeeEmail});

  @override
  State<SendRequestScreen> createState() => _SendRequestScreenState();
}

class _SendRequestScreenState extends State<SendRequestScreen> with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  String? managerId;
  String? managerName;
  String? employeeId;
  String? orgId;

  String recipientType = "manager";
  final TextEditingController subjectController = TextEditingController();
  final TextEditingController messageController = TextEditingController();

  bool loadingProfile = true;
  bool sending = false;
  String sendError = "";
  String fetchError = "";
  bool loadingRequests = false;

  late TabController _tabController;
  List<Map<String, dynamic>> requests = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    loadProfileAndRequests();
  }

  Future<void> loadProfileAndRequests() async {
    setState(() {
      loadingProfile = true;
      fetchError = "";
    });

    try {
      final emp = await supabase
          .from('employee_records')
          .select()
          .eq('email', widget.employeeEmail)
          .maybeSingle();

      setState(() {
        employeeId = emp?['id']?.toString();
        managerId = emp?['manager_id']?.toString();
        managerName = emp?['manager_name']?.toString();
        orgId = emp?['organization_id']?.toString();
        loadingProfile = false;
      });

      if (employeeId != null && employeeId!.isNotEmpty) {
        await fetchRequests();
      } else {
        setState(() {
          fetchError = "Employee ID (UUID) not found. Cannot fetch requests.";
        });
      }
    } catch (e) {
      setState(() {
        loadingProfile = false;
        fetchError = "Failed to fetch profile: $e";
      });
    }
  }

  Future<void> fetchRequests() async {
    setState(() {
      loadingRequests = true;
      fetchError = "";
    });
    try {
      if (employeeId == null || employeeId!.isEmpty) {
        setState(() {
          requests = [];
          loadingRequests = false;
        });
        return;
      }

      final resp = await supabase
          .from('support_requests')
          .select()
          .eq('employee_id', employeeId!)
          .order('created_at', ascending: false);

      setState(() {
        requests = (resp as List).cast<Map<String, dynamic>>();
        loadingRequests = false;
      });
    } catch (e) {
      setState(() {
        loadingRequests = false;
        requests = [];
        fetchError = "Could not fetch requests: $e";
      });
    }
  }

  Future<void> sendSupportRequest() async {
    final subject = subjectController.text.trim();
    final message = messageController.text.trim();

    if (subject.isEmpty || message.isEmpty) {
      setState(() {
        sendError = "Subject and message cannot be empty.";
      });
      return;
    }
    if ((recipientType == 'manager' && (managerId == null || managerId!.isEmpty)) ||
        employeeId == null || employeeId!.isEmpty ||
        orgId == null || orgId!.isEmpty) {
      setState(() {
        sendError = "Invalid manager/org/employee details.";
      });
      return;
    }

    setState(() {
      sending = true;
      sendError = "";
    });

    final recId = recipientType == 'manager' ? managerId! : "hr";
    final recType = recipientType;

    final payload = {
      "subject": subject,
      "message": message,
      "employee_id": employeeId,
      "organization_id": orgId,
      "manager_id": recType == "manager" ? recId : null,
      "recipient_type": recType,
      "status": "pending",
    };

    try {
      await supabase.from('support_requests').insert(payload);

      setState(() {
        sending = false;
      });

      subjectController.clear();
      messageController.clear();

      await fetchRequests();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Request sent successfully.")),
      );
    } catch (e) {
      setState(() {
        sending = false;
        sendError = "Failed to send request: $e";
      });
    }
  }

  @override
  void dispose() {
    subjectController.dispose();
    messageController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final managerDropdownValue = (managerName != null && managerName!.isNotEmpty)
        ? "Manager ($managerName)"
        : "Manager";

    return Scaffold(
      appBar: AppBar(title: Text("Send Request", style: theme.textTheme.headlineMedium)),
      body: loadingProfile
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: "Send Request"),
              Tab(text: "See Response"),
            ],
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.textTheme.bodySmall!.color,
            indicatorColor: theme.colorScheme.primary,
            labelStyle: theme.textTheme.bodyLarge!.copyWith(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: AbsorbPointer(
                    absorbing: loadingProfile || employeeId == null || orgId == null,
                    child: Opacity(
                      opacity: (loadingProfile || employeeId == null || orgId == null) ? 0.45 : 1,
                      child: Column(
                        children: [
                          Card(
                            margin: const EdgeInsets.only(bottom: 20),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Send Request", style: theme.textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 5),
                                  Text("Submit your queries or requests to your manager or HR team",
                                      style: theme.textTheme.bodyLarge),
                                  const Divider(),
                                  DropdownButtonFormField<String>(
                                    value: recipientType,
                                    items: [
                                      DropdownMenuItem(value: "manager", child: Text(managerDropdownValue, style: theme.textTheme.bodyLarge)),
                                      DropdownMenuItem(value: "hr", child: Text("HR Team", style: theme.textTheme.bodyLarge)),
                                    ],
                                    onChanged: (v) => setState(() { recipientType = v!; }),
                                    decoration: InputDecoration(
                                      labelText: "Send To",
                                      prefixIcon: Icon(Icons.person_outline, color: theme.colorScheme.primary),
                                      filled: true,
                                      fillColor: theme.cardColor,
                                    ),
                                  ),
                                  const SizedBox(height: 13),
                                  TextFormField(
                                    controller: subjectController,
                                    decoration: InputDecoration(
                                      labelText: "Subject",
                                      hintText: "Brief description of your request",
                                      filled: true,
                                      fillColor: theme.cardColor,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    style: theme.textTheme.bodyLarge,
                                  ),
                                  const SizedBox(height: 13),
                                  TextFormField(
                                    controller: messageController,
                                    decoration: InputDecoration(
                                      labelText: "Message",
                                      hintText: "Describe your request or query in detail...",
                                      filled: true,
                                      fillColor: theme.cardColor,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    minLines: 3,
                                    maxLines: 5,
                                    style: theme.textTheme.bodyLarge,
                                  ),
                                  const SizedBox(height: 15),
                                  if (sendError.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8.0),
                                      child: Text(sendError, style: theme.textTheme.bodyLarge!.copyWith(color: theme.colorScheme.error)),
                                    ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: sending ? null : sendSupportRequest,
                                          child: sending
                                              ? SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: theme.colorScheme.onPrimary,
                                            ),
                                          )
                                              : const Text("Send Request"),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Icon(Icons.send, color: theme.colorScheme.primary),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                loadingRequests
                    ? const Center(child: CircularProgressIndicator())
                    : fetchError.isNotEmpty
                    ? Center(child: Text(fetchError, style: theme.textTheme.bodyLarge!.copyWith(color: theme.colorScheme.error)))
                    : RefreshIndicator(
                  onRefresh: fetchRequests,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(18),
                    itemCount: requests.length,
                    itemBuilder: (ctx, idx) {
                      final req = requests[idx];
                      final isPending = req['status'] == 'pending';
                      final isResolved = req['status'] == 'resolved' ||
                          req['status'] == 'responded' ||
                          (req['response'] ?? '').toString().isNotEmpty;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.description_outlined, color: theme.colorScheme.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(req['subject'] ?? "",
                                        style: theme.textTheme.bodyLarge!.copyWith(fontWeight: FontWeight.bold)),
                                  ),
                                  if (isResolved)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text("Resolved",
                                          style: theme.textTheme.bodySmall!.copyWith(color: Colors.green.shade800)),
                                    )
                                  else if (isPending)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text("Pending", style: theme.textTheme.bodySmall!.copyWith(color: Colors.blue.shade800)),
                                    )
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(Icons.account_circle_outlined,
                                      size: 18, color: theme.colorScheme.secondary),
                                  const SizedBox(width: 6),
                                  Text("Sent to: ",
                                      style: theme.textTheme.bodyMedium),
                                  Text(
                                    req['recipient_type'] == "hr"
                                        ? "HR Team"
                                        : "Manager",
                                    style: theme.textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 14),
                                  Icon(Icons.schedule,
                                      size: 18, color: theme.colorScheme.secondary),
                                  const SizedBox(width: 4),
                                  Text(
                                    timeAgo(DateTime.parse(req['created_at'])),
                                    style: theme.textTheme.bodySmall!.copyWith(color: theme.colorScheme.secondary),
                                  )
                                ],
                              ),
                              if ((req['message'] ?? '').toString().isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text("Your Message:", style: theme.textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold)),
                                Text(req['message'] ?? "", style: theme.textTheme.bodyMedium),
                              ],
                              if ((req['response'] ?? "").toString().isNotEmpty) ...[
                                const SizedBox(height: 14),
                                Text("Response:", style: theme.textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold)),
                                Text(req['response'], style: theme.textTheme.bodyMedium),
                                Text(
                                  "Responded ${timeAgo(DateTime.parse(req['responded_at'] ?? req['updated_at'] ?? req['created_at']))}",
                                  style: theme.textTheme.bodySmall!.copyWith(color: theme.colorScheme.secondary),
                                )
                              ] else if (isPending) ...[
                                const SizedBox(height: 14),
                                Text(
                                  "Waiting for response from your ${req['recipient_type'] == "hr" ? "HR team" : "manager"}...",
                                  style: theme.textTheme.bodySmall!.copyWith(color: theme.colorScheme.secondary),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String timeAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays > 60) return "${(diff.inDays / 30).floor()} months ago";
    if (diff.inDays > 30) return "about 1 month ago";
    if (diff.inDays > 1) return "${diff.inDays} days ago";
    if (diff.inDays == 1) return "1 day ago";
    if (diff.inHours > 1) return "${diff.inHours} hours ago";
    if (diff.inHours == 1) return "1 hour ago";
    if (diff.inMinutes > 1) return "${diff.inMinutes} mins ago";
    if (diff.inMinutes == 1) return "1 min ago";
    return "few seconds ago";
  }
}
