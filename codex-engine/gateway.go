package main

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httputil"
	"net/url"
	"strings"
	"sync"
)

type Gateway struct {
	server        *http.Server
	apiKey        string
	fallbackModel string
	mu            sync.Mutex
}

func NewGateway(fallbackModel string) *Gateway {
	if fallbackModel == "" {
		fallbackModel = "meta/llama-3.1-70b-instruct"
	}
	return &Gateway{
		fallbackModel: fallbackModel,
	}
}

// Start 启动网关服务
func (g *Gateway) Start(port int, apiKey string) error {
	g.mu.Lock()
	defer g.mu.Unlock()

	if g.server != nil {
		return fmt.Errorf("gateway is already running")
	}

	g.apiKey = apiKey
	mux := http.NewServeMux()

	// OpenAI 协议透传通道
	mux.HandleFunc("/v1/chat/completions", g.handleOpenAIPassThrough)
	// Anthropic 协议转换通道
	mux.HandleFunc("/v1/messages", g.handleAnthropicToOpenAI)

	g.server = &http.Server{
		Addr:    fmt.Sprintf(":%d", port),
		Handler: mux,
	}

	go func() {
		// 启动 HTTP 服务
		if err := g.server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			fmt.Printf("Gateway server error: %v\n", err)
		}
	}()

	return nil
}

// Stop 停止网关服务
func (g *Gateway) Stop() error {
	g.mu.Lock()
	defer g.mu.Unlock()

	if g.server != nil {
		err := g.server.Shutdown(context.Background())
		g.server = nil
		return err
	}
	return nil
}

// handleOpenAIPassThrough 代理 OpenAI 请求到 Nvidia
func (g *Gateway) handleOpenAIPassThrough(w http.ResponseWriter, r *http.Request) {
	// Nvidia 的目标 URL
	targetURL, _ := url.Parse("https://integrate.api.nvidia.com")

	proxy := httputil.NewSingleHostReverseProxy(targetURL)

	// 修改请求头
	originalDirector := proxy.Director
	proxy.Director = func(req *http.Request) {
		originalDirector(req)
		req.Host = targetURL.Host
		
		// 确保路径正确映射
		if !strings.HasPrefix(req.URL.Path, "/v1/") {
			req.URL.Path = "/v1" + req.URL.Path
		}
		
		// 注入 Nvidia API Key
		req.Header.Set("Authorization", "Bearer "+g.apiKey)
		// 移除可能引起编码问题的 Header
		req.Header.Del("Accept-Encoding")
	}

	// 允许跨域 (CORS) 以支持各类客户端
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization, x-api-key, anthropic-version")

	if r.Method == "OPTIONS" {
		w.WriteHeader(http.StatusOK)
		return
	}

	proxy.ServeHTTP(w, r)
}

