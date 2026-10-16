import Foundation
var entry = JournalEntry(day: "2026-10-15", zone: "UTC")
entry.mood = 3; entry.completedAt = Date()
var state = JournalState(entries: [entry])
do { _ = try state.validated(); fatalError("An empty entry qualified") } catch {}
entry.text = "A small lesson"; state.entries = [entry]
let checked = try state.validated()
precondition(checked.entries[0].qualifies)
entry.photos = ["../outside.jpg"]; state.entries = [entry]
do { _ = try state.validated(); fatalError("Escaping media accepted") } catch {}
entry.photos = []; entry.mood = 6; state.entries = [entry]
do { _ = try state.validated(); fatalError("Invalid mood accepted") } catch {}
entry.mood = nil; entry.completedAt = nil
precondition(!entry.qualifies)
let bytes = try LocalDataCoding.encode(JournalState(entries: [entry]))
let decoded = try LocalDataCoding.decode(JournalState.self, bytes)
precondition(decoded.entries[0] == entry)
print("Journal: completion, privacy-safe data format and unsafe media validation passed")
