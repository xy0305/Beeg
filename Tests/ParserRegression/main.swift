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

let now = ISO8601DateFormatter().date(from: "2026-10-10T12:00:00Z")!
expect(BeegCatalog.relativeDate("2026-10-09T18:10:57.561783Z", now: now) == "Today", "today")
expect(BeegCatalog.relativeDate("2026-10-08T10:00:00Z", now: now) == "Yesterday", "yesterday")

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
expect(BeegCatalog.preferredVariant("#EXTM3U\nhttps://evil.example/x.m3u8") == nil, "reject remote variant")

print("beeg catalog regression passed")
