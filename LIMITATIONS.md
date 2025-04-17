# Limitations

## Consul startup command

The Consul nodes do not have systemd installed so Consul needs to be stopped and started manually.

The command to start Consul on each node is:

```
consul agent -config-dir=/etc/consul.d > /tmp/logs/consul-server.log 2>&1 & 
```

The command starts Consul in the background to not lock the terminal.