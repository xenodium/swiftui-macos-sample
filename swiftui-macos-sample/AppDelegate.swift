import Cocoa
import SwiftUI

struct ClockView: View {
  static let mouseDidEnterNotification = Notification.Name("ClockMouseDidEnterNotification")
  static let mouseDidExitNotification = Notification.Name("ClockMouseDidExitNotification")
  static let mirrorNotification = Notification.Name("ClockMirrorNotification")

  @State
  private var time = "--:--"

  @State
  private var date = "--- --"

  @State
  private var closeEnabled = false

  // Variable tap count, because when the window is not focused, we need 3 taps (to achieve 2) ¯\_(ツ)_/¯
  @State
  private var tapCount = 3

  // Can be used to hide, but not used. Trying out mirroring.
  @State
  private var hidden = false

  @State
  private var hideTimer: Timer?

  private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        VStack {
          Text(self.time)
            .onReceive(self.timer) { input in
              let timeFormatter = DateFormatter()
              timeFormatter.dateFormat = "HH:mm"
              self.time = timeFormatter.string(from: input)

              let dateFormatter = DateFormatter()
              dateFormatter.dateFormat = "MMM d"
              self.date = dateFormatter.string(from: input)
            }
            .font(
              Font.system(
                size: (pow(geometry.size.width, 2)
                  + pow(geometry.size.height, 2)).squareRoot() / 4
              ).bold()
            )
            .padding(0)
          Text(date)
            .foregroundColor(Color(hex: "#e796d2"))
            .font(
              Font.system(
                size: (pow(geometry.size.width, 2) + pow(geometry.size.height, 2)).squareRoot()
                  / 15
              )
            )
        }.frame(width: geometry.size.width, height: self.hidden ? 0 : geometry.size.height)
          .background(Color.black)
          .cornerRadius(10)

        if self.closeEnabled {
          VStack {
            HStack {
              Spacer()
              Button(action: {
                NSApplication.shared.terminate(nil)
              }) {
                Text("x")
                  .padding(.bottom, 3)
                  .frame(width: 17, height: self.hidden ? 0 : 17)
                  .background(Color.gray)
                  .foregroundColor(.primary)
                  .clipShape(Circle())
              }
              .buttonStyle(PlainButtonStyle())
            }.padding(.horizontal, 5)

            Spacer()
          }
          .padding(.vertical, 5)
        }
      }
      .gesture(
        TapGesture(count: self.tapCount)
          .onEnded { _ in
            NotificationCenter.default.post(name: ClockView.mirrorNotification, object: nil)
          }
      )
      // Mouse events are more effective than onHover (because hover doesn't trigger on macOS if window is not active).
      .onReceive(
        NotificationCenter.default.publisher(for: ClockView.mouseDidExitNotification)
      ) { _ in
        self.closeEnabled = false
      }
      .onReceive(
        NotificationCenter.default.publisher(for: ClockView.mouseDidEnterNotification)
      ) { _ in
        self.closeEnabled = true
      }
      .onReceive(
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
      ) { _ in
        // Need to delay it or else a single tap when window is not focused results in false positive.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
          self.tapCount = 2
        }
      }
      .onReceive(
        NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)
      ) { _ in
        self.tapCount = 3
      }
    }
  }
}

extension NSWindow {
  static func makeWindow() -> NSWindow {
    let window = NSWindow(
      contentRect: NSRect.makeDefault(),
      styleMask: [
        .closable,
        .miniaturizable,
        .resizable,
        .fullSizeContentView,
      ],
      backing: .buffered, defer: false)
    window.level = .floating
    window.setFrameAutosaveName("floating-window")
    window.collectionBehavior = [
      .canJoinAllSpaces,
      .stationary,
      .ignoresCycle,
      .fullScreenPrimary,
    ]
    window.makeKeyAndOrderFront(nil)
    window.isMovableByWindowBackground = true
    window.titleVisibility = .hidden
    window.backgroundColor = .clear
    return window
  }
}

class MouseTrackingHostingView: NSHostingView<ClockView> {
  required init(rootView: ClockView) {
    super.init(rootView: rootView)
    addTrackingArea(
      NSTrackingArea(
        rect: bounds,
        options: [
          .inVisibleRect,
          .mouseEnteredAndExited,
          .activeAlways,
        ],
        owner: self,
        userInfo: nil))
  }

  required init?(coder aDecoder: NSCoder) {
    assert(false)
    return nil
  }

  override func mouseEntered(with event: NSEvent) {
    NotificationCenter.default.post(name: ClockView.mouseDidEnterNotification, object: nil)
  }

  override func mouseExited(with event: NSEvent) {
    NotificationCenter.default.post(name: ClockView.mouseDidExitNotification, object: nil)
  }
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
  let window: NSWindow = .makeWindow()
  var hostingView: NSView = MouseTrackingHostingView(rootView: ClockView())
  var observer: Any?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.delegate = self
    window.contentView = hostingView

    observer = NotificationCenter.default.addObserver(
      forName: ClockView.mirrorNotification, object: nil, queue: nil
    ) { [weak self] _ in
      self?.window.mirror()

      // Restore location after 60 seconds.
      DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
        self?.window.mirror()
      }
    }
  }
}

extension NSWindow {
  func mirror() {
    guard let screenFrame = NSScreen.main?.frame else {
      return
    }

    var origin = frame.origin
    origin.y = (screenFrame.maxY - frame.origin.y) - frame.height
    setFrameOrigin(origin)
  }
}

extension NSRect {
  static func makeDefault() -> NSRect {
    let initialMargin = CGFloat(60)
    let fallback = NSRect(x: 0, y: 0, width: 100, height: 150)

    guard let screenFrame = NSScreen.main?.frame else {
      return fallback
    }

    return NSRect(
      x: screenFrame.maxX - fallback.width - initialMargin,
      y: screenFrame.maxY - fallback.height - initialMargin,
      width: fallback.width, height: fallback.height)
  }
}

extension Color {
  init(hex text: String) {
    var text: String = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    if text.hasPrefix("#") {
      text.removeFirst()
    }
    self.init(hex: UInt(text, radix: 16) ?? 0)
  }

  init(hex: UInt, alpha: Double = 1) {
    self.init(
      .sRGB,
      red: Double((hex >> 16) & 0xff) / 255,
      green: Double((hex >> 08) & 0xff) / 255,
      blue: Double((hex >> 00) & 0xff) / 255,
      opacity: alpha
    )
  }
}
