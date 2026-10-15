#if canImport(UIKit)
  import SwiftUI
  import UIKit

  enum CampusAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String {
      switch self {
      case .system: return "System"
      case .light: return "Hell"
      case .dark: return "Dunkel"
      }
    }
    var colorScheme: ColorScheme? {
      switch self {
      case .system: return nil
      case .light: return .light
      case .dark: return .dark
      }
    }
  }

  private func campusColor(_ light: UInt32, _ dark: UInt32) -> Color {
    Color(
      uiColor: UIColor { traits in
        let hex = traits.userInterfaceStyle == .dark ? dark : light
        return UIColor(
          red: CGFloat((hex >> 16) & 255) / 255,
          green: CGFloat((hex >> 8) & 255) / 255,
          blue: CGFloat(hex & 255) / 255, alpha: 1)
      })
  }

  let campusBlue = campusColor(0x1468F3, 0x82BBFF)
  let campusCanvas = campusColor(0xF7F9FC, 0x071426)
  let campusInk = campusColor(0x102A56, 0xEDF4FF)
  let campusSurface = campusColor(0xFFFFFF, 0x142A47)
  let campusMuted = campusColor(0x53657F, 0xAABDD7)
  let campusIce = campusColor(0xE5F3FF, 0x17395F)
  let campusMint = campusColor(0x126C68, 0xA6E5DD)
  let campusViolet = campusColor(0x594AB5, 0xC5BDFF)
  let campusRed = campusColor(0xB32235, 0xFF8894)

  struct CampusBackdrop: View {
    var body: some View {
      campusCanvas.overlay(alignment: .topTrailing) {
        RadialGradient(
          colors: [campusBlue.opacity(0.12), campusCanvas.opacity(0)],
          center: .topTrailing, startRadius: 10, endRadius: 400)
      }.ignoresSafeArea()
    }
  }

  private struct CampusSurface: ViewModifier {
    let radius: CGFloat
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func body(content: Content) -> some View {
      content
        .background {
          RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
              RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(campusSurface.opacity(reduceTransparency ? 1 : 0.82))
            }
        }
        .overlay {
          RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(campusBlue.opacity(0.10), lineWidth: 0.5)
        }
        .shadow(color: campusInk.opacity(0.06), radius: 14, x: 0, y: 6)
    }
  }

  extension View {
    func campusCard(radius: CGFloat = 22) -> some View {
      modifier(CampusSurface(radius: radius))
    }
  }
#endif
