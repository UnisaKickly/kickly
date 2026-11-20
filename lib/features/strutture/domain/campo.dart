// Entity Campo del class diagram (docs/modelli/class.puml).
//
// Rappresenta un campo della struttura sportiva di un Gestore (associazione
// GestoreCampo 1 — 0..* Campo). Fornisce la tariffa da dividere tra i
// partecipanti e gli orari di disponibilita' (tabella degli oggetti del RAD).

/// Campo sportivo di un Gestore, letto dalla tabella `campo`.
///
/// `id` e `gestoreCampoId` sono attributi tecnici di mappatura
/// (class_diagram_sdd.md §3, regola 9).
class Campo {
  /// Chiave del campo (colonna `id`).
  final String id;

  /// Chiave esterna verso il GestoreCampo proprietario (colonna
  /// `gestore_campo_id`); obbligatoria per la molteplicita' 1 (regola 8).
  final String gestoreCampoId;

  /// Nome del campo.
  final String nome;

  /// Ubicazione del campo.
  final String ubicazione;

  /// Tariffa oraria del campo, usata per calcolare la quota individuale
  /// (UC_PAR_1 passo 3).
  final double tariffaOraria;

  /// Orari di disponibilita' del campo, colonna di Campo e non una tabella
  /// (class_diagram_sdd.md §3, regola 5).
  final String orariDisponibilita;

  /// Crea un Campo con tutti gli attributi del class diagram.
  const Campo({
    required this.id,
    required this.gestoreCampoId,
    required this.nome,
    required this.ubicazione,
    required this.tariffaOraria,
    required this.orariDisponibilita,
  });

  /// Crea un Campo da una riga di `campo` come la restituisce Supabase.
  /// La tariffa puo' arrivare come intero (es. 60) o con decimali (es. 60.5):
  /// la si legge come numero e la si converte in double. Non valida i valori.
  factory Campo.fromJson(Map<String, dynamic> json) {
    return Campo(
      id: json['id'] as String,
      gestoreCampoId: json['gestore_campo_id'] as String,
      nome: json['nome'] as String,
      ubicazione: json['ubicazione'] as String,
      tariffaOraria: (json['tariffa_oraria'] as num).toDouble(),
      orariDisponibilita: json['orari_disponibilita'] as String,
    );
  }

  /// Converte il Campo nella mappa delle colonne di `campo`, con i nomi della
  /// regola 9 (`<entity>_id` per la chiave esterna).
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gestore_campo_id': gestoreCampoId,
      'nome': nome,
      'ubicazione': ubicazione,
      'tariffa_oraria': tariffaOraria,
      'orari_disponibilita': orariDisponibilita,
    };
  }
}
