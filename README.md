# Claude e i server: scenari e metodologia

Materiale della demo presentata al **Linux Day 2026**: mostra come un assistente AI da riga di comando, **Claude Code**, può gestire dei server reali in modo controllato.
L'ambiente è composto da tre macchine Linux su Microsoft Azure. Ognuna rappresenta un modo diverso di interfacciarsi con un'infrastruttura.

---

## Gli scenari

### 1. Amministrazione via SSH: `vm-lamp`

Un server web classico LAMP (Linux, Apache, MariaDB, PHP) che ospita una piccola applicazione "Rubrica".

- **Canale:** SSH con chiave, un comando alla volta (`ssh lab-lamp '<comando>'`)
- **Cosa fa Claude:** legge lo stato dei servizi e i log, interroga il database, modifica configurazioni, pubblica contenuti e verifica il risultato
- **Cosa dimostra:** Claude lavora come un sistemista, con gli stessi strumenti (`systemctl`, `journalctl`, `apache2ctl`, `mysql`, `curl`) e le stesse procedure

### 2. Gestione via API: `vm-api`

Un server applicativo che non si amministra entrando nella macchina: espone invece un'**API REST** documentata con OpenAPI.

- **Canale:** HTTPS con token Bearer (`curl` verso `$LAB_API_URL`)
- **Cosa fa Claude:** legge la specifica (`api/openapi.json`), capisce da solo quali operazioni esistono, interroga stato, servizi e log ed esegue un deploy
- **Cosa dimostra:** anche senza accesso al sistema operativo Claude lavora su un contratto formale (la specifica dell'API) e interpreta risposte strutturate (JSON)

In parallelo Claude usa le **API di Azure** (tramite `az`) per vedere la stessa macchina "da fuori": stato della VM, rete, metriche.

### 3. Troubleshooting: `vm-broken`

Una copia del server LAMP che "non funziona": gli utenti segnalano che l'applicazione non è raggiungibile.

- **Canali:** SSH + API di Azure
- **Cosa fa Claude:** parte dal sintomo, raccoglie evidenze, formula ipotesi, individua le cause e propone le correzioni, poi le applica dopo l'approvazione dell'operatore e verifica che il servizio sia tornato a funzionare
- **Cosa dimostra:** un'analisi metodica su più livelli, non un singolo comando

---

## I canali a confronto

| | SSH | API REST | API Azure (`az`) |
|---|---|---|---|
| **Livello** | Sistema operativo | Applicazione | Infrastruttura cloud |
| **Autenticazione** | Chiave SSH dedicata al lab | Token Bearer in variabile d'ambiente | Login Azure dell'operatore |
| **Cosa si vede** | Tutto: file, processi, log | Solo ciò che l'API espone | Risorse: VM, rete, NSG, metriche |
| **Punti di forza** | Massima flessibilità | Operazioni controllate e tracciabili | Visione "dall'esterno", indipendente dalla VM |
| **Limiti** | Richiede accesso alla macchina | Fa solo quello che l'API prevede | Non vede dentro il sistema operativo |

Nei casi reali i canali si combinano: per esempio la rete si diagnostica con `az` e il servizio via SSH.

---

## La metodologia

### Il ciclo di lavoro

```
  osserva ──► spiega ──► proponi ──► (approvazione) ──► agisci ──► verifica
     ▲                                                               │
     └───────────────────────────────────────────────────────────────┘
```

1. **Osserva:** prima i comandi di sola lettura (stato, log, configurazione).
2. **Spiega:** riassume cosa ha trovato, in linguaggio chiaro.
3. **Proponi:** descrive la modifica e il motivo prima di farla.
4. **Agisci:** solo dopo l'approvazione dell'operatore, e con una copia di backup dei file che modifica.
5. **Verifica:** controlla che la modifica abbia avuto l'effetto atteso.

### Troubleshooting per livelli

Quando qualcosa non funziona, l'analisi procede dall'esterno verso l'interno:

1. **Rete e cloud:** la VM è accesa? L'IP è corretto? Le regole di rete lasciano passare il traffico?
2. **Sistema:** i servizi sono attivi? Cosa dicono i log? C'è spazio su disco?
3. **Applicazione:** l'app riesce a parlare con le sue dipendenze (es. il database)? Cosa restituisce?

Alla fine Claude riassume **causa, correzione e verifica** per ogni problema trovato.

---

## Controllo e sicurezza

L'operatore resta sempre al comando.

- **Approvazione esplicita:** ogni comando SSH e ogni chiamata API richiede conferma prima di essere eseguita. Solo le letture su Azure partono senza conferma.
- **Azioni vietate:** Claude non può eliminare, spegnere o riavviare le VM, né modificare l'infrastruttura con Terraform.
- **Segreti fuori dallo schermo:** il token dell'API è in una variabile d'ambiente; Claude lo usa senza mai leggerlo o stamparlo.
- **Superficie ridotta:** le VM accettano connessioni solo dall'IP dell'operatore e la chiave SSH è dedicata al laboratorio.
- **Contesto esplicito:** il file `CLAUDE.md` descrive a Claude l'ambiente e le regole di lavoro; le regole tecniche stanno in `.claude/settings.json`.

---

## Come si usa

```bash
cd demo
claude
```

Poi si chiede in linguaggio naturale, per esempio:

- *"Controlla lo stato del server LAMP."*
- *"Leggi la specifica dell'API e dimmi lo stato del server applicativo."*
- *"Gli utenti dicono che la rubrica su vm-broken non funziona: trova la causa."*

---

## Struttura del repository

```
LinuxDay2026/
├── README.md                 # questo documento
├── demo/                     # workspace da cui si avvia Claude durante la demo
│   ├── CLAUDE.md             # istruzioni e contesto per Claude
│   ├── api/openapi.json      # specifica dell'API di vm-api
│   └── .claude/settings.json # permessi di Claude in questo workspace
└── lab/                      # infrastruttura e materiale del presentatore
    ├── README.md             # dettagli tecnici della configurazione
    ├── COPIONE.md            # scaletta della demo
    ├── lab.sh, break.sh      # gestione VM e ripristino dei guasti
    └── infra/                # Terraform + cloud-init
```

Per ricreare il laboratorio nella propria subscription Azure: vedi [`lab/README.md`](lab/README.md).

> ⚠️ `lab/` contiene anche le soluzioni dello scenario di troubleshooting.
