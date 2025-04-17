# Consul Sandbox

WARNING

-------------------------------------------------------------------------

This environment is not production-ready, as it does not follow our
recommendations for production-ready cluster deployments. Refer to the
[Consul Deployment Guide](https://developer.hashicorp.com/consul/tutorials/production-vms/deployment-guide)
for more information.

It is meant to serve as a development and testing environment. It is
"production-lite" as it enables gossip encryption, TLS, and ACLs.

-------------------------------------------------------------------------

This is a 3-node Consul community edition datacenter running in a Docker environment.

Alongside the server nodes 4 client nodes are also added to the datacenter. The
nodes are running HashiCups, a demo web application.

One extra node, Bastion Host, is also added to the scenario to simulate scenarios
where there is no direct access to the different nodes composing the Consul 
datacenter and a bastion host is required to access the nodes.

## Architecture

Refer to the `ARCHITECTURE.md` file to find a diagram of the deployed scenario.

## Configuration and logs

You can find container data, configuration, and logs in the `var` directory. 


You can get an overview of the content using the `tree` command.

```
tree /root/repository/var
```

You can browse the files from the Files tab as well.

## Access the nodes

The recommended method to access the different nodes is using SSH.

You can SSH into the Bastion Host using:

```
ssh -i certs/id_rsa admin@localhost -p 2222
```

You can also use one of the two `Bastion Host` tabs to get direct access into
the Bastion Host node.

## Interact with Consul

From Bastion Host you can directly interact with Consul.

First, load necessary environment variables.

```
source assets/scenario/env-consul.env 
```

After that you can directly use Consul CLI to interact with your datacenter.

```
consul members
```

You can also use the `Consul UI` tab to interact with Consul.

If you want to login to the UI use the token present in the `env-consul.env` file.