#!/usr/bin/env bash
# Reintroduce i tre guasti su vm-broken, qualunque sia stata la correzione applicata.
#   ./break.sh         ripristina i guasti
#   ./break.sh check   mostra se i guasti sono presenti
set -euo pipefail

LAB_DIR="$(cd "$(dirname "$0")" && pwd)"
INFRA="$LAB_DIR/infra"
HOST=lab-broken
RG=rg-claude-lab-broken
NSG=nsg-broken

check() {
  local ip
  ip=$(terraform -chdir="$INFRA" output -json public_ips | python3 -c 'import sys,json;print(json.load(sys.stdin)["broken"])')

  printf '1. NSG:    '
  if az network nsg rule show -g "$RG" --nsg-name "$NSG" -n Deny-HTTP-Maintenance -o none 2>/dev/null; then
    echo "guasto presente (Deny-HTTP-Maintenance esiste)"
  else
    echo "corretto"
  fi

  printf '2. Apache: '
  ssh "$HOST" 'sudo apache2ctl configtest >/dev/null 2>&1 && echo corretto || echo "guasto presente (configtest fallisce)"'

  printf '3. App:    '
  ssh "$HOST" "sudo grep -q \"Rubrica2024!\" /var/www/html/config.php && echo 'guasto presente (password sbagliata in config.php)' || echo corretto"

  printf 'HTTP:     '
  curl -s -m 5 -o /dev/null -w '%{http_code}\n' "http://$ip/" || true
}

if [[ ${1:-} == check ]]; then
  check
  exit 0
fi

echo ">> 1/3 NSG: ripristino le regole definite in Terraform (rimette Deny-HTTP-Maintenance)"
terraform -chdir="$INFRA" apply -input=false -auto-approve -no-color \
  -target=module.broken.azurerm_network_security_group.this | grep -E 'Apply complete|Error' || true

echo ">> 2/3 e 3/3 Apache e applicazione"
db_password=$(echo 'nonsensitive(random_password.broken_db.result)' | terraform -chdir="$INFRA" console | tr -d '"')

ssh "$HOST" 'sudo bash -s' <<EOF
set -e
# Guasto 2: include di un file di hardening che non esiste
rm -rf /etc/apache2/hardening
cat > /etc/apache2/conf-available/security-hardening.conf <<'CONF'
# Hardening applicato il 2026-09-28 (ticket OPS-1432)
ServerTokens Prod
ServerSignature Off
Include /etc/apache2/hardening/headers.conf
CONF
a2enconf -q security-hardening

# Guasto 3: password sbagliata nell'app; il DB torna alla password originale
sed -i "s/^\\\$db_pass = .*/\\\$db_pass = 'Rubrica2024!';/" /var/www/html/config.php
mysql -e "ALTER USER 'rubrica'@'localhost' IDENTIFIED BY '$db_password'; FLUSH PRIVILEGES;"

# Via le copie di backup create durante la demo precedente
find /etc/apache2 /var/www/html -name '*.bak*' -delete
systemctl restart apache2 2>/dev/null || true
EOF

echo ">> Verifica"
check
