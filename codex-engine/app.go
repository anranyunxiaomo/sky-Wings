package main

import (
	"context"
)

// App struct
type App struct {
	ctx     context.Context
	gateway *Gateway
}

// NewApp creates a new App application struct
func NewApp(fallbackModel string) *App {
	return &App{
		gateway: NewGateway(fallbackModel),
	}
}

// startup is called when the app starts. The context is saved
// so we can call the runtime methods
func (a *App) startup(ctx context.Context) {
	a.ctx = ctx
}

// StartGateway starts the local API gateway
func (a *App) StartGateway(apiKey string, port int) error {
	return a.gateway.Start(port, apiKey)
}

// StopGateway stops the local API gateway
func (a *App) StopGateway() error {
	return a.gateway.Stop()
}
