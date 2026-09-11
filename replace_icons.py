import os
import re

icon_map = {
    'more_vert_rounded': 'ellipsis_vertical',
    'more_vert': 'ellipsis_vertical',
    'music_note_rounded': 'music_note',
    'music_note': 'music_note',
    'check_circle': 'checkmark_alt_circle',
    'language_rounded': 'globe',
    'check_rounded': 'checkmark',
    'close_rounded': 'clear',
    'close': 'clear',
    'menu_book_rounded': 'book',
    'menu_book_outlined': 'book',
    'bookmark_remove_rounded': 'bookmark_solid',
    'bookmark_remove_outlined': 'bookmark_solid',
    'bookmark_add_rounded': 'bookmark',
    'copy_rounded': 'doc_on_clipboard',
    'wifi_off_rounded': 'wifi_slash',
    'refresh_rounded': 'refresh',
    'refresh': 'refresh',
    'volume_up_rounded': 'volume_up',
    'translate_rounded': 'globe',
    'person_rounded': 'person',
    'info_outline_rounded': 'info',
    'chevron_right_rounded': 'chevron_right',
    'chevron_right': 'chevron_right',
    'chevron_left_rounded': 'chevron_left',
    'album_rounded': 'music_albums',
    'headphones_rounded': 'headphones',
    'audiotrack_rounded': 'music_note_list',
    'search_rounded': 'search',
    'search': 'search',
    'clear_rounded': 'clear',
    'search_off_rounded': 'search',
    'folder_outlined': 'folder',
    'tune_rounded': 'slider_horizontal_3',
    'dark_mode_outlined': 'moon',
    'light_mode_outlined': 'sun_max',
    'lyrics_outlined': 'doc_text',
    'skip_previous_rounded': 'backward_end_fill',
    'skip_next_rounded': 'forward_end_fill',
    'shuffle_rounded': 'shuffle',
    'repeat_one_rounded': 'repeat_1',
    'repeat_rounded': 'repeat',
    'pause_rounded': 'pause_fill',
    'play_arrow_rounded': 'play_fill',
    'sort': 'sort_down',
    'home_rounded': 'house',
    'library_music_rounded': 'music_albums'
}

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    new_content = content
    has_changes = False
    
    for mat, cup in icon_map.items():
        if f"Icons.{mat}" in new_content:
            new_content = new_content.replace(f"Icons.{mat}", f"CupertinoIcons.{cup}")
            has_changes = True

    if has_changes:
        if 'package:flutter/cupertino.dart' not in new_content:
            new_content = "import 'package:flutter/cupertino.dart';\n" + new_content
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Updated {filepath}")

for root, _, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            process_file(os.path.join(root, file))
