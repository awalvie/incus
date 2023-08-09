package main

import (
	"context"

	clusterConfig "github.com/lxc/incus/incus/cluster/config"
	"github.com/lxc/incus/incus/db"
	"github.com/lxc/incus/incus/node"
	"github.com/lxc/incus/incus/state"
	"github.com/lxc/incus/shared"
)

func daemonConfigRender(state *state.State) (map[string]any, error) {
	config := map[string]any{}

	// Turn the config into a JSON-compatible map.
	for key, value := range state.GlobalConfig.Dump() {
		config[key] = value
	}

	// Apply the local config.
	err := state.DB.Node.Transaction(context.TODO(), func(ctx context.Context, tx *db.NodeTx) error {
		nodeConfig, err := node.ConfigLoad(ctx, tx)
		if err != nil {
			return err
		}

		for key, value := range nodeConfig.Dump() {
			config[key] = value
		}

		return nil
	})
	if err != nil {
		return nil, err
	}

	return config, nil
}

func daemonConfigSetProxy(d *Daemon, config *clusterConfig.Config) {
	// Update the cached proxy function
	d.proxy = shared.ProxyFromConfig(
		config.ProxyHTTPS(),
		config.ProxyHTTP(),
		config.ProxyIgnoreHosts(),
	)
}