# Spotify no Chrome

Integração Web com OAuth Authorization Code + PKCE e Web Playback SDK.
Client ID configurado: `1bdc621fcaa74a21a2c2f90b5b5f0cbc`.
Não usa Client Secret. Tokens ficam no sessionStorage da aba e são removidos ao desconectar.

1. No Spotify Developer Dashboard, abra seu aplicativo e Settings.
2. Cadastre em Redirect URIs exatamente `http://127.0.0.1:8080/` (incluindo a barra final), salve e habilite Web API / Web Playback SDK quando solicitado.
3. Confira sua conta em Users Management. A conta de reprodução precisa de Premium.
4. Execute no diretório do projeto:

```sh
flutter run -d chrome --web-hostname 127.0.0.1 --web-port 8080
```

5. Na Home, clique em **Conectar Spotify Premium** e autorize na tela do Spotify.
6. Use **Buscar** para escolher uma faixa do catálogo Spotify. Abra e pressione Play.
7. Teste pausa, avanço, retorno e acompanhamento das letras. Uma faixa sem LRC aparece em Texto Livre.

O player aparece no Spotify Connect como Droplyric. O login não fornece arquivos MP3.
O player Spotify está integrado no Flutter Web e no Android (App Remote).
Se ouvir apenas 30 segundos, confira se conectou o Spotify e escolheu uma faixa na busca após conectar. Faixas Spotify usam o Web Playback SDK; prévias de outros catálogos não são músicas completas. No Android, a reprodução é feita pelo aplicativo oficial do Spotify e controlada pelo Droplyric.
Se houver erro 403, confira Premium e a lista de usuários autorizados. Erro 429 indica limite da API.
Erros 500, 502, 503 e 504 indicam falha do servidor ou gateway. Nas buscas e consultas de faixas, o app faz até duas novas tentativas (após 0,5 e 1 segundo). Se persistir, aguarde e tente novamente. Comandos de reprodução não são repetidos automaticamente; pressione Play novamente quando o serviço voltar. Essas falhas não apagam a sessão Spotify.
Depois de alterar `web/spotify_bridge.js`, reinicie a execução e recarregue a página no Chrome para carregar a nova versão do script.
Se o Chrome bloquear autoplay, pressione Play novamente. Não há fallback para prévia ao falhar Spotify.
O catálogo e os controles dependem das permissões e limites atuais do aplicativo Spotify.

Validação automatizada:

```sh
flutter analyze --no-pub
flutter test --no-pub
node --test test/spotify_http_test.cjs
flutter test --no-pub test/spotify_audio_source_test.dart
flutter build web --no-pub
```

A validação real de áudio, DRM, login e sincronização exige uma sessão Premium autorizada.

## Teste no Android real

1. Instale o Spotify oficial e entre com a mesma conta Premium autorizada em Users Management.
2. No painel Spotify, habilite Android, mantenha `droplyric://callback` e cadastre:
   - Package name: `com.example.droplyric`
   - SHA-1 do certificado debug deste computador: `BB:BA:FF:16:C1:24:17:B2:EE:0E:B3:8F:A4:26:7B:23:8C:AC:B7:17`
3. Gere o APK com `flutter build apk --debug` e instale `build/app/outputs/flutter-apk/app-debug.apk`.
4. No Droplyric, conecte o Spotify e autorize o login no navegador. Ao tocar a primeira faixa, autorize também o controle do Spotify pelo App Remote, se solicitado.
5. Faça uma nova busca conectado, toque uma faixa e verifique reprodução além de 30 segundos, pausa, retomada e avanço. Teste marcar palavras e reabrir o app para conferir a persistência.

O login nativo permanece em memória: após encerrar o processo do app, conecte novamente. As palavras persistem no SQLite. A autorização do navegador e a do App Remote são etapas separadas. O áudio é reproduzido pelo Spotify instalado; não há conversão para MP3 nem substituição de faixas Spotify por prévias.

Biblioteca oficial incluída: `android/app/libs/spotify-app-remote-release-0.8.0.aar`, obtida da release `v0.8.0-appremote_v2.1.0-auth` em https://github.com/spotify/android-sdk/releases. Os testes automatizados dos comandos nativos usam mocks; áudio real exige validar no aparelho.

```sh
flutter test --no-pub test/spotify_android_bridge_test.dart test/spotify_audio_source_test.dart test/known_words_persistence_test.dart
```
