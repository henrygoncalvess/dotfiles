<h1 align=center>📂 dotfiles</h1>

## 📋 Conteúdo

- [Visão Geral](#overview)
- [Objetivo](#objective)
- [Requisitos](#prerequisites)
- [Clonando Repositório](#cloning-repo)
- [Instrução de uso ( Stow )](#use1)
- [Explicação](#explanation)
- [Instrução de uso ( Dconf )](#use2)
- [Licença](#license)

<br>

<a name="overview"></a>
## 🔍 Visão Geral

Repositório com minhas configurações pessoais para shells, extenções, terminais e outras ferramentas.
Feito para fazer backup, organizar e replicar em novos ambientes.

<br>

<a name="objective"></a>
### 🎯 Objetivo

Versionar minhas preferências de desenvolvimento, garantindo consistência e produtividade em qualquer ambiente.

<br>

<a name="prerequisites"></a>
### 📦 Pré-Requisitos

- **Linux** (testado em Zorin OS, mas deve funcionar em qualquer distribuição)
- **Git**
- [**GNU stow**](https://www.gnu.org/software/stow/) - para gerenciar links simbólicos
- [**Dconf**](https://wiki.gnome.org/Projects/dconf) e/ou [**Dconf Editor**](https://wiki.gnome.org/Apps(2f)DconfEditor.html) -  para armazenar configurações de sistema e aplicativos em um banco de dados binário eficiente

<br>

<a name="cloning-repo"></a>
### 💻 Clonando Repositório

No Terminal, certifique de que você está no diretório **HOME** (~/)

`~/usuario`
```bash
git clone https://github.com/henrygoncalvess/dotfiles.git
```

Renomeie a pasta:

```bash
mv ~/dotfiles ~/.dotfiles
```

<br>

<a name="use1"></a>
### 📜 Instrução de uso ( Stow )

1. Entre na pasta

```bash
cd ~/.dotfiles
```  
<br>

> [!IMPORTANT]
> #### Atenção antes de utilizar o Stow.
> Mova os arquivos em que deseja criar os links simbólicos para as pastas correspondentes.
>  
> _EXEMPLO 1:_ se quiser criar um link para `~/.config/oh_my_posh_config/theme.omp.json`  
> Mova o arquivo para `~/.dotfiles/oh_my_posh/.config/oh_my_posh_config/`
> 
> _EXEMPLO 2:_ se quiser criar um link para `~/.config/Code/User/settings.json`  
> Mova o arquivo para `~/.dotfiles/vscode/.config/Code/User/`

<br>

2. Após organizar os arquivos desejados, crie Symlinks com Stow

`~/.dotfiles`
```bash
stow -v -t ~ oh_my_posh/ vscode/ bash/ git/
```

<br>

<a name="explanation"></a>
### 💡 Explicação

`-v` → verbose, ou seja, vai mostrar na saída o que ele está fazendo.

`-t ~` → define o _target directory_ (`~/`, o diretório home do usuário). É para lá que os links simbólicos serão criados.

`oh_my_posh/ vscode/ bash/ git/` → são os pacotes (pastas) que você quer "stowar". Cada pasta representa um conjunto de arquivos de configuração.

Suponha que você tem a seguinte estrutura dentro de `~/.dotfiles/`:

```bash
.dotfiles/
├── oh_my_posh/
│   └── .config/oh_my_posh_config/theme.omp.json
└── vscode/
    └── .config/Code/User/settings.json
```

Ao rodar o comando, o Stow não copia os arquivos. Ele cria symlinks no diretório `~/`:

```bash
~/.config/oh_my_posh_config/theme.omp.json  →  ~/.dotfiles/oh_my_posh/.config/oh-my-posh/config.json
~/.config/Code/User/settings.json →  ~/.dotfiles/vscode/.config/Code/User/settings.json
```

<br>

<a name="use2"></a>
### 📜 Instrução de uso ( Dconf )

```bash
# Exportar configurações (exemplo)
dconf dump /org/gnome/path/example > ~/.dotfiles/my-backup.ini

# Carregar configurações (exemplo)
dconf load /org/gnome/path/example < ~/.dotfiles/my-backup.ini

# Resetar configurações (exemplo)
dconf reset -f /org/gnome/path/example
```

Configurações do **GNOME Terminal**:

```bash
dconf list /org/gnome/terminal/legacy/profiles:/
dconf dump /org/gnome/terminal/legacy/profiles:/:profile-id-123/ > ~/.dotfiles/gnome-terminal-backup.ini
dconf load /org/gnome/terminal/legacy/profiles:/:profile-id-123/ < ~/.dotfiles/gnome-terminal-backup.ini
```

Configurações das **Extensões**:

```bash
dconf dump /org/gnome/shell/extensions/ > ~/.dotfiles/extensions-backup.ini
dconf load /org/gnome/shell/extensions/ < ~/.dotfiles/extensions-backup.ini
```

<br>

<a name="license"></a>
## 📄 Licença

Este projeto está licenciado sob a [MIT License](https://github.com/henrygoncalvess/dotfiles/blob/main/LICENSE).

---

<div align="center">
  <p>Feito com ❤️ por <a href="https://github.com/henrygoncalvess">Henry Gonçalves</a></p>
  <p>Deixe uma ⭐ no repositório se ele for útil para você!</p>
</div>
