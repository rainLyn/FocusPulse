import SwiftUI
import UniformTypeIdentifiers

// ═════════════════════════════════════════════════════════════
//  CSVDocument — FileDocument 适配器
//  用于 .fileExporter 导出 CSV 数据
// ═════════════════════════════════════════════════════════════
struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
