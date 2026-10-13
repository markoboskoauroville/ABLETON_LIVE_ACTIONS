// The icon, drawn: Live's world as a hand-fitted control: four vertical faders and a knob above them, one fader
// amber; the version under it.
import AppKit
let S: CGFloat = 1024
let version = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "1"
let img = NSImage(size: NSSize(width: S, height: S)); img.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext
ctx.addPath(CGPath(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824), cornerWidth: 180, cornerHeight: 180, transform: nil))
ctx.setFillColor(NSColor(calibratedRed: 0.04, green: 0.05, blue: 0.06, alpha: 1).cgColor); ctx.fillPath()
let amber = NSColor(calibratedRed: 0.91, green: 0.64, blue: 0.24, alpha: 1)
let caps: [CGFloat] = [0.7, 0.35, 0.55, 0.8]
for (i, c) in caps.enumerated() {
    let x = 250 + CGFloat(i) * 150
    ctx.setFillColor(NSColor(calibratedWhite: 0.28, alpha: 1).cgColor); ctx.fill(CGRect(x: x - 6, y: 300, width: 12, height: 420))
    let y = 300 + c * 420 - 40
    ctx.addPath(CGPath(roundedRect: CGRect(x: x - 46, y: y, width: 92, height: 80), cornerWidth: 12, cornerHeight: 12, transform: nil))
    ctx.setFillColor((i == 2 ? amber : NSColor(calibratedWhite: 0.85, alpha: 1)).cgColor); ctx.fillPath()
}
ctx.setStrokeColor(NSColor(calibratedWhite: 0.85, alpha: 1).cgColor); ctx.setLineWidth(18)
ctx.strokeEllipse(in: CGRect(x: 690, y: 760, width: 110, height: 110))
ctx.move(to: CGPoint(x: 745, y: 815)); ctx.addLine(to: CGPoint(x: 780, y: 855)); ctx.strokePath()
("v" + version as NSString).draw(at: NSPoint(x: 170, y: 150), withAttributes: [.font: NSFont.systemFont(ofSize: 92, weight: .semibold), .foregroundColor: NSColor(calibratedWhite: 0.78, alpha: 1)])
img.unlockFocus()
try! NSBitmapImageRep(data: img.tiffRepresentation!)!.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "icon_1024.png"))
