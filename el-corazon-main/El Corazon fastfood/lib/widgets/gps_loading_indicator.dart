import 'package:flutter/material.dart';

/// GPS Loading Indicator Widget
/// Shows animated loading indicator while fetching GPS location
class GpsLoadingIndicator extends StatelessWidget {
  final String? message;
  final bool isLoading;
  final Color? color;

  const GpsLoadingIndicator({
    super.key,
    this.message,
    this.isLoading = true,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLoading) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(
                color ?? Colors.blue,
              ),
            ),
          ),
          if (message != null) ...[
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                message!,
                style: TextStyle(
                  color: color ?? Colors.blue,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact GPS indicator for inline use
class CompactGpsIndicator extends StatelessWidget {
  final bool isLoading;
  final Color color;

  const CompactGpsIndicator({
    super.key,
    this.isLoading = true,
    this.color = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: isLoading
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            )
          : Icon(
              Icons.location_on,
              color: color,
              size: 18,
            ),
    );
  }
}

/// Pulsing GPS icon animation
class PulsingGpsIcon extends StatefulWidget {
  final Color color;
  final double size;

  const PulsingGpsIcon({
    super.key,
    this.color = Colors.blue,
    this.size = 24,
  });

  @override
  State<PulsingGpsIcon> createState() => _PulsingGpsIconState();
}

class _PulsingGpsIconState extends State<PulsingGpsIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: Icon(
        Icons.gps_fixed,
        color: widget.color,
        size: widget.size,
      ),
    );
  }
}
