import Foundation

/// A fixed sequence, so every shuffle in these checks can be repeated exactly.
struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

// The feed order: every video once a round, never the same video twice in a row.
var emptyBag = ReelShuffleBag()
var emptySeed = SeededGenerator(state: 1)
assert(emptyBag.next(from: [], using: &emptySeed) == nil, "An empty library has nothing to show")

let only = UUID()
var oneBag = ReelShuffleBag()
var oneSeed = SeededGenerator(state: 2)
assert((0..<4).allSatisfy { _ in oneBag.next(from: [only], using: &oneSeed) == only },
       "One video necessarily repeats")

let five = (0..<5).map { _ in UUID() }
for seed in UInt64(1)...40 {
    var bag = ReelShuffleBag()
    var generator = SeededGenerator(state: seed)
    var order: [UUID] = []
    for _ in 0..<25 { order.append(bag.next(from: five, using: &generator)!) }
    for round in 0..<5 {
        assert(Set(order[(round * 5)..<(round * 5 + 5)]) == Set(five),
               "Every video plays exactly once in each round (seed \(seed), round \(round))")
    }
    assert(zip(order, order.dropFirst()).allSatisfy { $0 != $1 },
           "No video plays twice in a row, including across rounds (seed \(seed))")
}
let two = [UUID(), UUID()]
var twoBag = ReelShuffleBag()
var twoSeed = SeededGenerator(state: 9)
let twoOrder = (0..<12).map { _ in twoBag.next(from: two, using: &twoSeed)! }
assert(zip(twoOrder, twoOrder.dropFirst()).allSatisfy { $0 != $1 }, "Two videos strictly alternate")

// The library changing during a round.
var changing = ReelShuffleBag()
var changingSeed = SeededGenerator(state: 5)
let firstShown = changing.next(from: five, using: &changingSeed)!
let removed = five.first { $0 != firstShown }!
let remaining = five.filter { $0 != removed }
var afterRemoval: [UUID] = []
for _ in 0..<3 { afterRemoval.append(changing.next(from: remaining, using: &changingSeed)!) }
assert(!afterRemoval.contains(removed), "A removed video never comes up again")
assert(Set(afterRemoval + [firstShown]) == Set(remaining), "The round still covers every video that is left")

var growing = ReelShuffleBag()
var growingSeed = SeededGenerator(state: 6)
_ = growing.next(from: five, using: &growingSeed)
let added = UUID()
var restOfRound: [UUID] = []
for _ in 0..<5 { restOfRound.append(growing.next(from: five + [added], using: &growingSeed)!) }
assert(restOfRound.contains(added) && Set(restOfRound).count == 5,
       "A video added during a round plays in that round, once")
print("PASS: 9 shuffle assertions (empty, one, rounds, no repeat, removal, addition)")

// Headlines and file names.
assert(ReelVault.headline("  Deadlift  PR \n at the gym ") == "Deadlift PR at the gym", "A headline is one trimmed line")
assert(ReelVault.headline(String(repeating: "x", count: 200)).count == 140, "A headline stops at 140 characters")
assert(ReelVault.headline("   ") == "", "A blank headline is empty")
assert(ReelVault.fileExtension(for: "IMG_0012.MP4") == "mp4" && ReelVault.fileExtension(for: "clip.mov") == "mov"
       && ReelVault.fileExtension(for: "old.avi") == "mov" && ReelVault.fileExtension(for: "noextension") == "mov",
       "Known containers keep their extension; anything else is tried as .mov")
assert(ReelVault.isSafeFileName("6F1F8C1E-4C1E-4E8A-9C1A-111111111111.mp4")
       && !ReelVault.isSafeFileName("../x.mp4") && !ReelVault.isSafeFileName("a/b.mp4")
       && !ReelVault.isSafeFileName(".hidden.mp4") && !ReelVault.isSafeFileName("clip.exe")
       && !ReelVault.isSafeFileName("clip"), "Only a plain video file name is accepted")
assert(ReelVault.durationText(42) == "0:42" && ReelVault.durationText(725) == "12:05"
       && ReelVault.durationText(3729) == "1:02:09" && ReelVault.durationText(0.4) == "0:00")
print("PASS: 6 headline and file-name assertions")

// The library and a backup, checked as a whole.
let noon = Date(timeIntervalSince1970: 1_790_000_000)
func video(_ marker: Character, headline: String = "", name: String? = nil) -> ReelVideo {
    let id = UUID()
    return ReelVideo(id: id, fileName: name ?? "\(id.uuidString).mp4", headline: headline, importedAt: noon,
                     duration: 12.5, byteCount: 4096, fingerprint: String(repeating: marker, count: 64))
}
let a = video("a", headline: "First"), b = video("b", headline: "Second")
assert((try? ReelVault.validated([a, b])) != nil, "A consistent library validates")
assert((try? ReelVault.validated([a, a])) == nil, "The same record twice is refused")
var sameFile = b
sameFile.fingerprint = a.fingerprint
assert((try? ReelVault.validated([a, sameFile])) == nil, "The same video twice is refused")
var badChecksum = a
badChecksum.fingerprint = "xyz"
var empty = a
empty.byteCount = 0
var badName = a
badName.fileName = "../escape.mp4"
var longHeadline = a
longHeadline.headline = String(repeating: "h", count: 141)
for broken in [badChecksum, empty, badName, longHeadline] {
    assert((try? ReelVault.validated([broken])) == nil, "A damaged record is refused")
}

let backup = ReelVaultBackup(createdAt: noon, videos: [a, b])
let decoded = try! ReelVaultBackup.decode(try! backup.encoded())
assert(decoded == backup && decoded.version == ReelVaultBackup.currentVersion, "A backup round-trips exactly")
var newer = backup
newer.version = ReelVaultBackup.currentVersion + 1
do {
    _ = try ReelVaultBackup.decode(try! newer.encoded())
    assert(false, "A newer backup must be refused")
} catch {
    assert(error as? ReelVaultError == .unsupportedVersion, "A newer backup is named as newer, not as damaged")
}
do {
    _ = try ReelVaultBackup.decode(Data("not a backup".utf8))
    assert(false, "Garbage must be refused")
} catch {
    assert(error as? ReelVaultError == .notABackup)
}
assert((try? ReelVaultBackup.decode(try! ReelVaultBackup(createdAt: noon, videos: [a, a]).encoded())) == nil,
       "A backup that fails the library check is refused")

// Restoring: videos are recognised by fingerprint; only headlines change on ones already here.
var hereAlready = a
hereAlready.id = UUID()
hereAlready.headline = "Old headline"
let plan = ReelRestorePlan(backup: backup, library: [hereAlready])
assert(plan.additions == [b], "A video not in the library is added")
assert(plan.headlineChanges == [.init(id: hereAlready.id, headline: "First")],
       "A video already here takes the backup's headline, under its own id")
assert(plan.hasWork)
assert(!ReelRestorePlan(backup: backup, library: [a, b]).hasWork, "An identical library has nothing to restore")
var blankInBackup = a
blankInBackup.headline = ""
assert(ReelRestorePlan(backup: ReelVaultBackup(createdAt: noon, videos: [blankInBackup]), library: [hereAlready])
        .headlineChanges.isEmpty, "A blank headline in the backup never wipes one written since")
print("PASS: 15 library, backup and restore-plan assertions")