// handleAnthropicToOpenAI 转换 Claude 请求为 OpenAI 并将响应流逆向转换
func (g *Gateway) handleAnthropicToOpenAI(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type, x-api-key, anthropic-version")

	if r.Method == "OPTIONS" {
		w.WriteHeader(http.StatusOK)
		return
	}

	// 1. 读取并转换请求
	var anthropicReq map[string]interface{}
	if err := json.NewDecoder(r.Body).Decode(&anthropicReq); err != nil {
		http.Error(w, "Invalid JSON", http.StatusBadRequest)
		return
	}

	modelName := anthropicReq["model"]
	if mStr, ok := modelName.(string); ok {
		// 如果客户端请求的是 claude 模型，自动映射到指定的 fallback 模型
		if strings.Contains(strings.ToLower(mStr), "claude") {
			modelName = g.fallbackModel
		}
	}

	openAIReq := map[string]interface{}{
		"model":       modelName,
		"stream":      anthropicReq["stream"],
		"max_tokens":  anthropicReq["max_tokens"],
		"temperature": anthropicReq["temperature"],
	}

	// 转换 messages 和 system prompt
	var messages []map[string]interface{}
	if sys, ok := anthropicReq["system"].(string); ok && sys != "" {
		messages = append(messages, map[string]interface{}{"role": "system", "content": sys})
	}

	if msgs, ok := anthropicReq["messages"].([]interface{}); ok {
		for _, m := range msgs {
			if msgMap, ok := m.(map[string]interface{}); ok {
				// Anthropic 的 content 可能是数组，OpenAI 需要转为字符串 (简单处理)
				if contentArr, isArr := msgMap["content"].([]interface{}); isArr {
					var textContent string
					for _, block := range contentArr {
						if blockMap, isBlockMap := block.(map[string]interface{}); isBlockMap {
							if text, hasText := blockMap["text"].(string); hasText {
								textContent += text + "\n"
							}
						}
					}
					msgMap["content"] = strings.TrimSpace(textContent)
				}
				messages = append(messages, msgMap)
			}
		}
	}
	openAIReq["messages"] = messages

	reqBody, _ := json.Marshal(openAIReq)
	fmt.Printf("[Debug] Request to Nvidia: %s\n", string(reqBody))

	nvReq, err := http.NewRequest("POST", "https://integrate.api.nvidia.com/v1/chat/completions", bytes.NewBuffer(reqBody))
	if err != nil {
		http.Error(w, "Failed to create request", http.StatusInternalServerError)
		return
	}

	nvReq.Header.Set("Content-Type", "application/json")
	nvReq.Header.Set("Authorization", "Bearer "+g.apiKey)
	nvReq.Header.Set("Accept", "text/event-stream")

	client := &http.Client{}
	resp, err := client.Do(nvReq)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadGateway)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		w.WriteHeader(resp.StatusCode)
		buf := new(bytes.Buffer)
		buf.ReadFrom(resp.Body)
		fmt.Printf("[Debug] Error from Nvidia: %d %s\n", resp.StatusCode, buf.String())
		w.Write(buf.Bytes())
		return
	}

	// 3. 处理流式响应转换
	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")
	flusher, ok := w.(http.Flusher)

	// 发送 Anthropic 的起始事件
	fmt.Fprintf(w, "event: message_start\ndata: {\"type\": \"message_start\", \"message\": {\"id\": \"msg_1\", \"type\": \"message\", \"role\": \"assistant\", \"model\": \"claude\"}}\n\n")
	fmt.Fprintf(w, "event: content_block_start\ndata: {\"type\": \"content_block_start\", \"index\": 0, \"content_block\": {\"type\": \"text\", \"text\": \"\"}}\n\n")
	if ok {
		flusher.Flush()
	}

	scanner := bufio.NewScanner(resp.Body)
	for scanner.Scan() {
		line := scanner.Text()
		if !strings.HasPrefix(line, "data: ") {
			continue
		}
		dataStr := strings.TrimPrefix(line, "data: ")
		if dataStr == "[DONE]" || dataStr == "" {
			continue
		}

		var chunk map[string]interface{}
		if err := json.Unmarshal([]byte(dataStr), &chunk); err == nil {
			if choices, has := chunk["choices"].([]interface{}); has && len(choices) > 0 {
				if choice, isMap := choices[0].(map[string]interface{}); isMap {
					if delta, hasDelta := choice["delta"].(map[string]interface{}); hasDelta {
						if content, hasContent := delta["content"].(string); hasContent && content != "" {
							// 包装为 Anthropic delta
							anthropicDelta := map[string]interface{}{
								"type":  "content_block_delta",
								"index": 0,
								"delta": map[string]interface{}{
									"type": "text_delta",
									"text": content,
								},
							}
							deltaJSON, _ := json.Marshal(anthropicDelta)
							fmt.Fprintf(w, "event: content_block_delta\ndata: %s\n\n", deltaJSON)
							if ok {
								flusher.Flush()
							}
						}
					}
				}
			}
		}
	}

	// 结束事件
	fmt.Fprintf(w, "event: content_block_stop\ndata: {\"type\": \"content_block_stop\", \"index\": 0}\n\n")
	fmt.Fprintf(w, "event: message_stop\ndata: {\"type\": \"message_stop\"}\n\n")
	if ok {
		flusher.Flush()
	}
}
