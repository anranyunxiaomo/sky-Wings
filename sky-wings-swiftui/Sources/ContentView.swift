import SwiftUI

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.7))
            .background(Material.thin)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 15, x: 0, y: 8)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.05), lineWidth: 1))
    }
}

extension View {
    func premiumCard() -> some View {
        self.modifier(CardModifier())
    }
}

struct ContentView: View {
    @State private var selectedTab: Tab = .localize
    @Namespace private var animation
    
    enum Tab: String, CaseIterable {
        case localize = "环境与汉化"
        case codex = "大模型网关"
        case about = "关于愿景"
        
        var icon: String {
            switch self {
            case .localize: return "globe"
            case .codex: return "cpu"
            case .about: return "sparkles"
            }
        }
    }
    
    var body: some View {
        ZStack {
            // 充满生命力的流光溢彩毛玻璃背景
            ZStack {
                Color(NSColor.windowBackgroundColor)
                
                // 柔和的清透蓝光
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 500, height: 500)
                    .blur(radius: 100)
                    .offset(x: -200, y: -200)
                
                // 柔和的优雅紫光
                Circle()
                    .fill(Color.purple.opacity(0.12))
                    .frame(width: 500, height: 500)
                    .blur(radius: 100)
                    .offset(x: 250, y: 200)
                
                // 覆盖极致轻薄的毛玻璃材质，让光影完美交融
                Rectangle()
                    .fill(.ultraThinMaterial)
            }
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部高级分段导航栏 (Top Tab Bar)
                HStack(spacing: 16) {
                    ForEach(Tab.allCases, id: \.self) { tab in
                        Button(action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                selectedTab = tab
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 16, weight: .semibold))
                                Text(tab.rawValue)
                                    .font(.system(size: 15, weight: .bold))
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .foregroundColor(selectedTab == tab ? .white : .primary)
                            .background(
                                ZStack {
                                    if selectedTab == tab {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.accentColor)
                                            .shadow(color: Color.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
                                            .matchedGeometryEffect(id: "TAB_BG", in: animation)
                                    } else {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.gray.opacity(0.08))
                                    }
                                }
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 24)
                .padding(.bottom, 16)
                
                // 主内容区域
                ScrollView {
                    VStack {
                        if selectedTab == .localize {
                            LocalizeView()
                        } else if selectedTab == .codex {
                            CodexView()
                        } else {
                            AboutView()
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
                    .frame(maxWidth: 800, alignment: .top)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedTab)
                }
            }
        }
        .frame(minWidth: 700, minHeight: 600)
    }
}
