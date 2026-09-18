# ==========================
# .zshenv - Environment Variables
# ==========================
# Sempre carregado, para todo tipo de shell. Mantenha rápido: nada de subprocesso
# caro aqui, ele roda até em `zsh -c`.

# ---- Locale ----
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# ---- Editor ----
# GNU nano é o nano padrão no Ubuntu (apt install nano). Config em ~/.nanorc.
export EDITOR=nano
export VISUAL=nano

# ---- bat ----
# No macOS o tema seguia a aparência do sistema via `defaults read`. Em Linux não
# há equivalente universal, então fica fixo. Temas: `batcat --list-themes`.
# No Ubuntu o binário se chama `batcat` (conflito de nome com o pacote `bat`);
# o alias em .zshrc resolve.
export BAT_THEME="${BAT_THEME:-Github}"

# ---- Custom ----
export GEMINI_MODEL="gemini-2.5-flash"
