import SwiftUI

struct AboutView: View {
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                // 应用图标的占位/展示
                Image(systemName: "wind")
                    .font(.system(size: 64, weight: .thin))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(32)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.1), radius: 20, y: 10)
                
                VStack(spacing: 8) {
                    Text("云端之翼 (Sky Wings)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    Text("Version \(appVersion)")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            .padding(.top, 20)
            
            VStack(spacing: 24) {
                Text("“ 专注 · 极简 ”")
                    .font(.system(size: 24, weight: .light, design: .serif))
                    .italic()
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.primary, .primary.opacity(0.6)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("Sky Wings 致力于打破工具的冰冷感。\n我们以最纯粹的苹果原生美学，将复杂的底层协议与配置隐藏于无形。\n为您提供如丝般顺滑的大模型体验与无缝的本地化融合。")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .frame(maxWidth: 400)
            }
            .premiumCard()
            
            Spacer()
            
            Text("© 2026 Sky Wings Team. All rights reserved.")
                .font(.system(size: 12))
                .foregroundColor(.gray.opacity(0.6))
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}
