// lib/widgets/refreshable_screen.dart
import 'package:flutter/material.dart';

/// A reusable mixin for any StatefulWidget screen to add:
///  - Skeleton loading on first load
///  - Pull-to-refresh functionality
///  - Auto-loading helpers
///
/// Usage inside your screen's State:
///   class _MyScreenState extends State<MyScreen>
///       with RefreshableScreen<MyScreen> {
///
///     @override
///     Future<void> loadData() async {
///        // fetch and assign state variables here
///     }
///
///     @override
///     void initState() {
///        super.initState();
///        startLoad();   // show skeleton and load data
///     }
///   }
mixin RefreshableScreen<T extends StatefulWidget> on State<T> {
  bool isLoading = true;
  bool isRefreshing = false;

  /// Screen MUST override this to fetch data.
  Future<void> loadData();

  /// Call inside initState() to show skeleton + load data.
  void startLoad() {
    _doLoad();
  }

  Future<void> _doLoad() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      await loadData();
    } catch (e, st) {
      debugPrint("RefreshableScreen load error: $e\n$st");
    }

    if (!mounted) return;
    setState(() {
      isLoading = false;
    });
  }

  /// Pull-to-refresh handler.
  Future<void> onRefresh() async {
    if (!mounted) return;

    setState(() {
      isRefreshing = true;
    });

    try {
      await loadData();
    } catch (e, st) {
      debugPrint("RefreshableScreen refresh error: $e\n$st");
    }

    if (!mounted) return;
    setState(() {
      isRefreshing = false;
    });
  }

  /// Builds a refreshable screen that shows:
  ///   - Skeleton while `isLoading == true`
  ///   - Real content (childBuilder) when loaded
  ///   - Supports pull-to-refresh at all times
  Widget buildRefreshable({
    required Widget skeleton,
    required Widget Function() childBuilder,
  }) {
    final fullHeight = MediaQuery.of(context).size.height;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: isLoading
          ? LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: skeleton,
            ),
          );
        },
      )
          : childBuilder(),
    );
  }
}
