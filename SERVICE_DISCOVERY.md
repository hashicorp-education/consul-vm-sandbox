# Service Discovery

The services are configured using configuration files placed into the Consul 
configuration folder in each client.

For this scenario we used the standard configuration path `etc/consul.d`.

## Review available configuration

From Bastion Host you can review the configuration files used to configure the sandbox.

```
tree assets
```

Using the Consul CLI is it possible to interact with Consul registry and list 
registered services.

First, load necessary environment variables.

```
source assets/scenario/env-consul.env 
```

Then query the Consul registry to retrieve registered services.

```
consul catalog services -tags
```


## Change configuration for a service

Using the configuration files it is possible to change the service definitions.

As example you can change the tags for the `hashicups-frontend` service.

First login to the `hashicups-frontend-0` node.

```
ssh -i certs/id_rsa hashicups-frontend-0
```

Then edit the `svc-hashicups-frontend.hcl` file in the `/etc/consul.d` directory.

```
vim /etc/consul.d/svc-hashicups-frontend.hcl 
```

Edit the file to add a tag.

```
## -----------------------------
## svc-hashicups-frontend.hcl
## -----------------------------
service {
  name = "hashicups-frontend"
  id = "hashicups-frontend-0"
  tags = [ "inst_1", "my_tag" ]
  port = 3000
  token = "b6aa4574-9581-bd10-da1f-6753c9cf1299"

  check     
  {
    id =  "check-hashicups-frontend",
    name = "hashicups-frontend status check",
    service_id = "hashicups-frontend-0",
    tcp  = "localhost:3000",
    interval = "5s",
    timeout = "5s"
  }
}
```

Then query the Consul registry to verify the tag changed.

```
consul catalog services -tags
```

## Resources

Using the configuration file you can change other settings of your services and
add extra health checks.

For more detailed examples check our tutorials at 
[Monitor your application health with distributed checks](https://developer.hashicorp.com/consul/tutorials/connect-services/monitor-applications-health-checks)
