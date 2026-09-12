# Spotify no iPhone

A reprodução usa o SDK oficial SpotifyiOS 5.0.1 via Swift Package Manager.
O áudio sai pelo app Spotify instalado no aparelho. O DropLyric envia a URI
exata da faixa e recebe o estado e a posição do player. Não há áudio de outros
catálogos nem prévias.

## Configuração

No Spotify Developer Dashboard, o aplicativo do client ID
`1bdc621fcaa74a21a2c2f90b5b5f0cbc` deve incluir:

- SDK iOS habilitado.
- Bundle ID `com.example.droplyric`.
- Redirect URI `droplyric://callback`.

Use um iPhone físico com o Spotify instalado e conectado à mesma conta.
A escolha de uma faixa específica requer reprodução sob demanda (Premium).
O SDK verifica essa capacidade antes de enviar o comando de reprodução.

## Teste no aparelho

1. Pare a execução anterior e execute novamente pelo Flutter/Xcode. Hot reload
   não instala as alterações nativas.
2. Conecte a conta Spotify no DropLyric e selecione uma música.
3. Permita o controle quando o Spotify abrir e retorne ao DropLyric.
4. Confira a faixa, a posição, a pausa, a retomada e o avanço no player.
5. Alterne para outro app e volte; a conexão deve ser restabelecida.

O login de catálogo continua usando PKCE no Dart. A autorização do App Remote
é tratada no SceneDelegate e não deve ser enviada ao processamento PKCE.
Falhas ao abrir, autorizar ou conectar o Spotify aparecem no player.

A compilação sem assinatura e os testes de canais Flutter não substituem este
teste de autorização/reprodução com uma conta no aparelho.

Referência: https://developer.spotify.com/documentation/ios/getting-started
