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
A implementação é para Flutter Web; o app nativo de macOS continua com o player anterior.
Se houver erro 403, confira Premium e a lista de usuários autorizados. Erro 429 indica limite da API.
Se o Chrome bloquear autoplay, pressione Play novamente. Não há fallback para prévia ao falhar Spotify.
O catálogo e os controles dependem das permissões e limites atuais do aplicativo Spotify.

Validação automatizada:

```sh
flutter analyze --no-pub
flutter test --no-pub
node test/spotify_bridge_test.cjs
flutter build web --no-pub
```

A validação real de áudio, DRM, login e sincronização exige uma sessão Premium autorizada.
