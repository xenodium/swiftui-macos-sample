import Cocoa
import SwiftUI

struct ClockView: View {
  static let mouseDidEnterNotification = Notification.Name("ClockMouseDidEnterNotification")
  static let mouseDidExitNotification = Notification.Name("ClockMouseDidExitNotification")

  @State
  private var time = "--:--"

  @State
  private var closeEnabled = false

  // Variable tap count, because when the window is not focused, we need 3 taps (to achieve 2) ¯\_(ツ)_/¯
  @State
  private var tapCount = 2

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
              let formatter = DateFormatter()
              formatter.dateFormat = "HH:mm"
              self.time = formatter.string(from: input)
            }
            .font(
              Font.system(
                size: (pow(geometry.size.width, 2)
                  + pow(geometry.size.height, 2)).squareRoot() / 4
              ).bold()
            )
            .padding()
        }.frame(width: geometry.size.width, height: self.hidden ? 0 : geometry.size.height)
          .background(Color.black)
          .cornerRadius(10)
          .frame(maxWidth: .infinity, maxHeight: .infinity)

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
            hidden = true
            hideTimer?.invalidate()
            hideTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: false) { _ in
              self.hidden = false
            }
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

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.delegate = self
    window.contentView = hostingView
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
