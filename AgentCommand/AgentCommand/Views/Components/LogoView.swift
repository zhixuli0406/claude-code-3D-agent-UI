import SwiftUI

// MARK: - Logo Size Variants

enum LogoSize {
    case favicon      // 16-64pt — sidebar headers, tiny icons
    case navbar       // 24-32pt — navigation bar, toolbar
    case medium       // 64-128pt — cards, panels
    case splash       // 128-256pt — scene selection, splash screen

    var imageSize: CGFloat {
        switch self {
        case .favicon: return 24
        case .navbar: return 28
        case .medium: return 80
        case .splash: return 160
        }
    }
}

// MARK: - Logo View (Icon Only)

struct LogoView: View {
    let size: LogoSize
    var showGlow: Bool = true

    var body: some View {
        Image("LogoIcon", bundle: .module)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: size.imageSize, height: size.imageSize)
            .shadow(
                color: showGlow ? Color(hex: "#00BCD4").opacity(glowOpacity) : .clear,
                radius: glowRadius
            )
    }

    private var glowOpacity: Double {
        switch size {
        case .favicon: return 0
        case .navbar: return 0.3
        case .medium: return 0.4
        case .splash: return 0.6
        }
    }

    private var glowRadius: CGFloat {
        switch size {
        case .favicon: return 0
        case .navbar: return 4
        case .medium: return 8
        case .splash: return 16
        }
    }
}

// MARK: - Logo with Title (Horizontal)

struct LogoWithTitle: View {
    let size: LogoSize
    @EnvironmentObject var localization: LocalizationManager

    var body: some View {
        HStack(spacing: spacing) {
            LogoView(size: size)

            VStack(alignment: .leading, spacing: 1) {
                Text(localization.localized(.agentCommandTitle))
                    .font(.system(size: titleFontSize, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)

                if size == .medium || size == .splash {
                    Text("3D AGENT UI")
                        .font(.system(size: subtitleFontSize, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(hex: "#7C4DFF").opacity(0.5))
                }
            }
        }
    }

    private var spacing: CGFloat {
        switch size {
        case .favicon: return 4
        case .navbar: return 8
        case .medium: return 12
        case .splash: return 16
        }
    }

    private var titleFontSize: CGFloat {
        switch size {
        case .favicon: return 10
        case .navbar: return 13
        case .medium: return 18
        case .splash: return 28
        }
    }

    private var subtitleFontSize: CGFloat {
        switch size {
        case .favicon, .navbar: return 7
        case .medium: return 9
        case .splash: return 11
        }
    }
}

// MARK: - Splash Logo (Vertical, for Scene Selection)

struct SplashLogoView: View {
    @EnvironmentObject var localization: LocalizationManager
    var animate: Bool = true
    @State private var glowPhase: Double = 0

    var body: some View {
        VStack(spacing: 16) {
            // Icon-only logo (LogoFull already contains brand text, so use LogoIcon
            // to avoid duplicating the title text rendered below)
            Image("LogoIcon", bundle: .module)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 180, height: 180)
                .shadow(
                    color: Color(hex: "#00BCD4").opacity(0.4 + glowPhase * 0.2),
                    radius: 20 + glowPhase * 8
                )

            // Title text
            VStack(spacing: 8) {
                Text(localization.localized(.agentCommand))
                    .font(.system(size: 36, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .shadow(color: Color(hex: "#00BCD4").opacity(0.5), radius: 10)

                Text(localization.localized(.selectYourEnvironment))
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundColor(.gray)
            }
        }
        .onAppear {
            if animate {
                withAnimation(
                    .easeInOut(duration: 2.0)
                    .repeatForever(autoreverses: true)
                ) {
                    glowPhase = 1.0
                }
            }
        }
    }
}

// MARK: - Sidebar Logo (Compact, for Side Panel Header)

struct SidebarLogoView: View {
    @EnvironmentObject var localization: LocalizationManager

    var body: some View {
        HStack(spacing: 8) {
            Image("LogoNavbar", bundle: .module)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 22, height: 22)
                .shadow(color: Color(hex: "#00BCD4").opacity(0.3), radius: 3)

            Text(localization.localized(.agentCommandTitle))
                .font(.headline)
                .foregroundColor(.white)

            Spacer()
        }
    }
}
