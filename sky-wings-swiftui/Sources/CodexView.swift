import SwiftUI
import Combine

class EngineManager: ObservableObject {
    @Published var isRunning = false
    @Published var logs: [String] = ["[系统] 就绪，等待指令。"]
    @Published var availableModels: [String] = ["meta/llama-3.1-70b-instruct", "meta/llama-3.1-405b-instruct"]
    @Published var isFetchingModels = false
    
    private var process: Process?
    private var outPipe: Pipe?
    
    init() {
        // 监听应用安全退出事件，主动销毁后台网关进程，防止产生僵尸进程锁死端口
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            self?.stopGateway()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        stopGateway()
    }
    
    func appendLog(_ text: String) {
        DispatchQueue.main.async {
            self.logs.append("[\(Date().formatted(date: .omitted, time: .standard))] \(text)")
        }
    }
    
    func fetchModels(apiKey: String) {
        guard !apiKey.isEmpty else {
            appendLog("获取模型失败：API Key 不能为空。")
            return
        }
        DispatchQueue.main.async { self.isFetchingModels = true }
        
        guard let url = URL(string: "https://integrate.api.nvidia.com/v1/models") else { return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async { self?.isFetchingModels = false }
            guard let data = data, error == nil else {
                self?.appendLog("获取模型列表失败: \(error?.localizedDescription ?? "网络错误")")
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let dataArray = json["data"] as? [[String: Any]] {
                    var models: [String] = []
                    for item in dataArray {
                        if let id = item["id"] as? String {
                            models.append(id)
                        }
                    }
                    if !models.isEmpty {
                        DispatchQueue.main.async {
                            self?.availableModels = models.sorted()
                            if self?.availableModels.contains(where: { $0.contains("llama-3.1") }) == false {
                                self?.availableModels.insert("meta/llama-3.1-70b-instruct", at: 0)
                            }
                            self?.appendLog("✅ 成功拉取 \(models.count) 个可用模型。")
                        }
                    }
                }
            } catch {
                self?.appendLog("解析模型列表失败。")
            }
        }.resume()
    }
    
    func startGateway(apiKey: String, port: String, fallbackModel: String) {
        if apiKey.isEmpty {
            appendLog("错误：必须填写英伟达 API Key。")
            return
        }
        
        // 启动前防呆：猎杀可能由于上次 App 异常崩溃残留的同名僵尸进程
        let cleanupTask = Process()
        cleanupTask.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        cleanupTask.arguments = ["codex-engine"]
        try? cleanupTask.run()
        cleanupTask.waitUntilExit()
        
        // 端口冲突检测：确保用户填写的动态端口没有被其他程序占用
        let portCheckTask = Process()
        portCheckTask.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        portCheckTask.arguments = ["-i", ":\(port)"]
        let portPipe = Pipe()
        portCheckTask.standardOutput = portPipe
        try? portCheckTask.run()
        portCheckTask.waitUntilExit()
        
        let portData = portPipe.fileHandleForReading.readDataToEndOfFile()
        if !portData.isEmpty {
            appendLog("⚠️ 启动中止：检测到端口 \(port) 正被系统或其他应用程序占用，请在配置中更换端口！")
            return
        }
        
        let enginePath = Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/codex-engine").path
        
        process = Process()
        process?.executableURL = URL(fileURLWithPath: enginePath)
        process?.arguments = ["-port", port, "-apikey", apiKey, "-fallback-model", fallbackModel]
        
        outPipe = Pipe()
        process?.standardOutput = outPipe
        process?.standardError = outPipe
        
        let outHandle = outPipe!.fileHandleForReading
        outHandle.readabilityHandler = { [weak self] pipe in
            let data = pipe.availableData
            if !data.isEmpty, let str = String(data: data, encoding: .utf8) {
                self?.appendLog(str.trimmingCharacters(in: .newlines))
            }
        }
        
        do {
            try process?.run()
            DispatchQueue.main.async { self.isRunning = true }
            appendLog("网关正在启动...")
        } catch {
            appendLog("启动失败: \(error.localizedDescription) (尝试路径: \(enginePath))")
        }
    }
    
    func stopGateway() {
        if process != nil {
            process?.terminate()
            process = nil
            outPipe?.fileHandleForReading.readabilityHandler = nil
            outPipe = nil
            DispatchQueue.main.async { self.isRunning = false }
            appendLog("网关已安全停止，端口释放完毕。")
        }
    }
    
    func configureClaude(apiKey: String, port: String, fallbackModel: String) {
        if apiKey.isEmpty {
            appendLog("错误：配置客户端需要填写 API Key。")
            return
        }
        
        let enginePath = Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/codex-engine").path
        let task = Process()
        task.executableURL = URL(fileURLWithPath: enginePath)
        
        let args = ["-port", port, "-apikey", apiKey, "-fallback-model", fallbackModel, "-config-claude=true"]
        task.arguments = args
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try task.run()
                task.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    self?.appendLog(output.trimmingCharacters(in: .newlines))
                    self?.appendLog("✅ Claude 专用环境配置注入完毕，请重启应用以生效。")
                }
            } catch {
                self?.appendLog("配置失败: \(error.localizedDescription)")
            }
        }
    }
}

