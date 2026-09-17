import 'package:flutter/material.dart';

class VocabularyPage extends StatelessWidget
{
  const VocabularyPage({super.key});

  @override
  Widget build(BuildContext context)
  {
    return Scaffold
    (
      appBar: AppBar(title: const Text('Vocabulary')),
      body: const Center(child: Text('Vocabulary Page')),
    );
  }
}