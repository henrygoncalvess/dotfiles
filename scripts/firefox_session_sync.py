#!/usr/bin/env python3
import argparse
import ctypes
import json
import os
import sys
import struct
import shutil

SENSITIVE_KEYS = ['formdata', 'postdata', 'structuredCloneState', 'structuredCloneVersion', 'referrerInfo']

def get_liblz4():
    try:
        return ctypes.CDLL("liblz4.so.1")
    except OSError:
        try:
            return ctypes.CDLL("liblz4.so")
        except OSError:
            print("Erro: liblz4 não encontrada. Instale o pacote lz4 do seu sistema.")
            sys.exit(1)

def decompress_mozlz4(file_path):
    liblz4 = get_liblz4()
    with open(file_path, "rb") as f:
        data = f.read()

    if data[:8] != b"mozLz40\0":
        print("Erro: Cabeçalho inválido no arquivo lz4.")
        sys.exit(1)

    uncompressed_size = struct.unpack('<I', data[8:12])[0]
    src = data[12:]
    dst = ctypes.create_string_buffer(uncompressed_size)
    
    result = liblz4.LZ4_decompress_safe(src, dst, len(src), uncompressed_size)
    if result < 0:
        print("Erro na descompressão.")
        sys.exit(1)
        
    return dst.raw.decode('utf-8')

def compress_mozlz4(data_bytes):
    liblz4 = get_liblz4()
    LZ4_compressBound = liblz4.LZ4_compressBound
    LZ4_compressBound.argtypes = [ctypes.c_int]
    LZ4_compressBound.restype = ctypes.c_int
    
    max_size = LZ4_compressBound(len(data_bytes))
    dst = ctypes.create_string_buffer(max_size)
    
    LZ4_compress_default = liblz4.LZ4_compress_default
    LZ4_compress_default.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_int, ctypes.c_int]
    LZ4_compress_default.restype = ctypes.c_int
    
    compressed_size = LZ4_compress_default(data_bytes, dst, len(data_bytes), max_size)
    if compressed_size <= 0:
        print("Erro na compressão.")
        sys.exit(1)
        
    header = b"mozLz40\0"
    size_bytes = struct.pack('<I', len(data_bytes))
    return header + size_bytes + dst.raw[:compressed_size]

def get_profile_dir():
    base = os.path.expanduser("~/.config/mozilla/firefox")
    if not os.path.isdir(base):
        base = os.path.expanduser("~/.mozilla/firefox")
        if not os.path.isdir(base):
            print("Erro: Diretório do Firefox não encontrado.")
            sys.exit(1)
            
    for d in os.listdir(base):
        if "default-release" in d and os.path.isdir(os.path.join(base, d)):
            return os.path.join(base, d)
            
    # Fallback to the first directory that looks like a profile
    for d in os.listdir(base):
        if d.endswith(".default") and os.path.isdir(os.path.join(base, d)):
            return os.path.join(base, d)
            
    print("Erro: Perfil do Firefox não encontrado.")
    sys.exit(1)

def clean_session(session):
    if 'cookies' in session:
        del session['cookies']
    if '_closedWindows' in session:
        session['_closedWindows'] = []
        
    for win in session.get('windows', []):
        if '_closedTabs' in win:
            win['_closedTabs'] = []
        
        for tab in win.get('tabs', []):
            if 'storage' in tab:
                del tab['storage']
                
            entries = tab.get('entries', [])
            if entries:
                active_idx = tab.get('index', 1) - 1
                if active_idx < 0 or active_idx >= len(entries):
                    active_idx = len(entries) - 1
                
                entry = entries[active_idx]
                for k in SENSITIVE_KEYS:
                    if k in entry:
                        del entry[k]
                tab['entries'] = [entry]
                tab['index'] = 1
                
    return session

def main():
    parser = argparse.ArgumentParser(description="Backup ou Restauro da sessão do Firefox sem dados sensíveis.")
    parser.add_argument('action', choices=['backup', 'restore'], help="Ação a ser executada")
    args = parser.parse_args()

    dotfiles_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    backup_file = os.path.join(dotfiles_dir, "conf_firefox", "session_backup.jsonlz4")
    profile_dir = get_profile_dir()
    session_backups_dir = os.path.join(profile_dir, "sessionstore-backups")
    recovery_file = os.path.join(session_backups_dir, "recovery.jsonlz4")

    if args.action == 'backup':
        if not os.path.exists(recovery_file):
            print(f"Erro: Arquivo de sessão não encontrado em {recovery_file}")
            sys.exit(1)
            
        print("Lendo sessão atual do Firefox...")
        json_str = decompress_mozlz4(recovery_file)
        session = json.loads(json_str)
        
        print("Limpando dados sensíveis (cookies, cache, histórico)...")
        cleaned_session = clean_session(session)
        
        out_json = json.dumps(cleaned_session)
        out_bytes = compress_mozlz4(out_json.encode('utf-8'))
        
        os.makedirs(os.path.dirname(backup_file), exist_ok=True)
        with open(backup_file, 'wb') as f:
            f.write(out_bytes)
            
        print(f"✅ Backup da sessão salvo com sucesso em: conf_firefox/session_backup.jsonlz4")

    elif args.action == 'restore':
        if not os.path.exists(backup_file):
            print(f"Erro: Backup não encontrado em {backup_file}")
            sys.exit(1)
            
        # Deletar sessão atual
        main_session = os.path.join(profile_dir, "sessionstore.jsonlz4")
        if os.path.exists(main_session):
            os.remove(main_session)
            
        os.makedirs(session_backups_dir, exist_ok=True)
        shutil.copy2(backup_file, recovery_file)
        
        print(f"✅ Sessão restaurada com sucesso!")
        print("Inicie o Firefox para ver as suas abas e Tab Groups.")

if __name__ == "__main__":
    main()
