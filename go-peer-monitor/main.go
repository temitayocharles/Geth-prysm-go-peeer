package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/ethereum/go-ethereum/rpc"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

type PeerInfo struct {
	ID      string   `json:"id"`
	Name    string   `json:"name"`
	Caps    []string `json:"caps"`
	Network struct {
		LocalAddress  string `json:"localAddress"`
		RemoteAddress string `json:"remoteAddress"`
	} `json:"network"`
	Protocols map[string]interface{} `json:"protocols"`
}

var (
	peerCountGauge = prometheus.NewGauge(prometheus.GaugeOpts{
		Name: "geth_peer_count",
		Help: "Number of connected peers",
	})
)

func init() {
	prometheus.MustRegister(peerCountGauge)
}

func main() {
	gethURL := os.Getenv("GETH_RPC_URL")
	if gethURL == "" {
		gethURL = "http://geth.ethereum.svc.cluster.local:8545"
	}

	client, err := rpc.Dial(gethURL)
	if err != nil {
		log.Fatalf("Failed to connect to Geth: %v", err)
	}
	defer client.Close()

	go func() {
		http.Handle("/metrics", promhttp.Handler())
		log.Println("Starting metrics server on :8080")
		if err := http.ListenAndServe(":8080", nil); err != nil {
			log.Fatalf("Failed to start metrics server: %v", err)
		}
	}()

	log.Println("Starting peer monitoring...")
	ticker := time.NewTicker(10 * time.Second)
	defer ticker.Stop()

	for {
		peers, err := getPeers(client)
		if err != nil {
			log.Printf("Error fetching peers: %v", err)
		} else {
			displayPeers(peers)
			peerCountGauge.Set(float64(len(peers)))
		}

		<-ticker.C
	}
}

func getPeers(client *rpc.Client) ([]PeerInfo, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	var peers []PeerInfo
	err := client.CallContext(ctx, &peers, "admin_peers")
	if err != nil {
		return nil, fmt.Errorf("failed to call admin_peers: %w", err)
	}

	return peers, nil
}

func displayPeers(peers []PeerInfo) {
	timestamp := time.Now().Format("2006-01-02 15:04:05")
	fmt.Printf("\n=== Connected Peers at %s ===\n", timestamp)
	fmt.Printf("Total Peers: %d\n\n", len(peers))

	for i, peer := range peers {
		fmt.Printf("Peer %d:\n", i+1)
		fmt.Printf("  ID: %s\n", peer.ID)
		fmt.Printf("  Name: %s\n", peer.Name)
		fmt.Printf("  Remote Address: %s\n", peer.Network.RemoteAddress)
		fmt.Printf("  Capabilities: %v\n", peer.Caps)

		if ethProtocol, ok := peer.Protocols["eth"]; ok {
			ethData, _ := json.MarshalIndent(ethProtocol, "  ", "  ")
			fmt.Printf("  ETH Protocol: %s\n", string(ethData))
		}

		fmt.Println()
	}
	fmt.Println("================================")
}
