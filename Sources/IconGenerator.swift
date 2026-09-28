import AppKit

let outputDirectory: URL
if CommandLine.arguments.count > 1 {
    outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
} else {
    fatalError("缺少图标输出目录")
}

try FileManager.default.createDirectory(
    at: outputDirectory,
    withIntermediateDirectories: true
)

let iconFiles: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

func makeIcon(size: Int) throws -> Data {
    let dimension = CGFloat(size)
    let image = NSImage(size: NSSize(width: dimension, height: dimension))
    image.lockFocus()

    NSGraphicsContext.current?.imageInterpolation = .high
    let inset = dimension * 0.045
    let rect = NSRect(x: inset, y: inset, width: dimension - inset * 2, height: dimension - inset * 2)
    let radius = dimension * 0.225
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.34, green: 0.20, blue: 0.92, alpha: 1),
        NSColor(calibratedRed: 0.14, green: 0.53, blue: 0.98, alpha: 1)
    ])!
    gradient.draw(in: path, angle: -35)

    let highlight = NSBezierPath(ovalIn: NSRect(
        x: dimension * 0.53,
        y: dimension * 0.54,
        width: dimension * 0.34,
        height: dimension * 0.34
    ))
    NSColor.white.withAlphaComponent(0.12).setFill()
    highlight.fill()

    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let font = NSFont(name: "PingFangSC-Semibold", size: dimension * 0.50)
        ?? NSFont.systemFont(ofSize: dimension * 0.50, weight: .semibold)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white,
        .paragraphStyle: paragraph
    ]
    let text = "中" as NSString
    let textRect = NSRect(
        x: dimension * 0.12,
        y: dimension * 0.20,
        width: dimension * 0.76,
        height: dimension * 0.62
    )
    text.draw(in: textRect, withAttributes: attributes)

    image.unlockFocus()

    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "IconGenerator", code: 1)
    }
    return png
}

for (name, size) in iconFiles {
    let data = try makeIcon(size: size)
    try data.write(to: outputDirectory.appendingPathComponent(name), options: .atomic)
}
