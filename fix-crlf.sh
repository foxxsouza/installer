#!/bin/bash
# Corrige line endings CRLF -> LF nos scripts do instalador
# Execute: cd /root/installer && bash fix-crlf.sh

cd "$(dirname "$0")"
for f in variables/*.sh lib/*.sh utils/*.sh scripts/*.sh *.sh install_primaria install_instancia 2>/dev/null; do
  [ -f "$f" ] && sed -i 's/\r$//' "$f" && echo "Fixed: $f"
done
echo "Concluído. Execute: sudo ./install.sh"
