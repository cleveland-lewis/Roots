import Foundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum NotesRichTextStorage {
    private static let rtfPrefix = "rtf:"

    static func attributedString(from raw: String) -> NSAttributedString {
        if raw.hasPrefix(rtfPrefix) {
            let payload = String(raw.dropFirst(rtfPrefix.count))
            if let data = Data(base64Encoded: payload),
               let attributed = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
               ) {
                return attributed
            }
        }
        return NSAttributedString(string: raw)
    }

    static func plainText(from raw: String) -> String {
        let attributed = attributedString(from: raw)
        return attributed.string
    }

    static func encode(_ attributed: NSAttributedString) -> String {
        if !hasFormatting(attributed) {
            return attributed.string
        }

        let range = NSRange(location: 0, length: attributed.length)
        guard let data = try? attributed.data(
            from: range,
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        ) else {
            return attributed.string
        }
        return rtfPrefix + data.base64EncodedString()
    }

    private static func hasFormatting(_ attributed: NSAttributedString) -> Bool {
        var hasTrait = false
        let fullRange = NSRange(location: 0, length: attributed.length)
        attributed.enumerateAttribute(.font, in: fullRange, options: []) { value, _, stop in
            guard let font = value as? PlatformFont else { return }
            if fontIsBoldOrItalic(font) {
                hasTrait = true
                stop.pointee = true
            }
        }
        return hasTrait
    }

    private static func fontIsBoldOrItalic(_ font: PlatformFont) -> Bool {
        #if os(macOS)
        let traits = font.fontDescriptor.symbolicTraits
        return traits.contains(.bold) || traits.contains(.italic)
        #else
        let traits = font.fontDescriptor.symbolicTraits
        return traits.contains(.traitBold) || traits.contains(.traitItalic)
        #endif
    }
}

#if os(macOS)
typealias PlatformFont = NSFont
#else
typealias PlatformFont = UIFont
#endif
