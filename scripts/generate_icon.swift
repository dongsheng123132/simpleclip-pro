#!/usr/bin/env swift
import Cocoa

// Configuration
let sizes: [(String, Int, Int)] = [
    ("icon_16x16.png", 16, 1),
    ("icon_16x16@2x.png", 16, 2),
    ("icon_32x32.png", 32, 1),
    ("icon_32x32@2x.png", 32, 2),
    ("icon_128x128.png", 128, 1),
    ("icon_128x128@2x.png", 128, 2),
    ("icon_256x256.png", 256, 1),
    ("icon_256x256@2x.png", 256, 2),
    ("icon_512x512.png", 512, 1),
    ("icon_512x512@2x.png", 512, 2)
]

// Adjust path to be relative to where the script is run (project root)
let baseDir = FileManager.default.currentDirectoryPath + "/SimpleClip/Assets.xcassets/AppIcon.appiconset"

// Helper to draw the icon
func drawIcon(size: Double) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()
    
    let ctx = NSGraphicsContext.current!.cgContext
    
    // 1. Background (White Squircle)
    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let bgPath = CGPath(roundedRect: rect, cornerWidth: size * 0.22, cornerHeight: size * 0.22, transform: nil)
    
    ctx.addPath(bgPath)
    ctx.clip()
    
    // Background Gradient (Subtle White/Grey)
    let colors = [
        NSColor(white: 1.0, alpha: 1.0).cgColor,
        NSColor(white: 0.92, alpha: 1.0).cgColor
    ] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.0, 1.0])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size), end: CGPoint(x: 0, y: 0), options: [])
    
    // 2. Clipboard Shape
    let boardW = size * 0.55
    let boardH = size * 0.70
    let boardX = (size - boardW) / 2
    let boardY = (size - boardH) / 2
    
    let boardRect = CGRect(x: boardX, y: boardY, width: boardW, height: boardH)
    let boardPath = CGPath(roundedRect: boardRect, cornerWidth: boardW * 0.1, cornerHeight: boardW * 0.1, transform: nil)
    
    ctx.addPath(boardPath)
    ctx.setFillColor(NSColor(white: 0.25, alpha: 1.0).cgColor) // Dark Grey
    ctx.fillPath()
    
    // 3. Paper
    let paperW = boardW * 0.85
    let paperH = boardH * 0.85
    let paperX = boardX + (boardW - paperW) / 2
    let paperY = boardY + (boardH - paperH) * 0.15 // Offset from top
    
    let paperRect = CGRect(x: paperX, y: paperY, width: paperW, height: paperH)
    let paperPath = CGPath(roundedRect: paperRect, cornerWidth: paperW * 0.05, cornerHeight: paperW * 0.05, transform: nil)
    
    ctx.addPath(paperPath)
    ctx.setFillColor(NSColor(white: 0.95, alpha: 1.0).cgColor)
    ctx.fillPath()
    
    // 4. Lines on Paper
    ctx.setFillColor(NSColor(white: 0.8, alpha: 1.0).cgColor)
    let lineH = paperH * 0.06
    let lineGap = paperH * 0.14
    let lineMargin = paperW * 0.15
    
    // Wait, let's just use simple rectangles relative to paperRect
    for i in 0..<3 {
        let ly = paperY + paperH * 0.6 - (Double(i) * lineGap)
        let lineRect = CGRect(x: paperX + lineMargin, y: ly, width: paperW - 2 * lineMargin, height: lineH)
        ctx.fill(lineRect)
    }
    
    // 5. Clip (Metal part at top)
    let clipW = boardW * 0.6
    let clipH = boardH * 0.18
    let clipX = (size - clipW) / 2
    let clipY = boardY + boardH - (clipH * 0.6)
    
    let clipRect = CGRect(x: clipX, y: clipY, width: clipW, height: clipH)
    let clipPath = CGPath(roundedRect: clipRect, cornerWidth: clipH * 0.3, cornerHeight: clipH * 0.3, transform: nil)
    
    ctx.addPath(clipPath)
    ctx.setFillColor(NSColor(white: 0.6, alpha: 1.0).cgColor) // Metal
    ctx.fillPath()
    
    // Clip hole
    ctx.setFillColor(NSColor(white: 0.25, alpha: 1.0).cgColor) // Dark Grey (Hole)
    let holeSize = clipH * 0.4
    let holeX = (size - holeSize) / 2
    let holeY = clipY + (clipH - holeSize) / 2
    ctx.fillEllipse(in: CGRect(x: holeX, y: holeY, width: holeSize, height: holeSize))
    
    img.unlockFocus()
    return img
}

// Ensure directory exists
let fileManager = FileManager.default
var isDir: ObjCBool = false
if !fileManager.fileExists(atPath: baseDir, isDirectory: &isDir) {
    try? fileManager.createDirectory(atPath: baseDir, withIntermediateDirectories: true, attributes: nil)
}

// Generate Images
for (filename, pointSize, scale) in sizes {
    let targetSize = Double(pointSize * scale)
    let img = drawIcon(size: targetSize)
    
    if let tiffData = img.tiffRepresentation,
       let bitmap = NSBitmapImageRep(data: tiffData),
       let pngData = bitmap.representation(using: .png, properties: [:]) {
        let url = URL(fileURLWithPath: baseDir).appendingPathComponent(filename)
        try? pngData.write(to: url)
        print("Generated: \(filename)")
    }
}

// Update Contents.json
let jsonContent = """
{
  "images" : [
    { "size" : "16x16", "idiom" : "mac", "filename" : "icon_16x16.png", "scale" : "1x" },
    { "size" : "16x16", "idiom" : "mac", "filename" : "icon_16x16@2x.png", "scale" : "2x" },
    { "size" : "32x32", "idiom" : "mac", "filename" : "icon_32x32.png", "scale" : "1x" },
    { "size" : "32x32", "idiom" : "mac", "filename" : "icon_32x32@2x.png", "scale" : "2x" },
    { "size" : "128x128", "idiom" : "mac", "filename" : "icon_128x128.png", "scale" : "1x" },
    { "size" : "128x128", "idiom" : "mac", "filename" : "icon_128x128@2x.png", "scale" : "2x" },
    { "size" : "256x256", "idiom" : "mac", "filename" : "icon_256x256.png", "scale" : "1x" },
    { "size" : "256x256", "idiom" : "mac", "filename" : "icon_256x256@2x.png", "scale" : "2x" },
    { "size" : "512x512", "idiom" : "mac", "filename" : "icon_512x512.png", "scale" : "1x" },
    { "size" : "512x512", "idiom" : "mac", "filename" : "icon_512x512@2x.png", "scale" : "2x" }
  ],
  "info" : {
    "version" : 1,
    "author" : "xcode"
  }
}
"""

let jsonUrl = URL(fileURLWithPath: baseDir).appendingPathComponent("Contents.json")
try? jsonContent.write(to: jsonUrl, atomically: true, encoding: .utf8)
print("Updated Contents.json")
