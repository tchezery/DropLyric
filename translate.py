import os

replacements = {
    "Rota não encontrada": "Route not found",
    "Início": "Home",
    "Busca": "Search",
    "Sua Biblioteca": "Library",
    "Perfil": "Profile",
    "Configurações": "Settings",
    "Não foi possível tocar. Confira a conexão Spotify e tente novamente.": "Could not play. Check your Spotify connection and try again.",
    "Busque esta música novamente após conectar o Spotify.": "Search for this track again after connecting Spotify.",
    "Calibrar Sincronização": "Calibrate Sync",
    "Ajuste para avançar (+) ou atrasar (-) o tempo em que a letra aparece.": "Adjust to advance (+) or delay (-) the lyrics timing.",
    "Letra não disponível\\npara esta música.": "Lyrics not available\\nfor this track.",
    "Esta música possui apenas letra em texto livre.": "This track only has plain text lyrics.",
    "Aleatório: Ativado": "Shuffle: On",
    "Aleatório: Desativado": "Shuffle: Off",
    "Repetir: Uma música": "Repeat: One track",
    "Repetir: Desativado": "Repeat: Off",
    "Repetir: Todas": "Repeat: All",
    "Falha na busca Spotify. Confira a conexão e tente novamente.": "Spotify search failed. Check your connection and try again.",
    "Não foi possível abrir a faixa no Spotify. Tente pela busca.": "Could not open the track on Spotify. Try searching.",
    "Que música você quer aprender?": "What track do you want to learn?",
    "Nenhuma música encontrada.": "No tracks found.",
    "Aprenda idiomas com músicas — v1.0.0": "Learn languages with music — v1.0.0",
    "Ouça músicas, leia as letras e marque as palavras que você já conhece para construir seu vocabulário.": "Listen to music, read the lyrics, and mark the words you already know to build your vocabulary.",
    "Não foi possível carregar a definição no momento.": "Could not load the definition at this time.",
    "Dicionário": "Dictionary",
    "Buscando significado no dicionário...": "Searching for meaning in dictionary...",
    "Vocabulário": "Vocabulary",
    "Configure seu idioma nativo e o idioma da música para personalizar o aprendizado.": "Configure your native language and the track's language to personalize your learning.",
    "Idioma da música / que quero aprender": "Track language / I want to learn",
    "Idioma nativo / que eu entendo": "Native language / I understand",
    "Idioma nativo": "Native language",
    "Idioma da música": "Track language",
    "Palavras\\nConhecidas": "Known\\nWords",
    "Idiomas\\nPraticados": "Practiced\\nLanguages",
    "Por idioma": "By language",
    "Sobre o Droplyric": "About Droplyric",
    "Idiomas de estudo": "Study languages",
    "palavras": "words"
}

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    new_content = content
    for pt, en in replacements.items():
        new_content = new_content.replace(f"'{pt}'", f"'{en}'")
        new_content = new_content.replace(f'"{pt}"', f'"{en}"')
        
    if new_content != content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Updated {filepath}")

for root, _, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            process_file(os.path.join(root, file))
