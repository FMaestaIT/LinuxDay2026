# Laboratorio server

Questo workspace serve a gestire tre server Linux su Azure (Ubuntu 24.04, regione Italy North).
Lavori dal PC dell'operatore: i server si raggiungono via SSH, via HTTPS o tramite Azure CLI (`az`, già autenticata sulla subscription giusta).

## Server

| Server | Resource group | Accesso | Ruolo |
|---|---|---|---|
| vm-lamp | rg-claude-lab-lamp | `ssh lab-lamp` | Server LAMP (Apache, MariaDB, PHP) con l'app "Rubrica" in /var/www/html |
| vm-api | rg-claude-lab-api | API REST su `$LAB_API_URL` | Server applicativo gestito tramite la sua API |
| vm-broken | rg-claude-lab-broken | `ssh lab-broken` | Server LAMP con l'app "Rubrica", segnalato come non funzionante |

Ogni server ha un proprio resource group con VNet, NSG e IP pubblico (`vnet-<nome>`, `nsg-<nome>`, `pip-<nome>`).

## Come accedere

- **SSH**: gli alias `lab-lamp` e `lab-broken` sono già configurati (utente `claude`, sudo senza password).
  Esegui un comando alla volta da qui, ad esempio `ssh lab-lamp 'sudo systemctl status apache2'`. Non aprire sessioni interattive.
- **API di vm-api**: l'URL è in `$LAB_API_URL`, il token in `$LAB_API_TOKEN`.
  La specifica è in `api/openapi.json` (sempre aggiornata anche su `$LAB_API_URL/openapi.json`).
  Autenticazione: header `Authorization: Bearer $LAB_API_TOKEN`. Il certificato è autofirmato: usa `curl -sk`.
  Usa sempre la variabile, mai il valore del token: non stamparlo e non scriverlo in file o output.
- **Azure**: usa `az` per vedere lo stato delle VM, le regole NSG, le metriche e i log di boot.

## Come lavorare

- Prima osserva, poi agisci: parti da comandi di sola lettura (stato, log, configurazione) e spiega cosa trovi.
- Prima di modificare qualcosa (file di configurazione, servizi, regole NSG, deploy) descrivi la modifica e il motivo, poi eseguila.
- Prima di modificare un file di configurazione, fanne una copia `.bak`. Dopo ogni modifica verifica che abbia avuto effetto.
- Non spegnere, riavviare o eliminare le VM e non toccare risorse fuori dai tre resource group del laboratorio.
- Per il troubleshooting, procedi per livelli: rete e Azure (NSG, IP, stato VM), poi sistema (servizi, log, disco), poi applicazione. Alla fine riassumi causa, correzione e verifica.
- Rispondi in italiano, in modo conciso: l'operatore sta presentando a un pubblico.
