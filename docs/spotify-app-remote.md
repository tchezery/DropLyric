# Teste do modo App Remote (Android e iOS)

O fluxo mobile usa apenas a conexão com o aplicativo Spotify para selecionar
conteúdos, tocar faixas e acompanhar os metadados/posição. O SDK ainda exige um
Client ID registrado, configuração de callback e autorização do usuário. Esta
mudança não comprova elegibilidade para distribuição pública irrestrita.

A versão Web mantém a implementação anterior, com Web API/Web Playback SDK.
Os arquivos de autenticação mobile antigos permanecem no repositório para
referência, mas não são inicializados pelo fluxo mobile nem pelos delegates iOS.
Letras e dicionário continuam usando seus serviços próprios na internet.

## Como testar em aparelho

1. Instale/abra o Spotify e entre na conta. Instale a versão de teste do DropLyric.
2. Abra a aba de busca: agora ela mostra **Escolher música** no mobile.
3. Use **Conectar ao app Spotify** e autorize o acesso. No iPhone, a autorização
   pode retomar a reprodução atual do Spotify. Retorne ao DropLyric.
4. Cole um link completo `https://open.spotify.com/track/ID` e toque em reproduzir.
   Links com `?si=...` e prefixo `/intl-pt/` são aceitos. Links encurtados,
   playlists e busca por nome não são aceitos nesse campo.
5. Confira título, artista, letra e posição. Troque a faixa no próprio Spotify:
   o player do DropLyric deve atualizar a música e a letra.
6. Em **Do Spotify**, toque em **Carregar**. Abra os grupos disponíveis ou use
   o botão de reprodução dos itens tocáveis. O conteúdo varia conforme a conta;
   a lista não representa o catálogo inteiro nem todas as playlists.
7. Em **Histórico neste aparelho**, favorite uma faixa pelo coração. Feche e
   reabra o DropLyric: o histórico e os favoritos devem permanecer.
8. Use **Acompanhar agora** para abrir a letra sem retomar uma faixa pausada.
9. Teste pausa, busca por posição, próxima/anterior e reconexão após voltar do
   segundo plano. Comandos podem ser recusados pelas capacidades da conta.
10. Desconecte no perfil. A seleção e as listas locais continuam disponíveis;
    tocar novamente pode solicitar conexão/autorização.

A reprodução real, o consentimento, as capacidades de cada conta e os conteúdos
retornados pelo Spotify precisam ser validados em aparelho com Spotify instalado.
Compilação e testes com canais simulados não substituem essa validação.
