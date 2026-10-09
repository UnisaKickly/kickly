// Punto di ingresso dell'app Kickly.
//
// Questo file deve restare il piu' piccolo possibile: si limita ad avviare
// l'app. Tutta la configurazione (tema, rotte, provider, inizializzazione di
// Supabase...) vive in `app.dart` o nei moduli sotto `lib/`, cosi' da poterla
// testare senza dover lanciare `main()`.
import 'package:flutter/material.dart';

import 'app.dart';

void main() {
  // TODO(Sprint 0): qui andra' l'inizializzazione di Supabase, letta dai
  // valori passati con `--dart-define-from-file=config.json`
  // (vedi README, sezione "Configurazione").
  runApp(const KicklyApp());
}
