// JumpToTop
























// How to navigate through this file?
// CMD + F, search: "Search: " and add what you're searching for after, example: Search: Attributed Strings
// CMD + F, search: "JumpToTop" to jump to the top of this file
// CMD + F, search: "JumpToBottom" to jump to the bottom of this file


















// Search: Imports

import Foundation
import Cocoa
import ObjectiveC

// Search: URLs

extension URL {
    @MainActor
    func fetchNSImage() async -> NSImage? {
        do {
            let (data, _) = try await URLSession.shared.data(from: self)
            return NSImage(data: data)
        } catch {
            return nil
        }
    }
}

// Search: NSImages
extension NSImage {
    func jpegData(compressionQuality: CGFloat) -> Data? {
        guard let tiffRepresentation = tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffRepresentation) else { return nil }
        return bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
    }

    func pngData() -> Data? {
        guard let tiffRepresentation = tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffRepresentation) else { return nil }
        return bitmapImage.representation(using: .png, properties: [:])
    }
}
extension NSImage {
    func roundedIcon(withCornerRadius radius: CGFloat? = nil, paddingFraction: CGFloat = 0.1) -> NSImage? {
        let imgSize = self.size
        let cornerRadius = radius ?? imgSize.width / 5
        
        let newImage = NSImage(size: imgSize)
        newImage.lockFocus()
        
        let fullRect = NSRect(origin: .zero, size: imgSize)
        
        let padding = imgSize.width * paddingFraction
        let paddedRect = fullRect.insetBy(dx: padding, dy: padding)
        
        let clipPath = NSBezierPath(roundedRect: paddedRect, xRadius: cornerRadius, yRadius: cornerRadius)
        clipPath.addClip()
        
        self.draw(in: paddedRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        
        newImage.unlockFocus()
        newImage.isTemplate = self.isTemplate
        
        return newImage
    }
}

extension NSImage {
    func roundedIconCustomBG(
        cornerRadius radius: CGFloat? = nil,
        paddingFraction: CGFloat = 0.1,
        color: NSColor = .white
    ) -> NSImage? {
        let imgSize = self.size
        let cornerRadius = radius ?? imgSize.width / 5
        
        let whiteBgImage = NSImage(size: imgSize)
        whiteBgImage.lockFocus()
        
        color.setFill()
        NSRect(origin: .zero, size: imgSize).fill()
        
        self.draw(at: .zero, from: NSRect(origin: .zero, size: imgSize), operation: .sourceOver, fraction: 1.0)
        
        whiteBgImage.unlockFocus()
        
        let finalImage = NSImage(size: imgSize)
        finalImage.lockFocus()
        
        let fullRect = NSRect(origin: .zero, size: imgSize)
        let padding = imgSize.width * paddingFraction
        let paddedRect = fullRect.insetBy(dx: padding, dy: padding)
        
        let clipPath = NSBezierPath(roundedRect: paddedRect, xRadius: cornerRadius, yRadius: cornerRadius)
        clipPath.addClip()
        
        whiteBgImage.draw(in: paddedRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        
        finalImage.unlockFocus()
        finalImage.isTemplate = self.isTemplate
        
        return finalImage
    }
}

import Cocoa

extension NSImage {
    func isMostlyWhiteOpaquePixels(threshold: CGFloat = 0.9, whiteRatioCutoff: CGFloat = 0.8) -> Bool {
        guard let tiffData = self.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return false
        }
        
        let width = bitmap.pixelsWide
        let height = bitmap.pixelsHigh
        
        var whitePixelCount = 0
        var opaquePixelCount = 0
        
        for x in 0..<width {
            for y in 0..<height {
                guard let color = bitmap.colorAt(x: x, y: y) else { continue }
                let alpha = color.alphaComponent
                
                if alpha > 0.1 {
                    opaquePixelCount += 1
                    
                    guard let rgbColor = color.usingColorSpace(.deviceRGB) else { continue }
                    
                    let r = rgbColor.redComponent
                    let g = rgbColor.greenComponent
                    let b = rgbColor.blueComponent
                    
                    if r >= threshold && g >= threshold && b >= threshold {
                        whitePixelCount += 1
                    }
                }
            }
        }
        
        guard opaquePixelCount > 0 else { return false }
        
        let whiteRatio = CGFloat(whitePixelCount) / CGFloat(opaquePixelCount)
        return whiteRatio >= whiteRatioCutoff
    }
}

// Search: Attributed Strings

extension NSAttributedString {
    func withSystemFont() -> AttributedString {
        let mutable = NSMutableAttributedString(attributedString: self)

        mutable.enumerateAttribute(.font, in: NSRange(location: 0, length: mutable.length)) { value, range, _ in
            if let font = value as? NSFont {
                let weight: NSFont.Weight = font.fontDescriptor.symbolicTraits.contains(.bold) ? .bold : .regular

                let newFont = NSFont.systemFont(ofSize: font.pointSize, weight: weight)
                mutable.addAttribute(.font, value: newFont, range: range)
            }
        }

        return AttributedString(mutable)
    }
}

extension NSAttributedString {
    func toAttributedString() -> AttributedString? {
        return AttributedString(self)
    }
}

// Search: Strings
extension String {
    func removing(_ string: String) -> String {
        return self.replacingOccurrences(of: string, with: "")
    }
}
// Search: Bundles

extension Bundle {
    var applicationName: String? {
        object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
            object(forInfoDictionaryKey: "CFBundleName") as? String
    }
}
// Search: NSWindows

extension NSWindow {
    func forceBecomeKeyWindow() {
        // Get the original getter for canBecomeKey
        let originalSelector = #selector(getter: NSWindow.canBecomeKey)
        let swizzledSelector = #selector(NSWindow.swizzled_canBecomeKey)

        guard let originalMethod = class_getInstanceMethod(NSWindow.self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(NSWindow.self, swizzledSelector) else {
            print("Failed to swizzle canBecomeKey")
            return
        }

        // Swap implementations
        method_exchangeImplementations(originalMethod, swizzledMethod)

        // Make this window the key window
        self.makeKey()

        // Swap back to restore original behavior
        method_exchangeImplementations(swizzledMethod, originalMethod)
    }

    // New implementation for canBecomeKey
    @objc func swizzled_canBecomeKey() -> Bool {
        return true
    }
}


// JumpToBottom
