import AppKit
import SwiftUI

enum StatusIconRenderer {

    /// 14×14 색상 점 NSImage 를 생성한다 (StatusBar 표준 사이즈).
    /// 동일 level 호출은 캐시에서 즉시 반환.
    static func makeDotIcon(level: StatusLevel) -> NSImage {
        if let cached = cache[level] { return cached }
        let image = render(level: level)
        cache[level] = image
        return image
    }

    // MARK: - Private

    private static var cache: [StatusLevel: NSImage] = [:]

    private static func render(level: StatusLevel) -> NSImage {
        let size = NSSize(width: 14, height: 14)
        let image = NSImage(size: size)
        image.lockFocus()

        let color = NSColor(level.displayColor)
        color.setFill()

        let dotRect = NSRect(x: 2, y: 2, width: 10, height: 10)
        NSBezierPath(ovalIn: dotRect).fill()

        image.unlockFocus()
        return image
    }
}
