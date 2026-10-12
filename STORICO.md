# Storico del progetto

Diario di lavoro del laboratorio Linux Day 2026: cosa è stato fatto, le decisioni prese e il loro motivo, i problemi incontrati e il punto di ripartenza.
**Da leggere all'inizio di ogni sessione; da aggiornare alla fine.** In cima c'è lo stato attuale, sotto le sessioni in ordine cronologico inverso.

> Repository pubblico: qui non vanno token, password, IP, ID di subscription o altri dati personali.

---

## Stato attuale (aggiornato al 2026-10-12)

| Elemento | Stato |
|---|---|
| Infrastruttura Azure | Creata: 3 VM (lamp, api, broken) in Italy North, un resource group ciascuna |
| VM | **Spente** (deallocate) dal 2026-10-12. Per riaccenderle: `lab/lab.sh start`, poi ~2 minuti di attesa. Gli IP sono statici e non cambiano |
| vm-broken | Guasti presenti (ultimo `break.sh` eseguito il 2026-10-12) |
| Workspace demo | Pronto in `demo/`; il dialogo di fiducia di Claude Code **non è ancora stato accettato** |
| Repository | Pubblicato su GitHub, branch `main` |

### Prossimi passi
- [ ] Avviare `claude` in `demo/` e accettare il dialogo di fiducia
- [ ] Fare una prova completa dei tre atti seguendo `lab/COPIONE.md`
- [ ] Valutare un utente con sudo limitato sulle VM (oggi `claude` ha sudo completo)
- [ ] Facoltativo: certificato non autofirmato per l'API, così da non usare `curl -k`

---

## Sessioni

### 2026-10-12: creazione del laboratorio

**Obiettivo:** preparare un laboratorio per una demo in cui Claude Code gestisce server Linux su Azure in tre modi: SSH, API, troubleshooting.

**Fatto**
1. Definito il piano: tre VM (LAMP via SSH, API REST, server con guasti voluti), infrastruttura come codice, workspace dedicato per Claude, copione della demo.
2. Installato Terraform 1.16.5 sul PC (checksum verificato) e generata la chiave SSH dedicata `~/.ssh/claude_lab_ed25519` (utente root).
3. Scritto il Terraform (`lab/infra`): un modulo `vm` riusato tre volte, ognuno nel proprio resource group con VNet, NSG, IP pubblico e VM Ubuntu 24.04 `Standard_B2s`. La configurazione software viene da cloud-init.
   - **vm-lamp:** Apache, MariaDB, PHP e l'app "Rubrica".
   - **vm-api:** API FastAPI dietro Nginx in HTTPS (certificato autofirmato), autenticata con token Bearer.
   - **vm-broken:** come vm-lamp, più tre guasti (NSG, Apache, password del DB).
4. Eseguito `terraform apply`: 3 VM create e verificate (cloud-init ok, sito, API e guasti come previsto).
5. Creato il workspace `demo/`: `CLAUDE.md`, permessi in `.claude/settings.json`, specifica OpenAPI. Le variabili d'ambiente dell'API sono in `settings.local.json`, generato da Terraform.
6. Scritti `lab/lab.sh` (start/stop/status) e `lab/break.sh` (ripristino e controllo dei guasti). `break.sh` è stato testato sul ciclo completo: correzione manuale → HTTP 200 → `break.sh` → guasti di nuovo presenti.
7. Scritti `lab/COPIONE.md` (scaletta), `lab/README.md` (dettagli tecnici con registro delle modifiche) e `README.md` (summary di scenari e metodologia).
8. Riorganizzato tutto nel repository `~/LinuxDay2026` (`claude-lab` → `lab/`, `claude-demo` → `demo/`), aggiornato ogni percorso e pubblicato su GitHub.

9. Creato questo `STORICO.md`. A fine giornata spente le 3 VM con `lab.sh stop` (deallocate: si pagano solo dischi e IP).

**Decisioni**
- **Un resource group per VM**, su richiesta, per tenere gli scenari isolati.
- **Terraform invece di Bicep**, su richiesta. Lo state è locale e non versionato perché contiene segreti.
- **Regione Italy North:** la B2s è disponibile e c'è quota per 20 vCPU della famiglia B.
- **VM2 "via API"** significa sia l'API REST esposta dalla VM sia le API Azure (`az`) per vederla dall'esterno.
- **Guasti su tre livelli** (Azure → sistema → applicazione), perché il troubleshooting racconti una storia. `break.sh` annulla anche le correzioni alternative, per esempio una password cambiata nel DB invece che in `config.php`.
- **Workspace della demo separato** dall'infrastruttura, con lettura di `lab/` vietata a Claude, perché lì ci sono le soluzioni.
- **Permessi:** le letture `az` partono senza conferma; `ssh` e `curl` chiedono sempre conferma, così il pubblico vede le approvazioni; sono vietati delete/stop/restart delle VM e `terraform`.
- **Repo pubblico con le soluzioni incluse:** scelta esplicita. Restano fuori state, tfvars, token, IP e ID della subscription.

**Problemi incontrati**
- **Auto-shutdown:** `Microsoft.DevTestLab/schedules` non è disponibile in Italy North, e Azure rifiuta di crearlo in un'altra regione (`InvalidScheduleLocation`). La risorsa è stata rimossa e sostituita da `lab.sh stop`.
- **pydantic:** Ubuntu 24.04 ha pydantic 1.x, quindi `Field(pattern=...)` non valida nulla. La validazione della versione ora è fatta a mano nell'endpoint.
- **Workspace non ancora fidato:** finché Claude Code non è stato avviato e il dialogo accettato, le regole `allow` di `settings.json` vengono ignorate.
- **`gh` assente:** installato da dnf. Il token GitHub è salvato in chiaro in `/root/.config/gh/hosts.yml` perché non c'è un keyring.
- **Fedora 39 a fine vita:** i repo copr PyCharm e RPM Fusion NVIDIA danno 404 durante `dnf upgrade`. Sono innocui, ma conviene aggiornare la release del PC.

10. **Verifica dati Azure nel repo:** cercati tenant ID e subscription ID reali (presi da `az account show`) nei file, nei file ignorati e in tutta la cronologia git, più ogni GUID e il nome della subscription. Nessuna occorrenza: l'unico GUID è il segnaposto `00000000-…` in `terraform.tfvars.example`; `terraform.tfvars`, state e `.env.lab` sono esclusi da `.gitignore`.
