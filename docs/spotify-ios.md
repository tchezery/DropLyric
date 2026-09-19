# Spotify no iPhone

A reprodução usa o SDK oficial SpotifyiOS 5.0.1 via Swift Package Manager.
O áudio sai pelo app Spotify instalado no aparelho. O DropLyric envia a URI
exata da faixa e recebe o estado e a posição do player. Não há áudio de outros
catálogos nem prévias.

## Configuração

No Spotify Developer Dashboard, o aplicativo do client ID
`1bdc621fcaa74a21a2c2f90b5b5f0cbc` deve incluir:

- SDK iOS habilitado.
- Bundle ID `com.tchezery.droplyric`.
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







@startuml
title Diagrama de Caso de Uso — DropLyric
left to right direction
skinparam backgroundColor #F7F8FA
skinparam shadowing false
skinparam actorStyle awesome
skinparam packageStyle rectangle
skinparam linetype ortho
skinparam nodesep 55
skinparam ranksep 45
skinparam usecase {
  BackgroundColor #EEF7F1
  BorderColor #16834C
  FontColor #101828
}
skinparam actor {
  BorderColor #273142
  FontColor #101828
}
skinparam ArrowColor #667085
actor "Usuário" as Usuario
rectangle "Sistema DropLyric" {
  usecase "UC01\nVincular conta Spotify" as UC01
  usecase "UC02\nPesquisar e selecionar música" as UC02
  usecase "UC03\nReproduzir música e\nacompanhar letra" as UC03
  usecase "UC04\nControlar reprodução" as UC04
  usecase "UC05\nConsultar palavra da letra" as UC05
  usecase "UC06\nGerenciar vocabulário pessoal" as UC06
  usecase "UC07\nConfigurar idioma de estudo" as UC07
  usecase "UC08\nVisualizar progresso de vocabulário" as UC08
  ' Mantém os casos em duas colunas organizadas.
  UC01 -[hidden]down-> UC02
  UC02 -[hidden]down-> UC03
  UC03 -[hidden]down-> UC05
  UC05 -[hidden]down-> UC07
  UC04 -[hidden]down-> UC06
  UC06 -[hidden]down-> UC08
  UC01 -[hidden]right-> UC04
  UC02 -[hidden]right-> UC06
  UC05 -[hidden]right-> UC08
  UC03 ..right.> UC04 : <<include>>
  UC06 ..left.> UC05 : <<extend>>
  UC08 ..up.> UC06 : <<include>>
}
actor "Spotify" as Spotify
actor "Serviço de Letras" as Letras
actor "Serviço de Dicionário" as Dicionario
' O usuário inicia os casos de uso do aplicativo.
Usuario -right- UC01
Usuario -right- UC02
Usuario -right- UC03
Usuario -right- UC05
Usuario -right- UC06
Usuario -right- UC07
Usuario -right- UC08
' Os serviços externos ficam do lado direito.
UC01 -right- Spotify
UC02 -right- Spotify
UC04 -right- Spotify
UC03 -right- Letras
UC05 -right- Dicionario
' Mantém os atores externos em ordem vertical.
Spotify -[hidden]down-> Letras
Letras -[hidden]down-> Dicionario
@enduml
