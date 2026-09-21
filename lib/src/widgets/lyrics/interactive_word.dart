import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme.dart';

/// Palavra interativa estilo Apple Music:
///
/// **Desconhecida** → 100% nítida para aprendizado.
/// **Conhecida** → esmaecida (baixa opacidade), indicando domínio.
/// **Linha ativa** → tipografia Apple SF Pro destacada.
class InteractiveWord extends StatelessWidget {
  final String word;
  final bool isKnown;
  final VoidCallback onToggle;
  final void Function(String word, TapDownDetails? details)? onWordPressed;
  final bool isActiveLine;
  final bool isLightMode;
  final bool isManualMode;
  final bool isFluentMode;
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
    this.isFluentMode = false,
    this.customColor,
    this.fontFamily = AppTheme.fontSF,
  });

  @override
  Widget build(BuildContext context) {
    // Quando a linha está ativa com fundo amarelo, a cor do texto deve ser sempre escura (Colors.black)
    // para garantir contraste perfeito tanto no Dark Mode quanto no Light Mode.
    final Color textColor;
    if (isActiveLine) {
      textColor = customColor ?? Colors.black;
    } else {
      textColor = customColor ?? (isLightMode ? Colors.black : Colors.white);
    }

    final double opacity;
    if (isActiveLine) {
      if (isFluentMode) {
        opacity = 1.0;
      } else {
        // Na linha amarela ativa:
        // - Já clicada (conhecida): 0.38 (perfeitamente legível sobre o amarelo, mas visivelmente esmaecida)
        // - Não clicada (desconhecida): 1.0 (preto sólido intenso)
        opacity = isKnown ? 0.38 : 1.0;
      }
    } else {
      if (isFluentMode) {
        opacity = isLightMode ? 0.60 : 0.55;
      } else {
        opacity = isKnown
            ? (isLightMode ? 0.38 : 0.32)
            : (isLightMode ? 0.95 : 0.90);
      }
    }

    final fontSize = isActiveLine ? 18.0 : 16.0;
    final fontWeight = isActiveLine
        ? (isKnown && !isFluentMode ? FontWeight.w500 : FontWeight.w800)
        : (isKnown && !isFluentMode ? FontWeight.w400 : FontWeight.w600);

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
        padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 1.5),
        child: Text(
          word,
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: textColor.withValues(alpha: opacity),
            letterSpacing: -0.3,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

/// Token de pontuação ou espaço.
class PunctuationSpan extends StatelessWidget {
  final String text;
  final bool isActiveLine;
  final bool isLightMode;
  final bool isManualMode;
  final bool isFluentMode;
  final Color? customColor;
  final String fontFamily;

  const PunctuationSpan({
    super.key,
    required this.text,
    this.isActiveLine = false,
    this.isLightMode = false,
    this.isManualMode = false,
    this.isFluentMode = false,
    this.customColor,
    this.fontFamily = AppTheme.fontSF,
  });

  @override
  Widget build(BuildContext context) {
    final Color textColor;
    if (isActiveLine) {
      textColor = customColor ?? Colors.black;
    } else {
      textColor = customColor ?? (isLightMode ? Colors.black : Colors.white);
    }

    final double opacity;
    if (isActiveLine) {
      opacity = 1.0;
    } else {
      opacity = isFluentMode
          ? (isLightMode ? 0.60 : 0.55)
          : (isLightMode ? 0.40 : 0.35);
    }
    final fontSize = isActiveLine ? 18.0 : 16.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: fontSize,
          fontWeight: isActiveLine ? FontWeight.w600 : FontWeight.w400,
          color: textColor.withValues(alpha: opacity),
          letterSpacing: -0.3,
          height: 1.4,
        ),
      ),
    );
  }
}
