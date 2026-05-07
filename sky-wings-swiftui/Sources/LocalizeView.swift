import SwiftUI

struct LocalizeView: View {
    @State private var logs: [String] = []
    @State private var isExecuting = false
    @State private var installStatus: Int = 0 // 0: 检查中, 1: 已汉化, 2: 官方原版, 3: 未安装
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Text("Desktop 汉化")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    
                    // 状态标识
                    Group {
                        if installStatus == 0 {
                            Label("检查状态中...", systemImage: "arrow.triangle.2.circlepath")
                                .foregroundColor(.gray)
                        } else if installStatus == 1 {
                            Label("已汉化", systemImage: "checkmark.seal.fill")
                                .foregroundColor(.green)
                        } else if installStatus == 2 {
                            Label("官方原版", systemImage: "shield.righthalf.filled")
                                .foregroundColor(.blue)
                        } else {
                            Label("未找到 Claude", systemImage: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                        }
                    }
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(statusColor.opacity(0.1))
                    .clipShape(Capsule())
                    .animation(.spring(), value: installStatus)
                }
                
                Text("在原生英文与中文体验间无缝切换。\n(注：受限于官方架构，当前补丁仅覆盖核心 UI 词条，部分动态业务组件可能仍保持英文)")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineSpacing(4)
            }
            
            HStack(spacing: 16) {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 24))
                VStack(alignment: .leading, spacing: 4) {
                    Text("安全与分发提示")
                        .font(.system(size: 15, weight: .semibold))
                    Text("汉化重签需要管理员权限。若未来本程序分享给他人被 macOS 提示“文件已损坏”，请让对方在终端执行：\n`sudo xattr -cr \"/Applications/Sky Wings.app\"` 即可绕过门禁强行打开。")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .premiumCard()
            
            HStack(spacing: 16) {
                Button(action: { executeAction(mode: "zh") }) {
                    Label("一键注入汉化补丁", systemImage: "globe")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isExecuting)
                
                Button(action: { executeAction(mode: "en") }) {
                    Label("恢复官方原版", systemImage: "wrench.and.screwdriver")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(isExecuting || installStatus == 2)
            }
            
            VStack(spacing: 0) {
                HStack {
                    Text("Terminal Output")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(white: 0.15))
                
                ScrollView {
                    ScrollViewReader { proxy in
                        VStack(alignment: .leading, spacing: 4) {
                            if logs.isEmpty {
                                Text("等待执行指令...")
                                    .foregroundColor(.gray)
                            } else {
                                ForEach(Array(logs.enumerated()), id: \.offset) { index, log in
                                    Text(log)
                                        .id(index)
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onChange(of: logs.count) { _ in
                            if !logs.isEmpty {
                                proxy.scrollTo(logs.count - 1, anchor: .bottom)
                            }
                        }
                    }
                }
                .background(Color.black.opacity(0.85))
                .foregroundColor(Color(red: 0, green: 1, blue: 0.25))
                .font(.system(size: 12, design: .monospaced))
            }
            .frame(height: 240)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.05), lineWidth: 1))
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isExecuting)
        .onAppear {
            checkStatus()
        }
    }
    
    private var statusColor: Color {
        switch installStatus {
        case 0: return .gray
        case 1: return .green
        case 2: return .blue
        default: return .red
        }
    }
    
    func checkStatus() {
        let fm = FileManager.default
        let appPaths = ["/Applications/Claude.app", (NSHomeDirectory() as NSString).appendingPathComponent("Applications/Claude.app")]
        var targetJsonPath = ""
        for path in appPaths {
            if fm.fileExists(atPath: path) {
                targetJsonPath = "\(path)/Contents/Resources/ion-dist/i18n/en-US.json"
                break
            }
        }
        
        if targetJsonPath.isEmpty || !fm.fileExists(atPath: targetJsonPath) {
            installStatus = 3
            return
        }
        
        let bakJsonPath = "\(targetJsonPath).bak"
        if fm.fileExists(atPath: bakJsonPath) {
            do {
                let targetSize = try fm.attributesOfItem(atPath: targetJsonPath)[.size] as? NSNumber ?? 0
                let bakSize = try fm.attributesOfItem(atPath: bakJsonPath)[.size] as? NSNumber ?? 0
                
                if targetSize == bakSize {
                    installStatus = 2
                } else {
                    installStatus = 1
                }
            } catch {
                installStatus = 1
            }
        } else {
            installStatus = 2
        }
    }
    
    func executeAction(mode: String) {
        isExecuting = true
        let isZh = (mode == "zh")
        logs.append(">>> 正在初始化 \(isZh ? "中文汉化" : "英文恢复") 序列...")
        
        guard let resourcePath = Bundle.main.resourcePath else {
            logs.append(">>> 错误：无法定位资源文件夹。")
            isExecuting = false
            return
        }
        
        let sourcePath = "\(resourcePath)/ion-dist-en-US-fully-translated.json"
        
        // 构造 Shell 脚本指令
        // 1. 动态寻址
        let findAppCommand = """
        CLAUDE_PATH="/Applications/Claude.app"
        if [ ! -d "$CLAUDE_PATH" ]; then
            CLAUDE_PATH="$HOME/Applications/Claude.app"
        fi
        if [ ! -d "$CLAUDE_PATH" ]; then
            echo "Error: 未能在常规目录找到 Claude.app"
            exit 1
        fi
        TARGET_JSON="$CLAUDE_PATH/Contents/Resources/ion-dist/i18n/en-US.json"
        BAK_JSON="${TARGET_JSON}.bak"
        """

        var actionScript = ""
        if isZh {
            actionScript = """
            export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
            echo "正在关闭可能运行的 Claude 进程..."
            killall "Claude" 2>/dev/null || true
            sleep 1
            
            if [ ! -f "$BAK_JSON" ]; then
                echo "创建首次原版备份..."
                cp "$TARGET_JSON" "$BAK_JSON"
            fi
            
            echo "正在注入增强版本地化语言包 (包含 1.3万+ 翻译条目)..."
            cp -f "\(sourcePath)" "$TARGET_JSON"
            chmod 644 "$TARGET_JSON"
            
            echo "正在进行系统安全标记净化..."
            xattr -cr "$CLAUDE_PATH" 2>/dev/null || true
            
            echo "全系统级汉化补丁注入成功！"
            """
        } else {
            actionScript = """
            export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
            echo "正在关闭可能运行的 Claude 进程..."
            killall "Claude" 2>/dev/null || true
            sleep 1
            
            # 恢复语言包
            if [ -f "$BAK_JSON" ]; then
                echo "正在恢复原版语言资源..."
                cp -f "$BAK_JSON" "$TARGET_JSON"
            fi
            
            echo "正在重置安全权限..."
            xattr -cr "$CLAUDE_PATH" 2>/dev/null || true
            
            echo "官方原版环境已完全恢复！"
            """
        }

        let resignScript = """
        echo "清理旧的隔离属性..."
        xattr -cr "$CLAUDE_PATH" 2>/dev/null || true
        
        echo "开始进行轻量级重签 (保留官方权限)..."
        codesign -f -s - --preserve-metadata=entitlements "$CLAUDE_PATH"
        echo "安全重签完成！"
        
        echo "正在自动唤醒 Claude Desktop..."
        open "$CLAUDE_PATH"
        """
        
        let command = findAppCommand + "\n" + actionScript + "\n" + resignScript
        
        let tempScriptURL = FileManager.default.temporaryDirectory.appendingPathComponent("claude_patch.sh")
        do {
            try command.write(to: tempScriptURL, atomically: true, encoding: .utf8)
        } catch {
            logs.append(">>> 错误：无法创建执行脚本。")
            isExecuting = false
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            var errorInfo: NSDictionary? = nil
            let appleScriptSource = "do shell script \"bash \\\"\(tempScriptURL.path)\\\"\" with administrator privileges"
            
            if let appleScript = NSAppleScript(source: appleScriptSource) {
                let result = appleScript.executeAndReturnError(&errorInfo)
                
                // 清理临时脚本
                try? FileManager.default.removeItem(at: tempScriptURL)
                
                // 成功后，以当前用户身份自动删除钥匙串中的旧锁，防止死循环弹窗
                if errorInfo == nil {
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
                    process.arguments = ["delete-generic-password", "-s", "Claude Safe Storage", "-a", "Claude Key"]
                    try? process.run()
                    process.waitUntilExit()
                }
                
                DispatchQueue.main.async {
                    if let error = errorInfo {
                        self.logs.append(">>> 执行出错: \(error)")
                        self.logs.append(">>> 请确保您授予了管理员权限。")
                    } else {
                        let output = result.stringValue ?? "执行成功"
                        let outputLines = output.components(separatedBy: "\r")
                        for line in outputLines {
                            self.logs.append(">>> \(line)")
                        }
                        self.logs.append(">>> 🔐 自动清除了旧版安全钥匙串，彻底解决权限弹窗问题。")
                        self.logs.append(">>> 任务完成！请在重新弹出的 Claude 中重新登录。")
                        self.checkStatus()
                    }
                    self.isExecuting = false
                }
            } else {
                DispatchQueue.main.async {
                    self.logs.append(">>> 无法初始化权限提升脚本。")
                    self.isExecuting = false
                }
            }
        }
    }
}
