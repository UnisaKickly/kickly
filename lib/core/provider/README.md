# core / provider

Provider `flutter_riverpod` condivisi che collegano gli strati: creano i
Repository (strato Data) e li passano alle classi Control (strato Domain), che a
loro volta vengono usate dalle Boundary (strato Presentation).

Tenerli qui permette di sostituire i Repository con dei mock nei test.
Per ora la cartella e' vuota: i provider verranno aggiunti dai ticket dei casi d'uso.
