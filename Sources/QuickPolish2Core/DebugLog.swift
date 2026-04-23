import Foundation

/// File + NSLog logger used during debugging. All entries go to
/// `~/.quickpolish/quickpolish.log` so we can `tail -f` the file from a
/// terminal even when Xcode's console swallows stdout.
public enum DebugLog {
    public static let logFile: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".quickpolish")
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true
        )
        return dir.appendingPathComponent("quickpolish.log")
    }()

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()

    private static let queue = DispatchQueue(label: "com.quickpolish.debuglog")

    public static func info(_ message: @autoclosure () -> String,
                            file: String = #file, line: Int = #line) {
        let msg = message()
        let stamp = formatter.string(from: Date())
        let loc = (file as NSString).lastPathComponent
        let line = "\(stamp) [QP] \(loc):\(line) \(msg)\n"

        NSLog("[QP] %@", msg)
        queue.async {
            if let handle = try? FileHandle(forWritingTo: logFile) {
                handle.seekToEndOfFile()
                handle.write(Data(line.utf8))
                try? handle.close()
            } else {
                try? line.write(to: logFile, atomically: true, encoding: .utf8)
            }
        }
    }
}
