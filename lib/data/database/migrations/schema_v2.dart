// Migrasi skema v2: modul Catatan & Koleksi (bacaan/tontonan).
// Hanya MENAMBAH tabel/index/trigger — data v1 tidak disentuh.
//
// Indeks pencarian notes_fts (FTS5) menyimpan note_id sebagai kolom UNINDEXED
// (bukan external-content berbasis rowid, karena rowid tabel ber-PK teks bisa
// berubah saat VACUUM). Disinkronkan trigger; tidak ikut backup.

const List<String> schemaV2Statements = [
  "CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts USING fts5("
      "note_id UNINDEXED, title, body, tokenize = 'unicode61 remove_diacritics 2')",
  '''CREATE TRIGGER trg_notes_fts_ai AFTER INSERT ON notes BEGIN
       INSERT INTO notes_fts (note_id, title, body) VALUES (NEW.id, NEW.title, NEW.body);
     END''',
  '''CREATE TRIGGER trg_notes_fts_au AFTER UPDATE OF title, body ON notes BEGIN
       DELETE FROM notes_fts WHERE note_id = OLD.id;
       INSERT INTO notes_fts (note_id, title, body) VALUES (NEW.id, NEW.title, NEW.body);
     END''',
  '''CREATE TRIGGER trg_notes_fts_ad AFTER DELETE ON notes BEGIN
       DELETE FROM notes_fts WHERE note_id = OLD.id;
     END''',
  'CREATE INDEX IF NOT EXISTS notes_list_idx ON notes (is_archived, is_pinned, updated_at DESC)',
  'CREATE INDEX IF NOT EXISTS note_tags_tag_idx ON note_tags (tag)',
  'CREATE INDEX IF NOT EXISTS note_attachments_note_idx ON note_attachments (note_id)',
  'CREATE INDEX IF NOT EXISTS note_links_entity_idx ON note_links (entity_type, entity_id)',
  'CREATE INDEX IF NOT EXISTS watchlist_items_status_idx ON watchlist_items (status, updated_at DESC)',
  'CREATE INDEX IF NOT EXISTS watchlist_items_type_idx ON watchlist_items (type)',
  'CREATE INDEX IF NOT EXISTS watchlist_item_ideas_idea_idx ON watchlist_item_ideas (idea_id)',
];

/// Bangun ulang indeks pencarian dari isi tabel notes (dipakai setelah restore).
const List<String> rebuildNotesFts = [
  'DELETE FROM notes_fts',
  'INSERT INTO notes_fts (note_id, title, body) SELECT id, title, body FROM notes',
];
