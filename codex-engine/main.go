package main

import (
	"flag"
	"fmt"
	"os"
	"os/signal"
	"syscall"
)

func main() {
	port := flag.Int("port", 8080, "Gateway port")
	apiKey := flag.String("apikey", "", "Nvidia API Key")
	configClaude := flag.Bool("config-claude", false, "Configure Claude client")
	fallbackModel := flag.String("fallback-model", "meta/llama-3.1-70b-instruct", "Fallback model for Claude requests")

	flag.Parse()

	if *apiKey == "" {
		fmt.Println("Error: --apikey is required")
		os.Exit(1)
	}

	app := NewApp(*fallbackModel)

	if *configClaude {
		err := app.AutoConfigureClients(*port, *apiKey, *configClaude)
		if err != nil {
			fmt.Printf("Configure failed: %v\n", err)
			os.Exit(1)
		}
		fmt.Println("Configure success")
		return
	}

	err := app.StartGateway(*apiKey, *port)
	if err != nil {
		fmt.Printf("Failed to start gateway: %v\n", err)
		os.Exit(1)
	}
	fmt.Printf("[System] Gateway started on port %d\n", *port)

	// Wait for interrupt signal
	sigs := make(chan os.Signal, 1)
	signal.Notify(sigs, syscall.SIGINT, syscall.SIGTERM)
	<-sigs

	fmt.Println("\nStopping gateway...")
	app.StopGateway()
}
