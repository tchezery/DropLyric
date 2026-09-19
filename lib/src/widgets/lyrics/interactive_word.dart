import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Palavra interativa sem background:
///
/// **Desconhecida** → texto normal, 100% visível/nítido para aprender.
/// **Conhecida** → apenas opaco (baixa opacidade/esmaecido), indicando domínio.
/// **Linha ativa** → tipografia maior e destacada.
class InteractiveWord extends StatelessWidget {
  final String word;
  final bool isKnown;
  final VoidCallback onToggle;
  final void Function(String word, TapDownDetails? details)? onWordPressed;
  final bool isActiveLine;
  final bool isLightMode;
  final bool isManualMode;
  final Color? customColor;
  final String fontFamily;

  const InteractiveWord({
    super.key,
    required this.word,
    required this.isKnown,
    required this.onToggle,
    this.onWordPressed,
    this.isActiveLine = false,
    this.isLightMode = false,
    this.isManualMode = false,
    this.customColor,
    this.fontFamily = 'monospace',
  });

  @override
  Widget build(BuildContext context) {
    // Quando a linha está ativa com o marca-texto amarelo, a cor do texto é tinta escura
    // Quando inativa, o texto é branco conforme solicitado pelo usuário
    final Color textColor;
    if (isActiveLine) {
      textColor = const Color(0xFF141F17);
    } else {
      textColor = customColor ?? (isLightMode ? Colors.black : Colors.white);
    }

    final double opacity;
    if (isKnown) {
      opacity = isActiveLine ? 0.40 : 0.30;
    } else {
      opacity = 1.0;
    }

    final fontSize = isActiveLine ? 16.5 : 15.0;
    final fontWeight = isActiveLine ? FontWeight.w800 : FontWeight.w500;

    TapDownDetails? tapDetails;

    return GestureDetector(
      onTapDown: (details) => tapDetails = details,
      onTap: () {
        HapticFeedback.selectionClick();
        onToggle();
      },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        if (onWordPressed != null) {
          onWordPressed!(word, tapDetails);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1.5, vertical: 1.0),
        child: Text(
          word,
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: textColor.withValues(alpha: opacity),
            height: 1.45,
          ),
        ),
      ),
    );
  }
}

/// Token de pontuação ou espaço, sempre exibido como conteúdo já dominado.
class PunctuationSpan extends StatelessWidget {
  final String text;
  final bool isActiveLine;
  final bool isLightMode;
  final bool isManualMode;
  final Color? customColor;
  final String fontFamily;

  const PunctuationSpan({
    super.key,
    required this.text,
    this.isActiveLine = false,
    this.isLightMode = false,
    this.isManualMode = false,
    this.customColor,
    this.fontFamily = 'monospace',
  });

  @override
  Widget build(BuildContext context) {
    final Color textColor;
    if (isActiveLine) {
      textColor = const Color(0xFF141F17);
    } else {
      textColor = customColor ?? (isLightMode ? Colors.black : Colors.white);
    }

    final fontSize = isActiveLine ? 16.5 : 15.0;
    final fontWeight = isActiveLine ? FontWeight.w800 : FontWeight.w500;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.0),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: textColor.withValues(alpha: isActiveLine ? 0.40 : 0.30),
          height: 1.45,
        ),
      ),
    );
  }
}
