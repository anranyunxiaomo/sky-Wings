package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// AutoConfigureClients 自动修改本地客户端（Claude 等）的配置
func (a *App) AutoConfigureClients(port int, apiKey string, configClaude bool) error {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return fmt.Errorf("failed to get home dir: %w", err)
	}

	baseURL := fmt.Sprintf("http://127.0.0.1:%d/v1", port)

	if configClaude {
		// 2. 自动扫描并注入配置到 Claude Desktop 的所有底层 JSON 文件
		if err := configureClaudeJSON(homeDir, apiKey, baseURL); err != nil {
			fmt.Printf("Warning: failed to configure Claude: %v\n", err)
		} else {
			fmt.Println("Claude Desktop native configuration injected.")
		}
	}

	return nil
}

func configureClaudeJSON(homeDir string, apiKey string, baseURL string) error {
	// 查找所有可能的 Claude 目录，例如 Claude 或 Claude-3p
	appSupportPath := filepath.Join(homeDir, "Library", "Application Support")
	
	// 这里可以匹配 Claude, Claude-3p, Claude-beta 等等
	matches, err := filepath.Glob(filepath.Join(appSupportPath, "Claude*"))
	if err != nil || len(matches) == 0 {
		return fmt.Errorf("no Claude directories found")
	}

	configuredCount := 0

	for _, claudeDir := range matches {
		configLibraryDir := filepath.Join(claudeDir, "configLibrary")
		
		// 如果不存在 configLibrary，说明可能不是目标应用，或者是旧版本
		if _, err := os.Stat(configLibraryDir); os.IsNotExist(err) {
			continue
		}

		// 遍历 configLibrary 下所有的 .json 文件
		jsonFiles, _ := filepath.Glob(filepath.Join(configLibraryDir, "*.json"))
		for _, jsonFile := range jsonFiles {
			// 读取 JSON 文件
			data, err := os.ReadFile(jsonFile)
			if err != nil {
				continue
			}

			var config map[string]interface{}
			if err := json.Unmarshal(data, &config); err != nil {
				continue
			}

			// 只要是合法的 JSON，我们就强行注入/覆盖推理网关配置
			config["inferenceProvider"] = "gateway"
			
			// 关键修复：Claude 客户端会在 baseURL 后面自动拼接 /v1/messages
			// 如果 baseURL 自带了 /v1，会导致请求变成 /v1/v1/messages 而报 404 模型找不到的错误！
			cleanBaseURL := strings.TrimSuffix(baseURL, "/v1")
			config["inferenceGatewayBaseUrl"] = cleanBaseURL
			
			config["inferenceGatewayApiKey"] = apiKey
			config["inferenceGatewayAuthScheme"] = "bearer"

			// 写回文件
			updatedData, err := json.MarshalIndent(config, "", "  ")
			if err != nil {
				continue
			}

			if err := os.WriteFile(jsonFile, updatedData, 0644); err == nil {
				configuredCount++
				fmt.Printf("Injected config into: %s\n", jsonFile)
			}
		}
	}

	if configuredCount == 0 {
		return fmt.Errorf("found Claude directories but no valid JSON configs found in configLibrary")
	}

	return nil
}


