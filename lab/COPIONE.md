# Copione demo (~30 minuti)

## Prima della demo
1. `~/LinuxDay2026/lab/lab.sh start`, poi aspetta ~2 minuti.
2. `~/LinuxDay2026/lab/break.sh`: rimette i guasti su vm-broken e alla fine mostra il check.
3. `cd ~/LinuxDay2026/demo && claude`. Al primo avvio accetta il dialogo "trust this folder".

## Atto 1: SSH su vm-lamp (8')
- "Controlla lo stato del server LAMP: servizi, spazio disco, ultimi errori di Apache."
- "Quanti contatti ci sono nella rubrica? Aggiungi 'Linus Torvalds' con email linus@example.com."
- "Crea un virtual host per demo.local che serva una pagina 'Ciao dalla demo', poi verificalo con curl usando l'header Host."

## Atto 2: API su vm-api (8')
- "Leggi la specifica dell'API e dimmi cosa posso fare."
- "Com'è lo stato del server e dei servizi? Qual è la versione in produzione?"
- "Fai il deploy della versione 1.1.0 con nota 'demo live', poi mostrami lo storico."
- "Confronta quello che dice l'API con quello che vede Azure sulla VM (stato, metriche CPU)."

## Atto 3: troubleshooting su vm-broken (12')
- "Gli utenti dicono che la rubrica su vm-broken non funziona. Trova la causa e proponi le correzioni."

Soluzioni attese (in ordine):
1. NSG `nsg-broken`: la regola `Deny-HTTP-Maintenance` (prio 105) blocca la porta 80 → eliminarla.
2. Apache non parte: `conf-enabled/security-hardening.conf` include `/etc/apache2/hardening/headers.conf`, che non esiste → `a2disconf` oppure creare il file.
3. Errore 500 "impossibile collegarsi al database": password sbagliata in `/var/www/html/config.php`.
   La password giusta non è sul server, quindi Claude dovrà proporre di reimpostarla nel DB (`ALTER USER`) e allineare config.php.

## Dopo la demo
- `~/LinuxDay2026/lab/break.sh` per la prossima prova, `~/LinuxDay2026/lab/lab.sh stop` per non pagare.
- Smontaggio definitivo: `cd ~/LinuxDay2026/lab/infra && terraform destroy`.
