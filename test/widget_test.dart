import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:droplyric/src/core/services/spotify_session.dart';
import 'package:droplyric/src/widgets/spotify_access_gate.dart';

class TestSession extends ChangeNotifier implements SpotifySession {
  bool _connected = false;
  @override
  bool get connected => _connected;
  @override
  bool get supported => true;
  @override
  bool get initializing => false;
  @override
  bool get connecting => false;
  @override
  String get error => '';
  void setConnected(bool value) {
    _connected = value;
    notifyListeners();
  }

  @override
  Future<void> command(String action, [String argument = '']) async {
    setConnected(action == 'login');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('music requires login and becomes hidden again on logout', (
    tester,
  ) async {
    final session = TestSession();
    await tester.pumpWidget(
      MaterialApp(
        home: SpotifyAccessGate(
          session: session,
          child: const Scaffold(body: Text('Catálogo Spotify')),
        ),
      ),
    );
    expect(find.text('Catálogo Spotify'), findsNothing);
    expect(
      find.text('Conecte o Spotify para ver e buscar músicas.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Conectar Spotify Premium'));
    await tester.pump();
    expect(find.text('Catálogo Spotify'), findsOneWidget);
    session.setConnected(false);
    await tester.pump();
    expect(find.text('Catálogo Spotify'), findsNothing);
    expect(find.textContaining('perfil e dicionário'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    session.dispose();
  });
}
