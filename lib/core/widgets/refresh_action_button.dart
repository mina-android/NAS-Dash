import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RefreshActionButton extends StatefulWidget {
  final Future<void> Function() onRefresh;
  final String tooltip;

  const RefreshActionButton({
    super.key,
    required this.onRefresh,
    this.tooltip = 'Refresh',
  });

  @override
  State<RefreshActionButton> createState() => _RefreshActionButtonState();
}

class _RefreshActionButtonState extends State<RefreshActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    _controller.repeat();
    HapticFeedback.lightImpact();

    try {
      await widget.onRefresh();
    } catch (_) {
    } finally {
      if (mounted) {
        _controller.stop();
        _controller.reset();
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: widget.tooltip,
      onPressed: _isLoading ? null : _handleRefresh,
      icon: RotationTransition(
        turns: _controller,
        child: const Icon(Icons.refresh_rounded),
      ),
    );
  }
}
