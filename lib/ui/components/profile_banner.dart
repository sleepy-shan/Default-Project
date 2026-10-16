import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/design_tokens.dart';
import '../../state/profile_prefs.dart';

/// Profile banner with a legible scrim and an optional overlay [child].
///
/// - [imageUrl] == null  → animated *komorebi* canvas (dappled light).
/// - [imageUrl] != null  → that image. GIF / animated WebP play natively;
///   still images get a slow Ken-Burns drift. Both fall back to komorebi
///   if the image fails to load.
///
/// Motion is skipped entirely when the OS asks for reduced motion.
class ProfileBanner extends StatelessWidget {
  const ProfileBanner({
    required this.height,
    this.imageUrl,
    this.isCustomLink = false,
    this.child,
    super.key,
  });

  final double height;
  final String? imageUrl;

  /// User-pasted links may live on hosts without CORS headers; those are
  /// loaded through an <img> element on web so they still show up.
  final bool isCustomLink;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(Tokens.radiusXl),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: url == null
                  ? const _KomorebiCanvas()
                  : _DriftingImage(url: url, htmlFallback: isCustomLink),
            ),
            // Keeps white text readable on any artwork.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.35, 1],
                  colors: [Color(0x00000000), Color(0x99000000)],
                ),
              ),
            ),
            ?child,
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Still / animated image banner
// ---------------------------------------------------------------------------

class _DriftingImage extends StatefulWidget {
  const _DriftingImage({required this.url, required this.htmlFallback});

  final String url;
  final bool htmlFallback;

  @override
  State<_DriftingImage> createState() => _DriftingImageState();
}

class _DriftingImageState extends State<_DriftingImage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 36),
  );

  /// GIFs already move; drifting them too would feel seasick.
  bool get _alreadyAnimated {
    final path = (Uri.tryParse(widget.url)?.path ?? widget.url).toLowerCase();
    return path.endsWith('.gif');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce || _alreadyAnimated) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _DriftingImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) didChangeDependencies();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = Image.network(
      widget.url,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      webHtmlElementStrategy: widget.htmlFallback
          ? WebHtmlElementStrategy.fallback
          : WebHtmlElementStrategy.never,
      errorBuilder: (context, error, stack) => const _KomorebiCanvas(),
    );
    return AnimatedBuilder(
      animation: _controller,
      child: image,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Transform.scale(
          scale: 1.08 + 0.06 * t,
          alignment: Alignment(-0.35 + 0.7 * t, 0),
          child: child,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Komorebi: sunlight through leaves
// ---------------------------------------------------------------------------

class _Spot {
  const _Spot({
    required this.x,
    required this.y,
    required this.size,
    required this.phase,
    required this.speed,
    required this.warm,
    required this.angle,
  });

  final double x; // 0..1 of width
  final double y; // 0..1 of height
  final double size; // fraction of height
  final double phase; // radians
  final int speed; // whole numbers keep the loop seamless
  final double warm; // 0 = mist, 1 = sun
  final double angle;
}

final List<_Spot> _spots = List.generate(11, (i) {
  final r = math.Random(i * 97 + 13);
  return _Spot(
    x: 0.04 + r.nextDouble() * 0.92,
    y: 0.12 + r.nextDouble() * 0.76,
    size: 0.28 + r.nextDouble() * 0.34,
    phase: r.nextDouble() * math.pi * 2,
    speed: 1 + r.nextInt(3),
    warm: r.nextDouble(),
    angle: (r.nextDouble() - 0.5) * 1.2,
  );
});

class _KomorebiCanvas extends StatefulWidget {
  const _KomorebiCanvas();

  @override
  State<_KomorebiCanvas> createState() => _KomorebiCanvasState();
}

class _KomorebiCanvasState extends State<_KomorebiCanvas>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 48),
    value: 0.18, // a pleasant still frame for reduced-motion users
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _KomorebiPainter(_controller),
      child: const SizedBox.expand(),
    );
  }
}

class _KomorebiPainter extends CustomPainter {
  _KomorebiPainter(this.animation) : super(repaint: animation);

  final Animation<double> animation;

  static const _base = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0B2B28), Color(0xFF0E5A50), Color(0xFF0A1F1D)],
  );

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..shader = _base.createShader(rect));

    final t = animation.value * math.pi * 2;
    final paint = Paint();
    for (final s in _spots) {
      final sway = math.sin(t * s.speed + s.phase);
      final bob = math.cos(t * s.speed + s.phase * 1.3);
      final pulse = 0.5 + 0.5 * math.sin(t * s.speed * 2 + s.phase * 1.7);
      final center = Offset(
        s.x * size.width + sway * size.width * 0.035,
        s.y * size.height + bob * size.height * 0.09,
      );
      final radius = s.size * size.height * (0.92 + 0.16 * pulse);
      paint
        ..color = Color.lerp(
          Tokens.mist,
          Tokens.sun,
          s.warm,
        )!.withValues(alpha: 0.07 + 0.13 * pulse)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.45);
      canvas
        ..save()
        ..translate(center.dx, center.dy)
        ..rotate(s.angle + sway * 0.12)
        ..drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: radius * 2.3,
            height: radius * 1.35,
          ),
          paint,
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(covariant _KomorebiPainter oldDelegate) =>
      oldDelegate.animation != animation;
}

// ---------------------------------------------------------------------------
// Editor
// ---------------------------------------------------------------------------

/// Lets the user choose where the profile banner comes from.
Future<void> showBannerEditor(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => const _BannerEditor(),
  );
}

class _BannerEditor extends ConsumerStatefulWidget {
  const _BannerEditor();

  @override
  ConsumerState<_BannerEditor> createState() => _BannerEditorState();
}

class _BannerEditorState extends ConsumerState<_BannerEditor> {
  late BannerSource _source;
  late final TextEditingController _url;
  String? _error;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(profileBannerProvider);
    _source = prefs.source;
    _url = TextEditingController(text: prefs.url ?? '');
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_source == BannerSource.custom && !isValidBannerUrl(_url.text)) {
      setState(() => _error = 'Paste a link that starts with https://');
      return;
    }
    await ref
        .read(profileBannerProvider.notifier)
        .save(_source, url: _url.text);
    if (mounted) Navigator.of(context).pop();
  }

  static const _details = {
    BannerSource.anilist: (
      Icons.link_rounded,
      'Uses the banner on your AniList profile. A GIF banner keeps '
          'animating here.',
    ),
    BannerSource.komorebi: (
      Icons.wb_twilight_rounded,
      'Slow, drifting sunlight. Works without an account or an image.',
    ),
    BannerSource.custom: (
      Icons.image_outlined,
      'Any image, GIF or animated WebP from the web.',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AlertDialog(
      title: const Text('Profile banner'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final source in BannerSource.values)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  selected: _source == source,
                  leading: Icon(_details[source]!.$1),
                  title: Text(
                    source.label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(_details[source]!.$2),
                  trailing: _source == source
                      ? Icon(Icons.check_circle_rounded, color: scheme.primary)
                      : null,
                  onTap: () => setState(() {
                    _source = source;
                    _error = null;
                  }),
                ),
              if (_source == BannerSource.custom) ...[
                const SizedBox(height: Tokens.space8),
                TextField(
                  controller: _url,
                  keyboardType: TextInputType.url,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Image, GIF or WebP link',
                    hintText: 'https://…',
                    errorText: _error,
                  ),
                  onSubmitted: (_) => _save(),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save banner')),
      ],
    );
  }
}
