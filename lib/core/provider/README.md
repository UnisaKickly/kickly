# core / provider

Provider `flutter_riverpod` condivisi che collegano gli strati: creano i
Repository (strato Data) e li passano alle classi Control (strato Domain), che a
loro volta vengono usate dalle Boundary (strato Presentation).

Tenerli qui permette di sostituire i Repository con dei mock nei test.
Provider presenti: `autenticazione_provider.dart` (AutenticazioneControl e
l'adattatore SessioneAutenticazione per il router, KCK-215),
`gestione_lega_provider.dart` (GestioneLegaControl e id del Giocatore
autenticato per FormLega e VistaLeghe, KCK-249). Gli altri provider
li aggiungono i ticket dei casi d'uso.
