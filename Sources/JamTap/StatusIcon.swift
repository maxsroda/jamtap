import AppKit
import JamTapCore

enum StatusIcon {
    /// Height of the menu bar icon in points.
    static let height: CGFloat = 18

    /// A template image: macOS tints it for light and dark menu bars, so only its alpha matters.
    /// The badge (notes, warning mark, dots) sits to the left of the guitar. The menu bar grows
    /// leftwards, so the guitar keeps its place when the badge appears.
    static func image(_ kind: StatusIconKind) -> NSImage {
        let guitarWidth: CGFloat = 19
        let badgeWidth: CGFloat = kind == .idle ? 0 : 12
        let size = NSSize(width: badgeWidth + guitarWidth, height: height)
        let image = NSImage(size: size, flipped: false) { _ in
            let guitarAlpha: CGFloat = kind == .idle ? 0.4 : 1.0
            drawGuitar(in: NSRect(x: badgeWidth, y: 0, width: guitarWidth, height: height),
                       colour: NSColor.black.withAlphaComponent(guitarAlpha))
            let badge = NSRect(x: 0, y: 0, width: badgeWidth, height: height)
            switch kind {
            case .idle:
                break
            case .recording:
                // Two notes flying off to the left: the farther one is smaller, higher and fainter.
                draw(symbol: "music.note", pointSize: 9, weight: .bold,
                     centredIn: NSRect(x: badge.maxX - 7, y: 1, width: 8, height: 11), alpha: 1)
                draw(symbol: "music.note", pointSize: 7, weight: .bold,
                     centredIn: NSRect(x: badge.minX, y: 8, width: 7, height: 9), alpha: 0.75)
            case .recordingSilent:
                draw(symbol: "exclamationmark.triangle.fill", pointSize: 9, weight: .bold,
                     centredIn: badge, alpha: 1)
            case .converting:
                draw(symbol: "ellipsis", pointSize: 9, weight: .bold, centredIn: badge, alpha: 1)
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    /// One Stratocaster-style electric guitar, neck pointing up and to the right.
    /// The SF Symbol "guitars" shows three guitars side by side, which is unreadable at menu bar size.
    private static func drawGuitar(in rect: NSRect, colour: NSColor) {
        guard let context = NSGraphicsContext.current else { return }
        context.saveGraphicsState()
        defer { context.restoreGraphicsState() }

        // The guitar is designed upright, seen from the front, in its own units:
        // x = 0 on the neck axis, y from 0 (strap end) to 23 (headstock tip).
        // The long upper horn and the tuners are on the left (bass) side.
        let designHeight: CGFloat = 23
        let tiltFromVertical: CGFloat = -42  // degrees; negative turns the neck towards the right
        let scale = 0.8 * rect.height / height  // 0.8 points per design unit at menu bar size
        let transform = NSAffineTransform()
        transform.translateX(by: rect.midX, yBy: rect.midY)
        transform.rotate(byDegrees: tiltFromVertical)
        transform.scale(by: scale)
        transform.translateX(by: 0, yBy: -designHeight / 2)
        transform.concat()

        let body = NSBezierPath()
        body.move(to: NSPoint(x: -1.0, y: 9.6))                       // neck pocket, bass side
        body.curve(to: NSPoint(x: -3.3, y: 12.6),                     // cutaway up to the long horn
                   controlPoint1: NSPoint(x: -2.0, y: 8.7), controlPoint2: NSPoint(x: -2.3, y: 11.4))
        body.curve(to: NSPoint(x: -4.5, y: 11.4),                     // rounded tip of the long horn
                   controlPoint1: NSPoint(x: -3.9, y: 13.2), controlPoint2: NSPoint(x: -4.6, y: 12.5))
        body.curve(to: NSPoint(x: -3.8, y: 5.7),                      // bass side down to the waist
                   controlPoint1: NSPoint(x: -4.4, y: 9.4), controlPoint2: NSPoint(x: -3.2, y: 7.6))
        body.curve(to: NSPoint(x: 0.4, y: 0),                         // lower bout, bass side
                   controlPoint1: NSPoint(x: -5.8, y: 3.4), controlPoint2: NSPoint(x: -3.6, y: 0))
        body.curve(to: NSPoint(x: 4.0, y: 5.3),                       // lower bout, treble side
                   controlPoint1: NSPoint(x: 4.2, y: 0), controlPoint2: NSPoint(x: 5.9, y: 2.8))
        body.curve(to: NSPoint(x: 3.7, y: 10.6),                      // treble side up to the short horn
                   controlPoint1: NSPoint(x: 3.2, y: 6.6), controlPoint2: NSPoint(x: 4.8, y: 8.6))
        body.curve(to: NSPoint(x: 2.6, y: 11.0),                      // rounded tip of the short horn
                   controlPoint1: NSPoint(x: 3.6, y: 11.3), controlPoint2: NSPoint(x: 2.9, y: 11.5))
        body.curve(to: NSPoint(x: 1.0, y: 9.6),                       // cutaway back to the neck pocket
                   controlPoint1: NSPoint(x: 2.2, y: 10.2), controlPoint2: NSPoint(x: 1.7, y: 9.0))
        body.close()

        let neck = NSBezierPath(rect: NSRect(x: -0.85, y: 9.2, width: 1.7, height: 9.4))

        // Six-in-line headstock: straight on the treble side, bulging towards the tuners, round tip.
        let headstock = NSBezierPath()
        headstock.move(to: NSPoint(x: 0.85, y: 18.0))
        headstock.line(to: NSPoint(x: 0.95, y: 21.4))
        headstock.curve(to: NSPoint(x: -0.5, y: 23.0),
                        controlPoint1: NSPoint(x: 1.0, y: 22.5), controlPoint2: NSPoint(x: 0.3, y: 23.1))
        headstock.curve(to: NSPoint(x: -1.8, y: 21.6),
                        controlPoint1: NSPoint(x: -1.3, y: 22.9), controlPoint2: NSPoint(x: -1.9, y: 22.4))
        headstock.curve(to: NSPoint(x: -2.3, y: 19.6),
                        controlPoint1: NSPoint(x: -1.6, y: 20.8), controlPoint2: NSPoint(x: -2.3, y: 20.5))
        headstock.curve(to: NSPoint(x: -0.85, y: 18.0),
                        controlPoint1: NSPoint(x: -2.3, y: 18.6), controlPoint2: NSPoint(x: -1.1, y: 18.9))
        headstock.close()

        colour.setFill()
        context.compositingOperation = .copy
        for part in [body, neck, headstock] { part.fill() }

        // Three pickups are cut out of the body; the bridge pickup is slanted, as on a Strat.
        context.compositingOperation = .destinationOut
        NSColor.black.setFill()
        NSBezierPath(rect: NSRect(x: -1.5, y: 7.3, width: 3.0, height: 0.7)).fill()
        NSBezierPath(rect: NSRect(x: -1.5, y: 5.6, width: 3.0, height: 0.7)).fill()
        let bridgePickup = NSBezierPath()
        bridgePickup.move(to: NSPoint(x: -1.5, y: 3.5))
        bridgePickup.line(to: NSPoint(x: 1.5, y: 4.3))
        bridgePickup.line(to: NSPoint(x: 1.5, y: 3.6))
        bridgePickup.line(to: NSPoint(x: -1.5, y: 2.8))
        bridgePickup.close()
        bridgePickup.fill()
    }

    private static func draw(symbol name: String, pointSize: CGFloat, weight: NSFont.Weight,
                             centredIn rect: NSRect, alpha: CGFloat, colour: NSColor? = nil) {
        var configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
        if let colour { configuration = configuration.applying(.init(paletteColors: [colour])) }
        guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration) else { return }
        let origin = NSPoint(x: rect.midX - symbol.size.width / 2, y: rect.midY - symbol.size.height / 2)
        symbol.draw(in: NSRect(origin: origin, size: symbol.size), from: .zero,
                    operation: .sourceOver, fraction: alpha)
    }

    /// The app icon, shown in notifications and in Finder: the recording icon in white on a sunburst
    /// finish, as a PNG of 1024 × 1024 pixels.
    static func writeAppIcon(to url: URL) throws {
        let side: CGFloat = 1024
        // The white drawing is made on its own transparent layer, because the pickups are cut out of
        // the guitar and must not cut through the background.
        let drawing = NSImage(size: NSSize(width: side, height: side), flipped: false) { _ in
            drawGuitar(in: NSRect(x: 320, y: 225, width: 600, height: 600), colour: .white)
            draw(symbol: "music.note", pointSize: 190, weight: .bold,
                 centredIn: NSRect(x: 240, y: 305, width: 200, height: 240), alpha: 1, colour: .white)
            draw(symbol: "music.note", pointSize: 130, weight: .bold,
                 centredIn: NSRect(x: 140, y: 555, width: 150, height: 180), alpha: 0.8, colour: .white)
            return true
        }
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(side), pixelsHigh: Int(side),
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                      colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        // macOS app icons are a rounded square of 824 points centred in the 1024-point canvas.
        let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
        let amber = NSColor(red: 0.96, green: 0.62, blue: 0.16, alpha: 1)
        let cherry = NSColor(red: 0.62, green: 0.13, blue: 0.09, alpha: 1)
        let nearBlack = NSColor(red: 0.13, green: 0.05, blue: 0.04, alpha: 1)
        NSGradient(colorsAndLocations: (amber, 0), (cherry, 0.62), (nearBlack, 1))!
            .draw(in: NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185), relativeCenterPosition: .zero)
        drawing.draw(in: NSRect(x: 0, y: 0, width: side, height: side))
        NSGraphicsContext.restoreGraphicsState()
        try bitmap.representation(using: .png, properties: [:])!.write(to: url)
    }

    /// Writes each icon as a PNG on a dark and on a light strip, to judge it outside the menu bar.
    static func writePreviews(to directory: URL, scale: CGFloat = 8) throws {
        for kind in StatusIconKind.allCases {
            for (themeName, background, tint) in [("dark", NSColor(white: 0.12, alpha: 1), NSColor.white),
                                                  ("light", NSColor(white: 0.93, alpha: 1), NSColor.black)] {
                let icon = image(kind)
                let padding: CGFloat = 6
                let pixelSize = NSSize(width: (icon.size.width + 2 * padding) * scale,
                                       height: (icon.size.height + 2 * padding) * scale)
                let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(pixelSize.width),
                                              pixelsHigh: Int(pixelSize.height), bitsPerSample: 8,
                                              samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                              colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
                background.setFill()
                NSRect(origin: .zero, size: pixelSize).fill()
                let iconRect = NSRect(x: padding * scale, y: padding * scale,
                                      width: icon.size.width * scale, height: icon.size.height * scale)
                // Tint the way the menu bar tints a template image: colour where the icon has alpha.
                let tinted = NSImage(size: icon.size, flipped: false) { rect in
                    icon.draw(in: rect)
                    tint.setFill()
                    rect.fill(using: .sourceIn)
                    return true
                }
                tinted.draw(in: iconRect)
                NSGraphicsContext.restoreGraphicsState()
                let url = directory.appendingPathComponent("icon-\(kind.rawValue)-\(themeName).png")
                try bitmap.representation(using: .png, properties: [:])!.write(to: url)
            }
        }
    }
}
