import Foundation

func expect(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL \(message)\n", stderr)
        exit(1)
    }
}

expect(BeegCatalog.displayName("Big {Tits}") == "Big Tits", "braces")
expect(BeegCatalog.compactCount(1_116_774) == "1.1M", "millions")
expect(BeegCatalog.compactCount(4_656) == "4.7K", "thousands")
expect(BeegCatalog.compactCount(316) == "316", "small")
expect(BeegCatalog.duration(782) == "13:02", "duration")

let calendar = Calendar(identifier: .gregorian)
let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 10, hour: 15))!
let today = calendar.date(byAdding: .hour, value: -4, to: now)!
let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
let formatter = ISO8601DateFormatter()
formatter.formatOptions = [.withInternetDateTime]
expect(BeegCatalog.relativeDate(formatter.string(from: today), now: now) == "Today", "today")
expect(BeegCatalog.relativeDate(formatter.string(from: yesterday), now: now) == "Yesterday", "yesterday")

let template = "key=abc,end=1,limit=10/data=ff/media=hls4A/_TPL_/777.mp4.m3u8"
let master = BeegCatalog.masterPlaylist(template: template, fileID: 777)
expect(master?.absoluteString.contains("video.beeg.com/key=abc") == true, "master host")
expect(BeegCatalog.masterPlaylist(template: "https://evil.example/x.m3u8", fileID: 1) == nil, "reject absolute")
expect(BeegCatalog.masterPlaylist(template: "../secret.m3u8", fileID: 1) == nil, "reject traversal")

let playlist = """
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=100,RESOLUTION=426x240
/key=a/240p/1.mp4.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=900,RESOLUTION=1920x1080
/key=b/1080p/1.mp4.m3u8
"""
expect(BeegCatalog.preferredVariant(playlist) == "/key=b/1080p/1.mp4.m3u8", "highest variant")
expect(BeegCatalog.variants(playlist).map(\.label) == ["1080p", "240p"], "quality labels")
let duplicated = playlist + "\n#EXT-X-STREAM-INF:BANDWIDTH=800,RESOLUTION=1280x720\n/key=c/720a.m3u8\n#EXT-X-STREAM-INF:BANDWIDTH=700,RESOLUTION=1280x720\n/key=d/720b.m3u8\n"
expect(BeegCatalog.variants(duplicated).map(\.label) == ["1080p", "720p", "240p"], "dedupe qualities")
expect(BeegCatalog.preferredVariant("#EXTM3U\nhttps://evil.example/x.m3u8") == nil, "reject remote variant")
expect(BeegCatalog.isCancellation(CancellationError()), "cancellation error")
expect(BeegCatalog.isCancellation(URLError(.cancelled)), "url cancellation")
expect(!BeegCatalog.isCancellation(URLError(.timedOut)), "timeout is visible")

print("beeg catalog regression passed")
