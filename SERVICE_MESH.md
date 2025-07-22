# Service Mesh

The services are configured using configuration files placed into the Consul 
configuration folder in each client.

For this scenario we used the standard configuration path `etc/consul.d`.

## Review available configuration

From Bastion Host, you can review the configuration files used to configure the sandbox. These configuration files include service definitions, intentions, and more.

```
tree assets
```

You can use the Consul CLI to interact with Consul registry and list registered services.

First, load necessary environment variables.

```
source assets/scenario/env-consul.env 
```

Then, query the Consul registry to retrieve registered services.

```
consul catalog services -tags
```

You can also review configured intentions.

```
consul intention list
```

## Resources

For more detailed examples on how to configure services, check our tutorial at [Monitor your application health with distributed checks](https://developer.hashicorp.com/consul/tutorials/connect-services/monitor-applications-health-checks).

For more detailed examples on how to configure intentions, check our tutorials at:
 - [Control traffic communication between services with intentions](https://developer.hashicorp.com/consul/tutorials/secure-services/secure-services-intentions)
 - [Control service requests with application-aware intentions](https://developer.hashicorp.com/consul/tutorials/secure-services/secure-services-intentions-l7)
