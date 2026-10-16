import Foundation
var state = WatchlistState()
let title = WatchTitle(title: "Synthetic title")
let source = UUID()
var transfer = WatchlistTransfer(sourceID: source, revision: 1, titles: [title])
try state.apply(transfer); state.mark(title.id, watched: true, at: Date())
precondition(state.watched(title.id))
do { try state.apply(transfer); fatalError("Replay accepted") } catch {}
transfer.revision = 2; transfer.titles = []
try state.apply(transfer)
precondition(state.titles.count == 1 && state.watched(title.id), "Absence must not erase titles or watched events")
transfer.revision = 3; transfer.titles = [title]
let counts = try state.importCounts(transfer)
precondition(counts.changed == 0)
var deleted = title; deleted.deleted = true
transfer.revision = 4; transfer.titles = [deleted]
try state.apply(transfer)
precondition(state.titles[0].deleted && state.events.count == 1)
var foreign = transfer; foreign.sourceID = UUID(); foreign.revision = 5
do { try state.apply(foreign); fatalError("Second writer accepted") } catch {}
print("Watchlist: source ownership, replay, explicit tombstones and event preservation passed")
