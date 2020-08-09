import Cocoa
import SwiftUI

struct ClockView: View {
  @State
  private var time = "--:--"

  @State
  private var closeEnabled = false

  @State
  private var hidden = false

  @State
  private var hideTimer: Timer?

  private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        if !hidden {
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
          }.frame(width: geometry.size.width, height: geometry.size.height)
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
                    .frame(width: 17, height: 17)
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
      }
      .onTapGesture(count: 2) {
        hidden = true
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: false) { _ in
          self.hidden = false
        }
      }
      .onHover {
        self.closeEnabled = $0
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

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
  let window: NSWindow = .makeWindow()
  var hostingView: NSView = NSHostingView(rootView: ClockView())

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
