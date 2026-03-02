import AppKit
import Foundation

protocol ClipboardChangeSource: AnyObject {
    var changeCount: Int { get }
}

extension NSPasteboard: ClipboardChangeSource {}
