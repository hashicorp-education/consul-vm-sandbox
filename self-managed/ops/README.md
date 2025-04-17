# Operations code for scenarios

This folder contains the code used for the configuration of the different scenarios.

```
./self-managed/ops/
├── conf
│   ├── 00_base_consul_dc.tfvars
│   ├── 01_modular_scenario_sd.tfvars
│   ├── 01_modular_scenario_sm.tfvars
│   ├── ...
│   └── ...
├── scenarios
│   ├── 00_base_scenario_files   
│   │   ├── base_consul_dc
│   │   └── supporting_scripts
│   ├── 00_shared_functions.env
│   ├── 01_md_log_functions.env
│   ├── 10_scenario_functions.env
│   ├── 20_infrastructure_functions.env
│   ├── 30_utility_functions.env
│   └── tutorials
│       ├── 00_test_base
│       ├── 00_test_modular
│       ├── connect_services/
│       ├── network_automation/
│       └── secure_services/
├── provision.sh   
└── README.md  
```

## Application deployed

All the scenarios use a demo application to demonstrate the different Consul use cased. 

The application selected for the scenarios is the [HashiCups](../../docs/HashiCups.md) application, a multi-tier demo coffee shop application made up of several services.

## The `provision.sh` script

Most of the scenario configuration logic is performed via the `provision.sh` script.

In both AWS and Docker environments the `provision.sh` is executed at the end of the infrastructure deployment process, on the [Bastion Host](../../docs/BastionHost.md).

- AWS example

```hcl
resource "aws_instance" "bastion" {
  
  ...

  # Waits for cloud-init to complete. Needed for ACL creation.
  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for user data script to finish'",
      "cloud-init status --wait > /dev/null", 
      "cd /home/admin/ops && bash ./provision.sh operate ${var.scenario}"
    ]
  }

  ...
}
```

- Docker example

```hcl
resource "docker_container" "bastion_host" {
  
  ...

  provisioner "remote-exec" {
    inline = [
      "cd /home/admin/ops && bash ./provision.sh operate ${var.scenario}"
    ]
  }
}
```

In both cases the `${var.scenario}` value is used to find the scenario to configure.

### The provision flow

The provision uses the `operate` function to:

- Generate the `operate.sh` script that contains all steps to configure the scenario prerequisites
- Generate the `solve.sh` script that contains all steps to solve the scenario
- Copy the `solve.sh` on Bastion Host at `/home/admin/assets/scenario/scripts/solve.sh`
- Copy the `operate.sh` on Bastion Host at `/home/admin/assets/scenario/scripts/operate.sh`
- Run the `operate.sh` on Bastion Host to configure the scenario prerequisites.
