// Draws the 1024px app icon: a chrome genie lamp (Magic Flow). With "settings": the mouse with edge sliders.
// Run: swift make_icon.swift icon_1024.png
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let S: CGFloat = 1024
let cs = CGColorSpace(name: CGColorSpace.displayP3)!
let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
                    space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [r / 255, g / 255, b / 255, a])!
}
func linear(_ colors: [CGColor], from: CGPoint, to: CGPoint) {
    let g = CGGradient(colorsSpace: cs, colors: colors as CFArray, locations: nil)!
    ctx.drawLinearGradient(g, start: from, end: to, options: [])
}

// Background: Apple's 824pt rounded square on a 1024 canvas, deep blue to violet.
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: rgb(0, 0, 0, 0.35))
ctx.addPath(tilePath); ctx.setFillColor(rgb(30, 34, 80)); ctx.fillPath()
ctx.restoreGState()
ctx.saveGState()
ctx.addPath(tilePath); ctx.clip()
linear([rgb(62, 76, 190), rgb(36, 30, 92)], from: CGPoint(x: 512, y: 924), to: CGPoint(x: 512, y: 100))
ctx.restoreGState()

// Settings variant (second argument "settings"): edge sliders instead of a letter. Two lit edges with a knob each,
// two dim, matching the Edges tab drawing in Jitouch Settings.
func bar(_ r: CGRect, lit: Bool) {
    let path = CGPath(roundedRect: r, cornerWidth: min(r.width, r.height) / 2, cornerHeight: min(r.width, r.height) / 2, transform: nil)
    ctx.saveGState()
    ctx.addPath(path); ctx.clip()
    if lit { linear([rgb(255, 160, 60), rgb(240, 80, 40)], from: CGPoint(x: r.minX, y: r.maxY), to: CGPoint(x: r.maxX, y: r.minY)) }
    else { ctx.setFillColor(rgb(196, 201, 218)); ctx.fill(r) }
    ctx.restoreGState()
}
func knob(_ c: CGPoint) {
    ctx.setFillColor(rgb(255, 120, 50, 0.28)); ctx.fillEllipse(in: CGRect(x: c.x - 44, y: c.y - 44, width: 88, height: 88))
    ctx.setFillColor(rgb(255, 255, 255)); ctx.fillEllipse(in: CGRect(x: c.x - 27, y: c.y - 27, width: 54, height: 54))
    ctx.setFillColor(rgb(240, 80, 40)); ctx.fillEllipse(in: CGRect(x: c.x - 15, y: c.y - 15, width: 30, height: 30))
}
if CommandLine.arguments.count > 2 && CommandLine.arguments[2] == "settings" {
    // Magic Mouse body: a tall pill with a soft shadow and a light top-to-bottom sheen.
    let mouse = CGRect(x: 337, y: 205, width: 350, height: 590)
    let mousePath = CGPath(roundedRect: mouse, cornerWidth: 175, cornerHeight: 175, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 40, color: rgb(0, 0, 20, 0.5))
    ctx.addPath(mousePath); ctx.setFillColor(rgb(245, 246, 250)); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(mousePath); ctx.clip()
    linear([rgb(255, 255, 255), rgb(214, 218, 230)], from: CGPoint(x: 512, y: 795), to: CGPoint(x: 512, y: 205))
    ctx.restoreGState()

    bar(CGRect(x: 417, y: 712, width: 190, height: 34), lit: true)   // front
    bar(CGRect(x: 437, y: 252, width: 150, height: 28), lit: false)  // back
    bar(CGRect(x: 364, y: 470, width: 34, height: 190), lit: true)   // left, toward the front
    bar(CGRect(x: 626, y: 470, width: 34, height: 190), lit: false)  // right
    knob(CGPoint(x: 566, y: 729))
    knob(CGPoint(x: 381, y: 610))
} else {
    // Magic Flow: the genie lamp from the menu bar icon (lampIcon in JitouchAppDelegate.m, the same outline in a
    // 22 x 16 box), scaled up and finished in mirror-polished chrome like the drawing ink, with a wisp of smoke.
    ctx.saveGState()
    ctx.translateBy(x: 160, y: 250)
    ctx.scaleBy(x: 32, y: 32)
    let body = CGMutablePath()
    body.move(to: CGPoint(x: 4, y: 8)) // bowl, out along the spout to its tip, back along the rim
    body.addCurve(to: CGPoint(x: 10, y: 3), control1: CGPoint(x: 4, y: 5), control2: CGPoint(x: 6.5, y: 3))
    body.addCurve(to: CGPoint(x: 15, y: 5.5), control1: CGPoint(x: 12.5, y: 3), control2: CGPoint(x: 14, y: 4))
    body.addLine(to: CGPoint(x: 21, y: 9.6)); body.addLine(to: CGPoint(x: 21, y: 10.4)); body.addLine(to: CGPoint(x: 15.5, y: 8))
    body.closeSubpath()
    body.addRect(CGRect(x: 9, y: 2, width: 2, height: 1.5))                                         // stem
    body.addRoundedRect(in: CGRect(x: 7.5, y: 0.8, width: 5, height: 1.6), cornerWidth: 0.8, cornerHeight: 0.8) // foot
    body.addEllipse(in: CGRect(x: 7, y: 7.6, width: 6, height: 3))                                  // lid
    body.addEllipse(in: CGRect(x: 9.1, y: 10.3, width: 1.8, height: 1.8))                           // knob
    let handle = CGPath(ellipseIn: CGRect(x: 1, y: 5.1, width: 4.2, height: 4.2), transform: nil)
        .copy(strokingWithWidth: 1.2, lineCap: .round, lineJoin: .round, miterLimit: 4)
    let lamp = CGMutablePath(); lamp.addPath(body); lamp.addPath(handle)

    ctx.saveGState() // shadow and blackened edge
    ctx.setShadow(offset: CGSize(width: 0, height: -0.6), blur: 1.4, color: rgb(0, 0, 20, 0.55))
    ctx.addPath(lamp); ctx.setLineWidth(0.5); ctx.setLineJoin(.round); ctx.setStrokeColor(rgb(20, 20, 26)); ctx.strokePath()
    ctx.restoreGState()
    // Mirror chrome: bright sky, dark horizon band, light floor. Handle first, then the body over it, each on its own:
    // filled together their overlap cancels out and the handle's edge shows through the bowl.
    let chrome = CGGradient(colorsSpace: cs, colors: [rgb(255, 255, 255), rgb(222, 226, 236), rgb(120, 124, 140),
                                                        rgb(52, 54, 66), rgb(190, 194, 206), rgb(250, 250, 255)] as CFArray,
                            locations: [0, 0.32, 0.48, 0.56, 0.78, 1])!
    for part in [handle, body as CGPath] {
        ctx.saveGState()
        ctx.addPath(part); ctx.clip(using: .winding)
        ctx.drawLinearGradient(chrome, start: CGPoint(x: 0, y: 12.4), end: CGPoint(x: 0, y: 0.8), options: [])
        ctx.restoreGState()
    }
    ctx.saveGState() // highlight along the top of the bowl
    ctx.setStrokeColor(rgb(255, 255, 255, 0.85)); ctx.setLineWidth(0.28); ctx.setLineCap(.round)
    ctx.move(to: CGPoint(x: 6.2, y: 7.3)); ctx.addCurve(to: CGPoint(x: 13.5, y: 7.1), control1: CGPoint(x: 8.5, y: 7.6), control2: CGPoint(x: 11.5, y: 7.6))
    ctx.strokePath()
    ctx.restoreGState()

    ctx.saveGState() // the wisp of smoke, glowing
    let wisp = CGMutablePath()
    wisp.move(to: CGPoint(x: 21, y: 11.2))
    wisp.addCurve(to: CGPoint(x: 18.6, y: 16.6), control1: CGPoint(x: 23.2, y: 13.2), control2: CGPoint(x: 17.4, y: 14.2))
    wisp.addCurve(to: CGPoint(x: 20.6, y: 19.2), control1: CGPoint(x: 19.4, y: 18.2), control2: CGPoint(x: 21.2, y: 17.8))
    ctx.setShadow(offset: .zero, blur: 1.2, color: rgb(200, 190, 255, 0.9))
    ctx.addPath(wisp); ctx.setLineWidth(0.9); ctx.setLineCap(.round); ctx.setStrokeColor(rgb(240, 238, 255, 0.95)); ctx.strokePath()
    ctx.restoreGState()
    ctx.restoreGState()
}

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png")
let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
precondition(CGImageDestinationFinalize(dest), "PNG write failed")