struct CodexView: View {
    @AppStorage("NvidiaApiKey") var apiKey: String = ""
    @AppStorage("GatewayPort") var port: String = "8080"
    @AppStorage("FallbackModel") var fallbackModel: String = "meta/llama-3.1-70b-instruct"
    
    @StateObject var engine = EngineManager()
    @State private var isApiKeyVisible: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("大模型协议网关")
                        .font(.system(size: 28, weight: .bold))
                    
                    Group {
                        if engine.isRunning {
                            Text("运行中")
                                .foregroundColor(.green)
                        } else {
                            Text("已停止")
                                .foregroundColor(.gray)
                        }
                    }
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(6)
                }
                
                Text("为 Claude Desktop 提供专属的免代理直连 Nvidia NIM 服务。")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("英伟达 API Key:")
                            .frame(width: 120, alignment: .leading)
                        
                        ZStack(alignment: .trailing) {
                            if isApiKeyVisible {
                                TextField("输入 Nvidia API Key", text: $apiKey)
                                    .textFieldStyle(.roundedBorder)
                            } else {
                                SecureField("输入 Nvidia API Key", text: $apiKey)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            Button(action: { isApiKeyVisible.toggle() }) {
                                Image(systemName: isApiKeyVisible ? "eye.slash.fill" : "eye.fill")
                                    .foregroundColor(.gray)
                            }
                            .buttonStyle(.plain)
                            .padding(.trailing, 8)
                        }
                    }
                    HStack {
                        Text("监听端口:")
                            .frame(width: 120, alignment: .leading)
                        TextField("8080", text: $port)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                    }
                    HStack {
                        Text("重定向模型:")
                            .frame(width: 120, alignment: .leading)
                        Picker("", selection: $fallbackModel) {
                            ForEach(engine.availableModels, id: \.self) { model in
                                Text(formatModelName(model)).tag(model)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 250)
                        
                        Button(action: {
                            engine.fetchModels(apiKey: apiKey)
                        }) {
                            if engine.isFetchingModels {
                                ProgressView().controlSize(.small).frame(width: 16, height: 16)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }
                        }
                        .buttonStyle(.plain)
                        .help("刷新可用模型列表")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .premiumCard()
            }
            
            HStack(spacing: 16) {
                Button(action: {
                    if engine.isRunning {
                        engine.stopGateway()
                    } else {
                        engine.startGateway(apiKey: apiKey, port: port, fallbackModel: fallbackModel)
                    }
                }) {
                    Label(engine.isRunning ? "停止引擎" : "启动核心网关", systemImage: engine.isRunning ? "stop.circle.fill" : "play.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(engine.isRunning ? .red : .blue)
                .controlSize(.large)
                
                Button(action: {
                    engine.configureClaude(apiKey: apiKey, port: port, fallbackModel: fallbackModel)
                }) {
                    Label("注入 Claude 配置", systemImage: "wand.and.stars")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button(action: {
                    let task = Process()
                    task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                    task.arguments = ["-a", "Claude"]
                    try? task.run()
                    engine.appendLog("🚀 正在唤醒 Claude 客户端...")
                }) {
                    Label("唤醒 Claude", systemImage: "sparkles.tv")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            
            VStack(spacing: 0) {
                HStack {
                    Text("Console Output")
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
                            ForEach(Array(engine.logs.enumerated()), id: \.offset) { index, log in
                                Text(log)
                                    .foregroundColor(logColor(for: log))
                                    .id(index)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onChange(of: engine.logs.count) { _ in
                            if !engine.logs.isEmpty {
                                proxy.scrollTo(engine.logs.count - 1, anchor: .bottom)
                            }
                        }
                    }
                }
                .background(Color.black.opacity(0.85))
                .font(.system(size: 12, design: .monospaced))
            }
            .frame(height: 220)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
        }
        .onAppear {
            if !apiKey.isEmpty && engine.availableModels.count <= 2 {
                engine.fetchModels(apiKey: apiKey)
            }
        }
    }
    
    private func logColor(for text: String) -> Color {
        if text.contains("错误") || text.contains("失败") { return .red }
        if text.contains("成功") || text.contains("✅") { return .green }
        return Color(red: 0, green: 1, blue: 0.25)
    }
    
    private func formatModelName(_ id: String) -> String {
        let lower = id.lowercased()
        if lower.contains("deepseek") {
            return "\(id) (🏆 编程王者)"
        } else if lower.contains("405b") {
            return "\(id) (🧠 综合巨无霸)"
        } else if lower.contains("70b") || lower.contains("72b") {
            return "\(id) (⚡️ 极速日常)"
        }
        return id
    }
}
