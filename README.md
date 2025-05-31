<h1 align=center>📂 dotfiles</h1>

## 📋 Conteúdo

- [Visão Geral](#overview)
- [Objetivo](#objective)
- [Requisitos](#prerequisites)
- [Clonando Repositório](#cloning-repo)
- [Instrução de uso ( Stow )](#use1)
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
### 📦 Requisitos

- Linux (testado em Zorin OS, mas deve funcionar em qualquer distribuição)
- Git
- [GNU stow](https://www.gnu.org/software/stow/) para gerenciar links simbólicos
- [Dconf](https://wiki.gnome.org/Projects/dconf) e/ou [Dconf Editor](https://wiki.gnome.org/Apps(2f)DconfEditor.html)

<br>

<a name="cloning-repo"></a>
### 💻 Clonando Repositório

No Terminal, certifique de que você está na **HOME** (~/)

`~/usuario`
```bash
git clone https://github.com/henrygoncalvess/dotfiles.git
```

<br>

<a name="use1"></a>
### 📜 Instrução de uso ( Stow )

1. Entre na pasta:

```bash
cd ~/dotfiles
```  
<br>

> [!IMPORTANT]
> #### Atenção antes de utilizar o Stow.
> Mova os arquivos em que deseja criar os links simbólicos para as pastas correspondentes.  
> _EXEMPLO:_ se quiser criar um link para `~/.config/oh_my_posh_config/theme.omp.json`  
> Mova o arquivo para `~/dotfiles/oh_my_posh/.config/oh_my_posh_config/`
<br>

2. Após organizar os arquivos desejados, crie Symlinks com Stow

`~/dotfiles`
```bash
stow -v -t ~ oh_my_posh/ code/ d2da/
```

<br>

<a name="use2"></a>
### 📜 Instrução de uso ( Dconf )

Resetar configurações:

```bash
dconf reset -f /caminho/
```

Exportar e aplicar configurações do **GNOME Terminal**:

```bash
# exportar
dconf dump /org/gnome/terminal/legacy/profiles:/:profile-id-123/ > ~/dotfiles/gnome-terminal-backup.ini

# aplicar
dconf load /org/gnome/terminal/legacy/profiles:/:profile-id-123/ < ~/dotfiles/gnome-terminal-backup.ini
```

Exportar e aplicar configurações da extensão **Dash2Dock Animated**:

```bash
# exportar
dconf dump /org/gnome/shell/extensions/dash2dock-lite/ > ~/dotfiles/dash2dock-backup.ini

# aplicar
dconf load /org/gnome/shell/extensions/dash2dock-lite/ < ~/dotfiles/dash2dock-backup.ini
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
