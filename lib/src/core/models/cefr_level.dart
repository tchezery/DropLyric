import 'package:flutter/material.dart';

enum CefrLevelType {
  starter,
  a1,
  a2,
  b1,
  b2,
  c1,
  c2,
}

/// Representa um nível de proficiência CEFR com base nos estudos científicos
/// de vocabulário de Paul Nation (2006) e Milton & Alexiou (2009).
class CefrLevel {
  final CefrLevelType type;
  final String code;
  final String titlePt;
  final String titleEn;
  final String descriptionPt;
  final String descriptionEn;
  final int minWords;
  final int targetWords;
  final Color badgeColor;

  const CefrLevel({
    required this.type,
    required this.code,
    required this.titlePt,
    required this.titleEn,
    required this.descriptionPt,
    required this.descriptionEn,
    required this.minWords,
    required this.targetWords,
    required this.badgeColor,
  });

  String localizedTitle(String langCode) => langCode == 'pt' ? titlePt : titleEn;
  String localizedDescription(String langCode) =>
      langCode == 'pt' ? descriptionPt : descriptionEn;

  static const List<CefrLevel> all = [
    CefrLevel(
      type: CefrLevelType.starter,
      code: 'Iniciante',
      titlePt: 'Iniciante',
      titleEn: 'Beginner',
      descriptionPt: 'Primeiros passos. Reconhecimento de palavras soltas e refrões simples.',
      descriptionEn: 'First steps. Recognizing isolated words and simple choruses.',
      minWords: 0,
      targetWords: 500,
      badgeColor: Color(0xFF8E8E93),
    ),
    CefrLevel(
      type: CefrLevelType.a1,
      code: 'A1',
      titlePt: 'Básico Inicial',
      titleEn: 'Elementary A1',
      descriptionPt: 'Compreende expressões cotidianas, cumprimentos e partes frequentes de músicas.',
      descriptionEn: 'Understands daily expressions, greetings, and frequent lyrics.',
      minWords: 500,
      targetWords: 1500,
      badgeColor: Color(0xFF34C759),
    ),
    CefrLevel(
      type: CefrLevelType.a2,
      code: 'A2',
      titlePt: 'Elementar',
      titleEn: 'Waystage A2',
      descriptionPt: 'Limiar lexical dos estudos de Nation: compreende cerca de 80% do vocabulário pop.',
      descriptionEn: 'Nation\'s lexical threshold: understands about 80% of pop lyrics.',
      minWords: 1500,
      targetWords: 3000,
      badgeColor: Color(0xFF30B0C7),
    ),
    CefrLevel(
      type: CefrLevelType.b1,
      code: 'B1',
      titlePt: 'Intermediário',
      titleEn: 'Intermediate B1',
      descriptionPt: 'Compreende a história central e ideias principais da maioria das músicas.',
      descriptionEn: 'Understands the main narrative and core themes of most songs.',
      minWords: 3000,
      targetWords: 4500,
      badgeColor: Color(0xFF007AFF),
    ),
    CefrLevel(
      type: CefrLevelType.b2,
      code: 'B2',
      titlePt: 'Autônomo',
      titleEn: 'Upper Intermediate B2',
      descriptionPt: 'Fluência em vários estilos musicais, gírias e expressões idiomáticas.',
      descriptionEn: 'Fluency in diverse genres, idioms, and natural slang.',
      minWords: 4500,
      targetWords: 6500,
      badgeColor: Color(0xFF5856D6),
    ),
    CefrLevel(
      type: CefrLevelType.c1,
      code: 'C1',
      titlePt: 'Avançado',
      titleEn: 'Advanced C1',
      descriptionPt: 'Compreensão de poesia lírica, trocadilhos, metáforas e rap veloz.',
      descriptionEn: 'Deep understanding of lyrical poetry, wordplay, and fast rap.',
      minWords: 6500,
      targetWords: 8000,
      badgeColor: Color(0xFFAF52DE),
    ),
    CefrLevel(
      type: CefrLevelType.c2,
      code: 'C2',
      titlePt: 'Domínio Pleno',
      titleEn: 'Mastery C2',
      descriptionPt: 'Vocabulário rico e abrangente, equivalente ao de um falante nativo culto.',
      descriptionEn: 'Rich, comprehensive vocabulary equivalent to an educated native.',
      minWords: 8000,
      targetWords: 10000,
      badgeColor: Color(0xFFFF9500),
    ),
  ];

  static CefrLevel fromWordCount(int count) {
    if (count < 500) return all[0];
    if (count < 1500) return all[1];
    if (count < 3000) return all[2];
    if (count < 4500) return all[3];
    if (count < 6500) return all[4];
    if (count < 8000) return all[5];
    return all[6];
  }

  static CefrLevel? nextLevel(CefrLevel current) {
    final idx = all.indexOf(current);
    if (idx < all.length - 1) return all[idx + 1];
    return null;
  }
}
