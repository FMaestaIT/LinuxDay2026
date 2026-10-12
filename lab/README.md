# Claude Lab: demo di gestione server con Claude Code

Laboratorio su Azure per mostrare come Claude Code interagisce con dei server Linux in tre modi:

| VM | Come la gestisce Claude | Scopo nella demo |
|---|---|---|
| **vm-lamp** | SSH | Amministrazione di un server LAMP |
| **vm-api** | API REST della VM + API Azure (`az`) | Gestione tramite API |
| **vm-broken** | SSH + `az` | Troubleshooting di un server con guasti voluti |

> Questo file è tenuto aggiornato man mano che il laboratorio evolve: vedi il [registro delle modifiche](#registro-delle-modifiche).

---

## Architettura

```
 PC operatore (Fedora, Claude Code CLI eseguito da ~/LinuxDay2026/demo)
   ├── SSH ───────────────► vm-lamp    rg-claude-lab-lamp    10.10.0.0/16
   ├── HTTPS (Bearer) ────► vm-api     rg-claude-lab-api     10.20.0.0/16
   ├── SSH ───────────────► vm-broken  rg-claude-lab-broken  10.30.0.0/16
   └── az CLI ────────────► Azure Resource Manager (stato VM, NSG, metriche)
```

- **Subscription:** quella indicata in `subscription_id` (`terraform.tfvars`)
- **Regione:** Italy North (`italynorth`)
- **Isolamento:** un resource group per VM; ogni VM ha la propria VNet, subnet (`/24`), NSG e IP pubblico statico, senza peering tra le VNet.
- **Immagine:** Ubuntu Server 24.04 LTS (`Canonical/ubuntu-24_04-lts/server`)
- **Taglia:** `Standard_B2s` (2 vCPU, 4 GB RAM), disco `StandardSSD_LRS` da 30 GB
- **Utente sulle VM:** `claude`, accesso con chiave SSH e sudo senza password
- **Accesso di rete:** tutte le porte esposte sono aperte solo all'IP pubblico dell'operatore (`allowed_cidr` in `terraform.tfvars`)

### Risorse per VM

Ogni VM è creata dal modulo `infra/modules/vm` con queste risorse:

| Risorsa | Nome |
|---|---|
| Resource group | `rg-claude-lab-<nome>` |
| Virtual network / subnet | `vnet-<nome>` / `snet-<nome>` |
| Network security group | `nsg-<nome>` (associato alla subnet) |
| IP pubblico (Standard, statico) | `pip-<nome>` |
| Scheda di rete | `nic-<nome>` |
| Macchina virtuale | `vm-<nome>` (hostname `<nome>`) |
| Disco OS | `osdisk-<nome>` |

Tag comuni: `project=claude-lab`, `managed_by=terraform`, `role=lamp-ssh|api|troubleshooting`.

### Regole NSG in ingresso

| VM | Regola | Priorità | Porta | Azione | Sorgente |
|---|---|---|---|---|---|
| lamp | Allow-SSH | 100 | 22 | Allow | IP operatore |
| lamp | Allow-HTTP | 110 | 80 | Allow | IP operatore |
| api | Allow-SSH | 100 | 22 | Allow | IP operatore |
| api | Allow-HTTPS | 110 | 443 | Allow | IP operatore |
| broken | Allow-SSH | 100 | 22 | Allow | IP operatore |
| broken | Deny-HTTP-Maintenance | 105 | 80 | **Deny** | qualsiasi (guasto voluto) |
| broken | Allow-HTTP | 110 | 80 | Allow | IP operatore |

---

## Configurazione delle VM

La configurazione software avviene al primo avvio tramite cloud-init (`infra/cloud-init/`). Terraform ignora le modifiche successive a `custom_data`: per riapplicarle bisogna ricreare la VM.

### vm-lamp

- Pacchetti: `apache2`, `mariadb-server`, `php`, `libapache2-mod-php`, `php-mysql`
- App **Rubrica** (`infra/files/rubrica.php` → `/var/www/html/index.php`): elenco e inserimento contatti
- Credenziali dell'app in `/var/www/html/config.php` (`root:www-data`, `0640`)
- Database `rubrica`, utente `rubrica@localhost` (password casuale generata da Terraform), tabella `contatti` con 3 righe di esempio

### vm-api

- Pacchetti: `nginx`, `python3-fastapi`, `python3-uvicorn`
- API FastAPI (`infra/files/labapi.py` → `/opt/labapi/labapi.py`), servizio systemd `labapi` eseguito dall'utente di sistema `labapi` (gruppo `systemd-journal`) su `127.0.0.1:8000`
- Nginx su 443 come reverse proxy, con certificato autofirmato in `/etc/ssl/labapi/` (CN `lab-api`; i client devono usare `curl -k`)
- Token in `/etc/labapi.env`; stato dei deploy in `/var/lib/labapi/deployments.json`

| Endpoint | Auth | Descrizione |
|---|---|---|
| `GET /health` | no | Liveness check |
| `GET /status` | sì | Hostname, uptime, load, memoria, disco, versione in produzione |
| `GET /services` | sì | Stato di `nginx`, `labapi`, `cron`, `systemd-journald` |
| `GET /logs?service=&lines=` | sì | Ultime righe di journal di un servizio (max 500) |
| `GET /deployments` | sì | Storico dei deploy |
| `POST /deployments` | sì | Deploy simulato: `{"version": "X.Y.Z", "note": "..."}` (409 se la versione è già in produzione) |
| `GET /docs`, `GET /openapi.json` | no | Documentazione e specifica OpenAPI |

Autenticazione: `Authorization: Bearer <token>`. Senza token la risposta è 403, con un token errato 401.

### vm-broken

È la stessa configurazione di vm-lamp, con tre guasti voluti. **Spoiler per il presentatore, da non mostrare a Claude:**

| # | Livello | Guasto | Sintomo | Correzione attesa |
|---|---|---|---|---|
| 1 | Azure | Regola NSG `Deny-HTTP-Maintenance` (prio 105) prima di `Allow-HTTP` (110) | Porta 80 irraggiungibile (timeout) | Eliminare la regola |
| 2 | Sistema | `conf-enabled/security-hardening.conf` include `/etc/apache2/hardening/headers.conf`, che non esiste | Apache non parte, `configtest` fallisce | `a2disconf security-hardening` o creare il file |
| 3 | Applicazione | `$db_pass = 'Rubrica2024!'` in `config.php` non corrisponde alla password del DB | HTTP 500, "impossibile collegarsi al database" | Reimpostare la password nel DB (`ALTER USER`) e allineare `config.php` |

---

## Struttura dei file

```
~/LinuxDay2026/lab/                 # infrastruttura e materiale del presentatore (vietato a Claude nella demo)
├── README.md                 # questo file
├── COPIONE.md                # scaletta della demo con i prompt e le soluzioni
├── lab.sh                    # start | stop | status delle VM
├── break.sh                  # reintroduce i guasti su vm-broken | check
├── ssh_config                # (non versionato) generato da Terraform: alias lab-lamp, lab-api, lab-broken
├── .env.lab                  # (non versionato) generato da Terraform: LAB_API_URL, LAB_API_TOKEN (0600)
├── .gitignore
└── infra/
    ├── versions.tf           # provider: azurerm ~> 4.0, random, local
    ├── variables.tf
    ├── main.tf               # 3 istanze del modulo vm + password + file locali
    ├── outputs.tf            # resource_groups, public_ips, urls, api_token (sensitive)
    ├── terraform.tfvars      # (non versionato) subscription_id, allowed_cidr; modello in terraform.tfvars.example
    ├── modules/vm/main.tf    # rete + NSG + IP + NIC + VM
    ├── cloud-init/           # lamp.yaml.tftpl (usato anche da broken), api.yaml.tftpl
    └── files/                # rubrica.php, labapi.py

~/LinuxDay2026/demo/                # workspace da cui si avvia Claude per la demo
├── README.md                 # summary per il pubblico: scenari, canali, metodologia (senza spoiler)
├── CLAUDE.md                 # contesto: server, accessi, regole di lavoro
├── api/openapi.json          # specifica dell'API di vm-api
└── .claude/
    ├── settings.json         # permessi
    └── settings.local.json   # generato da Terraform: variabili d'ambiente dell'API (0600)
```

### Variabili Terraform

| Variabile | Default | Note |
|---|---|---|
| `subscription_id` | (da tfvars) | |
| `allowed_cidr` | (da tfvars) | IP pubblico dell'operatore, es. `203.0.113.10/32` |
| `location` | `italynorth` | |
| `prefix` | `claude-lab` | |
| `vm_size` | `Standard_B2s` | |
| `ssh_public_key_path` | `~/.ssh/claude_lab_ed25519.pub` | |
| `ssh_private_key_path` | `~/.ssh/claude_lab_ed25519` | Serve solo a generare `ssh_config` |
| `demo_dir` | `/home/federico/LinuxDay2026/demo` | Dove scrivere `settings.local.json` |

---

## Ricreare il lab da zero

Prerequisiti: Azure CLI autenticata (`az login`), Terraform ≥ 1.9, una subscription con quota per 6 vCPU della famiglia B.

```bash
ssh-keygen -t ed25519 -N '' -C claude-lab -f ~/.ssh/claude_lab_ed25519
cd lab/infra
cp terraform.tfvars.example terraform.tfvars   # inserire subscription_id e il proprio IP pubblico
terraform init && terraform apply
echo "Include $PWD/../ssh_config" | cat - ~/.ssh/config > /tmp/sshcfg && mv /tmp/sshcfg ~/.ssh/config
```

Se il repository non è in `/home/federico/LinuxDay2026`, aggiornare `demo_dir` (variabile Terraform) e i percorsi vietati in `demo/.claude/settings.json`.

## Configurazione di Claude Code per la demo

- Claude Code gira come **root**: la chiave SSH (`/root/.ssh/claude_lab_ed25519`), la config SSH (`/root/.ssh/config` include `~federico/LinuxDay2026/lab/ssh_config`) e il login `az` sono quelli di root.
- Gli host key delle VM finiscono in `~/.ssh/known_hosts_claude_lab`, separato dal file principale, così una VM ricreata non dà conflitti.
- Le variabili `LAB_API_URL` e `LAB_API_TOKEN` arrivano a Claude da `.claude/settings.local.json` (blocco `env`): il token è disponibile ai comandi ma non compare a schermo.

### Permessi (`~/LinuxDay2026/demo/.claude/settings.json`)

| Tipo | Regole |
|---|---|
| Consentiti senza conferma | `az vm show/list/get-instance-view/boot-diagnostics get-boot-log`, `az network nsg show/list/rule list/rule show`, `az network public-ip show/list`, `az network nic show`, `az monitor metrics list`, `az group list`, `az resource list` |
| Con conferma (default) | tutto il resto, compresi `ssh` e `curl`: il pubblico vede l'approvazione delle modifiche |
| Vietati | `az group delete`, `az vm delete/deallocate/stop/restart`, `terraform`, lettura di `/home/federico/LinuxDay2026/lab/**` |

> Le regole `allow` valgono solo dopo aver accettato il dialogo di fiducia: avviare `claude` una volta in `~/LinuxDay2026/demo` e confermare.

---

## Operazioni

| Cosa | Comando |
|---|---|
| Creare/aggiornare il lab | `cd ~/LinuxDay2026/lab/infra && terraform apply` |
| Vedere IP e URL | `terraform -chdir=~/LinuxDay2026/lab/infra output` |
| Accendere / spegnere / stato | `~/LinuxDay2026/lab/lab.sh start\|stop\|status` |
| Reintrodurre i guasti | `~/LinuxDay2026/lab/break.sh` |
| Controllare i guasti | `~/LinuxDay2026/lab/break.sh check` |
| Ricreare da zero una VM | `terraform apply -replace=module.<nome>.azurerm_linux_virtual_machine.this` |
| Avviare la demo | `cd ~/LinuxDay2026/demo && claude` |
| Smontare tutto | `cd ~/LinuxDay2026/lab/infra && terraform destroy` |

Se cambia l'IP pubblico dell'operatore: aggiornare `allowed_cidr` in `terraform.tfvars` e lanciare `terraform apply`.

`break.sh` ripristina le regole NSG con un `terraform apply` mirato. Su vm-broken riscrive la conf di hardening e la riabilita, rimette la password sbagliata in `config.php`, riporta la password del DB al valore generato da Terraform, cancella i `*.bak` e riavvia Apache.

---

## Costi

- Con le 3 VM `B2s` accese si spendono circa 2,5 €/giorno; spente con `lab.sh stop` (deallocate) restano solo dischi e IP pubblici, pochi centesimi al giorno.
- **Non c'è auto-shutdown:** `Microsoft.DevTestLab/schedules` non è disponibile in Italy North, né come risorsa nella stessa regione né in un'altra regione. Le VM vanno spente a mano con `lab.sh stop`.

---

## Sicurezza e note

- Lo state Terraform (`infra/terraform.tfstate`) è locale e contiene in chiaro il token dell'API e le password del DB: non va condiviso né committato (è nel `.gitignore`).
- Anche `.env.lab` e `settings.local.json` contengono il token (permessi `0600`).
- L'utente `claude` ha sudo completo sulle VM: il controllo passa dalle richieste di approvazione di Claude Code. Un possibile irrigidimento futuro è un sudo limitato ai comandi necessari.
- Strumenti installati sul PC per il lab: Terraform 1.16.5 in `/usr/local/bin` (checksum verificato).

---

## Registro delle modifiche

| Data | Modifica |
|---|---|
| 2026-10-12 | Creazione del lab con Terraform: 3 resource group, 3 VM in Italy North, cloud-init per LAMP, API e guasti. Tolto l'auto-shutdown (non supportato in Italy North), aggiunto `lab.sh`. |
| 2026-10-12 | Workspace `~/LinuxDay2026/demo` (CLAUDE.md, permessi, OpenAPI, variabili d'ambiente generate da Terraform), `break.sh` testato sul ciclo completo correggi → guasta, `COPIONE.md`. |
| 2026-10-12 | Aggiunto questo README. |
| 2026-10-12 | Aggiunto `~/LinuxDay2026/demo/README.md`: summary di scenari, canali di interfacciamento e metodologia, senza riferimenti ai guasti. |
| 2026-10-12 | Spostato tutto nel repository `~/LinuxDay2026` (`claude-lab` → `lab/`, `claude-demo` → `demo/`), summary come README principale, pubblicato su GitHub (FMaestaIT/LinuxDay2026). Esclusi dal repo state, tfvars e file con token/IP. |
