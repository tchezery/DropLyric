import 'package:flutter/widgets.dart';

/// UI copy follows the app locale, independently of the song/study language.
String tr(BuildContext context, String english) {
  final portuguese = Localizations.localeOf(context).languageCode == 'pt';
  return portuguese ? (portugueseStrings[english] ?? english) : english;
}

String localizedLanguageName(BuildContext context, String code) => tr(
  context,
  const {
        'en': 'English',
        'pt': 'Portuguese',
        'es': 'Spanish',
        'fr': 'French',
        'it': 'Italian',
        'de': 'German',
        'ja': 'Japanese',
        'ko': 'Korean',
      }[code] ??
      code.toUpperCase(),
);

const portugueseStrings = <String, String>{
  "Home": "Início",
  "Dictionary": "Dicionário",
  "Profile": "Perfil",
  "Lyrics": "Letra",
  "Progress": "Progresso",
  "Known\nWords": "Palavras\nconhecidas",
  "Practiced\nLanguages": "Idiomas\npraticados",
  "By language": "Por idioma",
  "Settings": "Configurações",
  "App language": "Idioma do app",
  "Remove all word history": "Remover histórico de palavras",
  "Delete every saved word": "Excluir todas as palavras salvas",
  "About DropLyric": "Sobre o DropLyric",
  "Learn languages with music — v1.0.0": "Aprenda idiomas com música — v1.0.0",
  "Listen to music, read the lyrics, and mark the words you already know to build your vocabulary.": "Ouça músicas, leia as letras e marque as palavras que já conhece para ampliar seu vocabulário.",
  "Remove all word history?": "Remover todo o histórico de palavras?",
  "This will permanently remove every saved word from your dictionary.": "Isso excluirá permanentemente todas as palavras salvas no seu dicionário.",
  "Cancel": "Cancelar",
  "Remove all": "Remover tudo",
  "Spotify connection required": "É necessário conectar ao Spotify",
  "Reconnect Spotify": "Reconectar ao Spotify",
  "Connected": "Conectado",
  "Disconnect": "Desconectar",
  "Continue with Spotify app": "Continuar com o app Spotify",
  "Continue with Web": "Continuar pela Web",
  "Restoring your Spotify session…": "Restaurando sua sessão do Spotify…",
  "Connect Spotify to browse and search for music.":
      "Conecte o Spotify para explorar e buscar músicas.",
  "Your profile and dictionary remain available below.":
      "Seu perfil e dicionário continuam disponíveis abaixo.",
  "Choose the language you want to use in the app.":
      "Escolha o idioma que deseja usar no app.",
  "Connect your Spotify account to continue.":
      "Conecte sua conta do Spotify para continuar.",
  "Continue": "Continuar",
  "Could not load your words.": "Não foi possível carregar suas palavras.",
  "Could not update word status.":
      "Não foi possível atualizar o estado da palavra.",
  "Refresh words": "Atualizar palavras",
  "Search words...": "Buscar palavras...",
  "Clear search": "Limpar busca",
  "No saved words yet": "Nenhuma palavra salva ainda",
  "Tap words in lyrics while playing songs to save them!":
      "Toque nas palavras das letras para salvá-las!",
  "Select another letter from the A–Z bar above.":
      "Selecione outra letra na barra de A–Z acima.",
  "Known": "Conhecida",
  "Learning": "Aprendendo",
  "Definition unavailable. Try again":
      "Definição indisponível. Tente novamente",
  "Remove from known": "Aprendido",
  "Mark as known": "Aprendido",
  "Spotify search failed. Check your connection and try again.":
      "A busca no Spotify falhou. Confira sua conexão e tente novamente.",
  "Could not open the track on Spotify. Try searching.":
      "Não foi possível abrir a música no Spotify. Tente buscá-la.",
  "No tracks found.": "Nenhuma música encontrada.",
  "It was not possible to open the track. Try searching for it.":
      "Não foi possível abrir a música. Tente buscá-la.",
  "Calibrate Sync": "Ajustar sincronização",
  "Adjust to advance (+) or delay (-) the lyrics timing.":
      "Ajuste para adiantar (+) ou atrasar (-) a letra.",
  "Reset (0ms)": "Redefinir (0ms)",
  "Could not change the Spotify track.":
      "Não foi possível trocar a música no Spotify.",
  "Back": "Voltar",
  "Adjust sync": "Ajustar sincronização",
  "Dark mode": "Modo escuro",
  "Paper mode": "Modo papel",
    "Use this theme throughout the app": "Usar este tema em todo o app",
  "Lyrics not available\nfor this track.":
      "Letra indisponível\npara esta música.",
  "FREE TEXT": "TEXTO LIVRE",
  "This track only has plain text lyrics.":
      "Esta música só tem letra sem sincronização.",
  "FOLLOW": "ACOMPANHAR",
  "Could not save the word. Try again.":
      "Não foi possível salvar a palavra. Tente novamente.",
  "Skip": "Pular",
  "Shuffle: On": "Aleatório: ativado",
  "Shuffle: Off": "Aleatório: desativado",
  "Repeat: One track": "Repetir: uma música",
  "Repeat: All": "Repetir: todas",
  "Repeat: Off": "Repetir: desativado",
  "Study languages": "Idiomas de estudo",
  "My native language": "Meu idioma nativo",
  "Track language / I want to learn": "Idioma da música / quero aprender",
  "Confirm": "Confirmar",
  "The native and study languages must be different.":
      "O idioma nativo e o de estudo devem ser diferentes.",
  "Vocabulary": "Vocabulário",
  "Could not load the definition at this time.":
      "Não foi possível carregar a definição agora.",
  "KNOWN": "CONHECIDA",
  "LEARNING": "APRENDENDO",
  "Unmark": "Desmarcar",
  "Searching for meaning in dictionary...":
      "Buscando significado no dicionário...",
  "Try again": "Tentar novamente",
  "TRANSLATION": "TRADUÇÃO",
  "LITERAL TRANSLATION": "TRADUÇÃO LITERAL",
  "FULL SENTENCE": "FRASE COMPLETA",
  "DICTIONARY DEFINITIONS": "DEFINIÇÕES DO DICIONÁRIO",
  "English": "Inglês",
  "Portuguese": "Português",
  "Spanish": "Espanhol",
  "French": "Francês",
  "Italian": "Italiano",
  "German": "Alemão",
  "Japanese": "Japonês",
  "Korean": "Coreano",
  "noun": "substantivo",
  "verb": "verbo",
  "adjective": "adjetivo",
  "adverb": "advérbio",
  "pronoun": "pronome",
  "preposition": "preposição",
  "conjunction": "conjunção",
  "interjection": "interjeição",
  "article": "artigo",
  "determiner": "determinante",
  "exclamation": "exclamação",
  "Saved on": "Salva em",
  "From:": "Música:",
  "words": "palavras",
  "ALL": "TODAS",
    "Language": "Idioma",
};
