import 'dart:ui';

import 'package:flutter/material.dart';

import 'camera_boo_page.dart';
import 'motion_boo_page.dart';

enum BooExperience { motion, camera }

class BooExperienceHubPage extends StatefulWidget {
  const BooExperienceHubPage({super.key});

  @override
  State<BooExperienceHubPage> createState() => _BooExperienceHubPageState();
}

class _BooExperienceHubPageState extends State<BooExperienceHubPage> {
  BooExperience _selection = BooExperience.motion;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String headline = _selection == BooExperience.motion
        ? 'Motion Boo'
        : 'Camera Boo';
    final String subhead = _selection == BooExperience.motion
        ? 'Tilt and move your device to coax Boo out of hiding.'
        : 'Let the front camera find your face so Boo can react.';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: <Widget>[
          const _LiquidGlassBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Boo Lab',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    headline,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subhead,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _ExperienceToggle(
                    selection: _selection,
                    onChanged: (BooExperience experience) {
                      if (_selection != experience) {
                        setState(() {
                          _selection = experience;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: _ExperienceStage(selection: _selection),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExperienceStage extends StatelessWidget {
  const _ExperienceStage({required this.selection});

  final BooExperience selection;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(36),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    Colors.white.withOpacity(0.08),
                    Colors.white.withOpacity(0.02),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
              child: const SizedBox(),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withOpacity(0.12),
                  width: 1.2,
                ),
                borderRadius: BorderRadius.circular(36),
              ),
            ),
          ),
          _ExperienceLayer(
            visible: selection == BooExperience.motion,
            child: MotionBooExperience(active: selection == BooExperience.motion),
          ),
          _ExperienceLayer(
            visible: selection == BooExperience.camera,
            child: CameraBooExperience(active: selection == BooExperience.camera),
          ),
        ],
      ),
    );
  }
}

class _ExperienceLayer extends StatelessWidget {
  const _ExperienceLayer({
    required this.visible,
    required this.child,
  });

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
        child: IgnorePointer(
          ignoring: !visible,
          child: child,
        ),
      ),
    );
  }
}

class _ExperienceToggle extends StatelessWidget {
  const _ExperienceToggle({
    required this.selection,
    required this.onChanged,
  });

  final BooExperience selection;
  final ValueChanged<BooExperience> onChanged;

  @override
  Widget build(BuildContext context) {
    final BooExperience current = selection;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.18), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Row(
          children: BooExperience.values.map((BooExperience value) {
            final bool isActive = value == current;
            final String label = value == BooExperience.motion
                ? 'Motion'
                : 'Camera';
            return Expanded(
              child: _ToggleButton(
                active: isActive,
                label: label,
                onPressed: () => onChanged(value),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.active,
    required this.label,
    required this.onPressed,
  });

  final bool active;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: active ? Colors.white.withOpacity(0.22) : Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        boxShadow: active
            ? const <BoxShadow>[
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ]
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(active ? 0.95 : 0.6),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LiquidGlassBackground extends StatelessWidget {
  const _LiquidGlassBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF04050F),
            Color(0xFF091427),
            Color(0xFF132C4A),
          ],
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: -120,
            left: -40,
            child: _GlowOrb(
              size: 320,
              colors: <Color>[
                const Color(0xFF6B7CFF).withOpacity(0.65),
                const Color(0xFFB57CFF).withOpacity(0.25),
              ],
            ),
          ),
          Positioned(
            bottom: -100,
            right: -60,
            child: _GlowOrb(
              size: 280,
              colors: <Color>[
                const Color(0xFF65FFC5).withOpacity(0.55),
                const Color(0xFF3BA9FF).withOpacity(0.3),
              ],
            ),
          ),
          Positioned(
            top: 180,
            right: -120,
            child: _GlowOrb(
              size: 240,
              colors: <Color>[
                const Color(0xFFFF66B2).withOpacity(0.4),
                const Color(0xFFFFC66C).withOpacity(0.2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.size,
    required this.colors,
  });

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: colors,
        ),
      ),
    );
  }
}
