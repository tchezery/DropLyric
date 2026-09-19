# Spotify no macOS

O DropLyric usa AppleScript para conversar com o Spotify instalado no Mac.
Não usa Client ID, login web, Web API ou o SDK mobile nessa plataforma.

## Uso

1. Instale o Spotify e entre na sua conta.
2. Abra o DropLyric e clique em **Conectar ao app Spotify**.
3. Autorize o controle do Spotify quando o macOS solicitar.
4. Na aba Buscar, cole um link completo de uma faixa ou selecione uma faixa do
   histórico/favoritos. Você também pode escolher a música no próprio Spotify
   e clicar em **Acompanhar agora** no DropLyric.

A conexão não inicia música por conta própria. Somente o comando de reprodução
retoma/inicia uma faixa. Fechar o Spotify interrompe o acompanhamento; reabri-lo
permite que a observação retome. Desconectar no perfil encerra a observação sem
pausar o Spotify. O acesso autorizado é restaurado ao reabrir o DropLyric.

Se a permissão for negada, habilite DropLyric → Spotify em **Ajustes do Sistema →
Privacidade e Segurança → Automação** e clique em conectar novamente.

## Capacidades

- Faixa, artista, álbum, duração e posição, consultados a cada segundo.
- Reprodução por URI/link de faixa, pausa, próxima/anterior e busca por posição.
- Histórico e favoritos locais, compartilhando a interface mobile.
- Sem lista de recomendações ou busca no catálogo: o dicionário AppleScript do
  Spotify não expõe essas operações.

O sandbox permanece habilitado. Os entitlements autorizam somente os grupos
`com.spotify.playback` e `com.spotify.library` do app `com.spotify.client`, além
  de acesso de rede para letras/dicionário e Apple Events no hardened runtime.
A mensagem `NSAppleEventsUsageDescription` explica o pedido ao usuário.

## Validação

- `flutter analyze`
- `flutter test`
- `flutter build macos --debug`
- `xcodebuild -workspace macos/Runner.xcworkspace -scheme Runner -configuration Debug -destination 'platform=macOS' -derivedDataPath build/macos test`

Os testes nativos verificam unidades de tempo, metadados e argumentos inválidos.
Com Spotify instalado, também compilam os scripts contra seu dicionário, sem
executar controles de reprodução. A permissão real e a sincronização devem ser
verificadas com música tocando no app Spotify.
