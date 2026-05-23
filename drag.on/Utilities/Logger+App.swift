import os

extension Logger {
    /// Logger for the Lair file store operations.
    static let lairStore = Logger(subsystem: "com.yokai.drag-on", category: "LairStore")
    /// Logger for image conversion operations.
    static let converter = Logger(subsystem: "com.yokai.drag-on", category: "ImageConverter")
    /// Logger for drag monitoring operations.
    static let dragMonitor = Logger(subsystem: "com.yokai.drag-on", category: "DragMonitor")
    /// Logger for file item operations.
    static let fileItem = Logger(subsystem: "com.yokai.drag-on", category: "FileItem")
}
