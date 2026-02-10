import SwiftUI

struct SceneSelectionView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager
    @State private var selectedTheme: SceneTheme = .commandCenter
    @State private var hoveredTheme: SceneTheme?
    @State private var appeared = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#0A0A1A"),
                    Color(hex: "#1A1A3E"),
                    Color(hex: "#0A0A1A")
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Title
                VStack(spacing: 8) {
                    Text(localization.localized(.agentCommand))
                        .font(.system(size: 36, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .shadow(color: Color(hex: "#00BCD4").opacity(0.5), radius: 10)

                    Text(localization.localized(.selectYourEnvironment))
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : -20)

                // Theme cards
                HStack(spacing: 24) {
                    ForEach(SceneTheme.allCases) { theme in
                        ThemeCard(
                            theme: theme,
                            isSelected: selectedTheme == theme,
                            isHovered: hoveredTheme == theme
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedTheme = theme
                            }
                        }
                        .onHover { hovering in
                            withAnimation(.easeInOut(duration: 0.15)) {
                                hoveredTheme = hovering ? theme : nil
                            }
                        }
                    }
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 30)

                // Enter button
                Button(action: {
                    appState.setTheme(selectedTheme)
                    appState.loadSampleConfig()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 18))
                        Text(localization.localized(.enter))
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(themeAccentColor)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(themeAccentColor.opacity(0.6), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .shadow(color: themeAccentColor.opacity(0.4), radius: 8)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)

                Spacer()

                // Footer
                Text(localization.localized(.themeCanBeChangedLater))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.5))
                    .padding(.bottom, 20)
                    .opacity(appeared ? 1 : 0)
            }
            .padding(.horizontal, 40)
        }
        .onAppear {
            selectedTheme = appState.currentTheme
            withAnimation(.easeOut(duration: 0.8)) {
                appeared = true
            }
        }
    }

    private var themeAccentColor: Color {
        Color(hex: ThemeColorPalette.palette(for: selectedTheme).accentColor)
    }
}

// MARK: - Theme Card

struct ThemeCard: View {
    let theme: SceneTheme
    let isSelected: Bool
    let isHovered: Bool
    @EnvironmentObject var localization: LocalizationManager

    private var palette: ThemeColorPalette {
        ThemeColorPalette.palette(for: theme)
    }

    var body: some View {
        VStack(spacing: 12) {
            // Gradient preview area
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(hex: theme.previewGradientColors.0),
                                Color(hex: theme.previewGradientColors.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 120)

                // Icon
                Image(systemName: theme.iconSystemName)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 4)
            }

            // Title
            Text(theme.localizedName(localization))
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.white)

            // Description
            Text(theme.localizedDescription(localization))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .frame(height: 40)
        }
        .padding(12)
        .frame(width: 200)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "#1A1A2E").opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isSelected
                        ? Color(hex: palette.accentColor)
                        : Color.white.opacity(isHovered ? 0.3 : 0.1),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .shadow(
            color: isSelected
                ? Color(hex: palette.accentColor).opacity(0.3)
                : .clear,
            radius: 12
        )
        .scaleEffect(isSelected ? 1.05 : (isHovered ? 1.02 : 1.0))
    }
}
