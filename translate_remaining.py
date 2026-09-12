import os

replacements = {
    'Palavra "${widget.rawWord}" copiada!': 'Word "${widget.rawWord}" copied!',
    'Meu idioma nativo': 'My native language',
    'Os idiomas nativo e de estudo devem ser diferentes.': 'The native and study languages must be different.',
    '${e.value} palavras': '${e.value} words'
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
