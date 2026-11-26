import AppKit
let s: CGFloat = 1024
let img = NSImage(size: NSSize(width: s, height: s))
img.lockFocus()
let r = NSRect(x: 100, y: 100, width: 824, height: 824)
let bg = NSBezierPath(roundedRect: r, xRadius: 185, yRadius: 185)
NSGradient(starting: NSColor(white: 0.22, alpha: 1), ending: NSColor(white: 0.08, alpha: 1))!.draw(in: bg, angle: -90)
NSColor.white.setFill()
let d: CGFloat = 150, gap: CGFloat = 70
let total = d * 3 + gap * 2
for i in 0..<3 {
    let x = (s - total) / 2 + CGFloat(i) * (d + gap)
    let y = (s - d) / 2 + (i == 1 ? 40 : 0)
    NSBezierPath(ovalIn: NSRect(x: x, y: y, width: d, height: d)).fill()
}
img.unlockFocus()
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "icon-1024.png"))
