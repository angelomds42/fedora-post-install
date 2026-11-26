# Quick Start

```bash
git clone https://github.com/angelomds42/fedora-post-install
cd fedora-post-install
./setup.sh
```

## Options

| Option | Description |
|--------|-------------|
| `--verify` | Verify installation completed successfully |
| `-y, --yes` | Answer yes to all prompts (non-interactive) |
| `-n, --dry-run` | Print commands without executing |
| `-o, --only a,b` | Run only the given modules |
| `-s, --skip a,b` | Skip the given modules |
| `-l, --list` | List available modules |
| `-c, --config FILE` | Load config file after `config/default.conf` |
| `-h, --help` | Show help |

Modules run in order: `system` → `repos` → `media` → `drivers` → `apps` → `fonts` → `cleanup`.
A failing module does not stop others; failures are listed in the summary with exit code 1.

## Configuration

```bash
cp config/default.conf config/local.conf  # git-ignored
# Edit local.conf
./setup.sh
```

### Package Lists

RPM lists in `packages/rpm/*.txt`:
- `base`: CLI tools, editors, archive utils
- `dev`: Build tools, compilers, containers
- `android`: Android development tools
- `browsers`: Chrome (via repo), commented Brave/Librewolf
- `desktop`: GNOME tweaks, VLC
- `gaming`: Steam, MangoHUD

Flatpak lists in `packages/flatpak/*.txt`:
- `utils`: OBS, Audacity, OnlyOffice, Podman Desktop, etc.
