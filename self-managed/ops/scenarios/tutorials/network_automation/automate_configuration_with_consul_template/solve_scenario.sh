#!/usr/bin/env bash

# ++-----------------+
# || Functions       |
# ++-----------------+

# ++-----------------+
# || Variables       |
# ++-----------------+

username=${username:-$(whoami)}

export STEP_ASSETS="${SCENARIO_OUTPUT_FOLDER}conf/"

export MD_RUNBOOK_FILE=/home/${username}/solve_runbook.md

## [ux-diff] [cloud provider] UX differs across different Cloud providers 
if [ "${SCENARIO_CLOUD_PROVIDER}" == "docker" ]; then

  NGINX_CONF_PATH="/etc/nginx/conf.d"

elif [ "${SCENARIO_CLOUD_PROVIDER}" == "aws" ]; then
  
  NGINX_CONF_PATH="/home/${username}"
  
elif [ "${SCENARIO_CLOUD_PROVIDER}" == "azure" ]; then
  
  NGINX_CONF_PATH="/home/${username}"
  
else

  log_err "Cloud provider $SCENARIO_CLOUD_PROVIDER is unsupported...exiting."

  exit 245
fi



# ++-----------------+
# || Begin           |
# ++-----------------+

header1 "Automate reverse proxy configuration with consul-template"

# H1 ===========================================================================
md_log "
# Automate reverse proxy configuration with consul-template"
# ==============================================================================

md_log "
This is a solution runbook for the scenario deployed.
"

md_log "
Consul template provides a programmatic method for rendering configuration files from a variety of locations, including Consul KV and Consul service catalog. 
It is an ideal option for replacing complicated API queries that often require custom formatting."

##  H2 -------------------------------------------------------------------------
md_log "
## Prerequisites"
# ------------------------------------------------------------------------------

md_log "
Login to the Bastion Host"

## [ux-diff] [cloud provider] UX differs across different Cloud providers 
if [ "${SCENARIO_CLOUD_PROVIDER}" == "docker" ]; then

  md_log_cmd 'ssh -i images/base/certs/id_rsa '${username}'@localhost -p 2222`
#...
'${username}'@bastion:~$'

elif [ "${SCENARIO_CLOUD_PROVIDER}" == "aws" ]; then
  
  md_log_cmd 'ssh -i certs/id_rsa.pem '${username}'@`terraform output -raw ip_bastion`
#...
'${username}'@bastion:~$'

elif [ "${SCENARIO_CLOUD_PROVIDER}" == "azure" ]; then
  
  md_log_cmd 'ssh -i certs/id_rsa.pem '${username}'@`terraform output -raw ip_bastion`
#...
'${username}'@bastion:~$'

else

  log_err "Cloud provider $SCENARIO_CLOUD_PROVIDER is unsupported...exiting."

  exit 245
fi

### H3 .........................................................................
md_log "
### Configure CLI to interact with Consul" 
# ..............................................................................

md_log "
Configure your bastion host to communicate with your Consul environment using the two dynamically generated environment variable files."

_RUN_CMD 'source "'${ASSETS}'scenario/env-scenario.env" && \
  source "'${ASSETS}'scenario/env-consul.env"'

_STAT="$?"

if [ "${_STAT}" -ne 0 ];  then
  log_err "Error reading variables"
  exit 254
fi

## Running the source command locally for variable visibility reasons
source "${ASSETS}scenario/env-scenario.env" && \
source "${ASSETS}scenario/env-consul.env"

md_log "
After loading the needed variables, verify you can connect to your Consul 
datacenter."

_RUN_CMD 'consul members'    

_STAT="$?"

if [ "${_STAT}" -ne 0 ];  then
  log_err "Error connecting to Consul."
  exit 254
fi

##  H2 -------------------------------------------------------------------------
md_log "
## Create ACL token for consul-template"
# ------------------------------------------------------------------------------

md_log "
In this tutorial you will use consul-template to generate configuration for hashicups-nginx upstreams."

md_log '
For this reason, you need a token providing `read` permissions  on both hashicups-api and hashicups-frontend.'

md_log '
First, create the proper configuration file for the policy.'

_RUN_CMD 'tee /home/'${username}'/assets/scenario/conf/acl-policy-consul-template.hcl > /dev/null << EOF
# -------------------------------+
# acl-policy-consul-template.hcl |
# -------------------------------+

service "hashicups-frontend" {
  policy = "read"
}

service "hashicups-api" {
  policy = "read"
}

node_prefix "hashicups-frontend" {
  policy = "read"
}

node_prefix "hashicups-api" {
  policy = "read"
}
EOF
'

md_log '
Then, create the policy using the generated file.'

_RUN_CMD 'consul acl policy create \
          -name "consul-template-policy" \
          -description "Policy for consul-template to generate configuration for hashicups-nginx" \
          -rules @/home/'${username}'/assets/scenario/conf/acl-policy-consul-template.hcl'

_STAT="$?"

if [ "${_STAT}" -ne 0 ];  then
  log_err "Error creating policy for consul-template."
  exit 254
fi

md_log '
Finally, generate the token from the policy.'

_RUN_CMD 'consul acl token create \
  -description="Consul-template token" \
  --format json \
  -policy-name="consul-template-policy" | tee '${STEP_ASSETS}'secrets/acl-token-consul-template.json'

_STAT="$?"

if [ "${_STAT}" -ne 0 ];  then
  log_err "Error creating token for consul-template."
  exit 254
fi

md_log '
Retrieve the token from the `acl-token-consul-template.json` file'


_RUN_CMD 'export CONSUL_TEMPLATE_TOKEN=`cat '${STEP_ASSETS}'secrets/acl-token-consul-template.json | jq -r ".SecretID"`'
## Exporting variables needs to be done also outside the _RUN_CMD commands. Otherwise environment will not pick them.
export CONSUL_TEMPLATE_TOKEN=`cat ${STEP_ASSETS}secrets/acl-token-consul-template.json | jq -r ".SecretID"`

_STAT="$?"

if [ "${_STAT}" -ne 0 ];  then
  log_err "Token file not found."
  exit 254
fi

md_log "
The token will be used in the consul-template configuration file."


##  H2 -------------------------------------------------------------------------
md_log "
## Configure consul-template"
# ------------------------------------------------------------------------------

md_log "
To use consul-template, you will need a configuration file and a template file to generate the application configuration."

###  H3 -------------------------------------------------------------------------
md_log "
### Confiugration file"
# ------------------------------------------------------------------------------

md_log "
A basic configuration for consul-template requires the following parameters:
- A Consul address, to find a Consul agent to conect to.
- A valid token for Consul, to use Consul API when ACLs are enabled.
- A template file path, to define the location for the template used to generate the configuration.
- An output file path, to save the generated file.
- Optionally, a command to execute once the output file changes.
"

md_log "
Create consul-template configuration file."

_RUN_CMD 'tee /home/'${username}'/assets/scenario/conf/hashicups-nginx-0/consul_template.hcl > /dev/null << EOF
# This denotes the start of the configuration section for Consul. All values
# contained in this section pertain to Consul.
consul {
  # This is the address of the Consul agent to use for the connection. 
  # The protocol (http(s)) portion of the address is required.
  address      = "http://localhost:8500"

  # This value can also be specified via the environment variable CONSUL_HTTP_TOKEN.
  token        = "${CONSUL_TEMPLATE_TOKEN}"
}

# This is the log level. This is also available as a command line flag.
# Valid options include (in order of verbosity): trace, debug, info, warn, err
log_level = "info"

# This block defines the configuration for logging to file
log_file {
  # If a path is specified, the feature is enabled 
  path = "/tmp/consul-template.log"
}

# This is the path to store a PID file which will contain the process ID of the
# Consul Template process. This is useful if you plan to send custom signals
# to the process.
pid_file = "/tmp/consul-template.pid"

# This is the signal to listen for to trigger a reload event. The default value 
# is shown below. Setting this value to the empty string will cause 
# consul-template to not listen for any reload signals.
reload_signal = "SIGHUP"

# This is the signal to listen for to trigger a graceful stop. The default value 
# is shown below. Setting this value to the empty string will cause 
# consul-template to not listen for any graceful stop signals.
kill_signal = "SIGINT"

# This block defines the configuration for a template. Unlike other blocks,
# this block may be specified multiple times to configure multiple templates.
template {
  # This is the source file on disk to use as the input template. This is often
  # called the "consul-template template".
  source      = "nginx-upstreams.tpl"

  # This is the destination path on disk where the source template will render.
  # If the parent directories do not exist, consul-template will attempt to
  # create them, unless create_dest_dirs is false.
  destination = "'${NGINX_CONF_PATH}'/def_upstreams.conf"

  # This is the optional command to run when the template is rendered. 
  # The command will only run if the resulting template changes.
  command     = "/home/'${username}'/start_service.sh reload"
}
EOF
'

_STAT="$?"

if [ "${_STAT}" -ne 0 ];  then
  log_err "Error creating consul-template configuration file."
  exit 254
fi

md_log '
Copy the configuration file on the `hashicups-nginx-0` node.'

_RUN_CMD 'scp -r -i '${SSH_CERT}' /home/'${username}'/assets/scenario/conf/hashicups-nginx-0/consul_template.hcl '${username}'@hashicups-nginx-0:/home/'${username}'/consul_template.hcl'

_STAT="$?"

if [ "${_STAT}" -ne 0 ];  then
  log_err "Error copying configuration file to the remote node."
  exit 254
fi

md_log "
The remaining part of the configuration will be executed directly on the hashicups-nginx-0 node."

_CONNECT_TO hashicups-nginx-0

md_log "
Verify the configuration file for consul-template got correctly copied on the node."

_RUN_CMD -r hashicups-nginx-0 -o hcl "cat /home/${username}/consul_template.hcl"

_STAT="$?"

if [ "${_STAT}" -ne 0 ];  then
  log_err "Error. Configuration file not found on the remote node."
  exit 254
fi

###  H3 -------------------------------------------------------------------------
md_log "
### Template file"
# ------------------------------------------------------------------------------

md_log "
The second step of configuring consul-template is to generate a template file that will render into a configuration file for your service."

md_log "
The file to dynamically generate, in this scenario, is the upstream definition for the NGINX process."

md_log "
Check the original configuration file."

_RUN_CMD -r hashicups-nginx-0 -o hcl "cat ${NGINX_CONF_PATH}/def_upstreams.conf"

_STAT="$?"

if [ "${_STAT}" -ne 0 ];  then
  log_err "Error. NGINX configuration file not found on the remote node."
  exit 254
fi

md_log "
From the output, you can verify NGINX is configured to redirect requests to hashicups-frontend on port 3000 and hashicups-api on port 8081."

md_log "
Both upstreams are configured for sinlge instance only and do not include a weight factor for the load balancing."

md_log "
Query the Consul catalog to verify service instances."

_RUN_CMD -r hashicups-nginx-0 -o hcl "consul catalog services -tags"

_STAT="$?"

if [ "${_STAT}" -ne 0 ];  then
  log_err "Error. Consul catalog query error."
  exit 254
fi

md_log "
From the output, you can verify that two instances of hashicups-nginx are running and that, with the current configuration, the second instance is not being used for the traffic."

md_log "
Create a consul-template template to replace the configuration file and include multiple instances of the services."

_RUN_CMD -r hashicups-nginx-0 'tee /home/'${username}'/nginx-upstreams.tpl > /dev/null << EOF
upstream frontend_upstream {
  {{ range service "hashicups-frontend" -}}
  server {{ .Address }}:{{ .Port }};
  {{ end }}
}

upstream api_upstream {
  {{ range service "hashicups-api" -}}
  server {{ .Address }}:{{ .Port }};
  {{ end }}
}
EOF
'

_STAT="$?"

if [ "${_STAT}" -ne 0 ];  then
  log_err "Error creating configuration file."
  exit 254
fi

md_log '
Once the template file is ready you can test it using the `-dry` option provided by consul-template.
Using the `-dry` option consul-template will print generated templates to `stdout` instead of rendering them into the destionation file.
Use the `-once` execution mode to stop consul-template after the first iteration.
'

_RUN_CMD -r hashicups-nginx-0 -o log "consul-template -config=consul_template.hcl -once -dry 2>&1"

_STAT="$?"

if [ "${_STAT}" -ne 0 ];  then
  log_err "Error. consul-template test error."
  exit 254
fi

md_log '
The ouput shows that the generated configuration filer now contains both `hashicups-frontend` instances.
'

##  H2 -------------------------------------------------------------------------
md_log "
## Start consul-template"
# ------------------------------------------------------------------------------

md_log "
Once you tested the configuration, start consul-template to run as a long lived process.
"

_RUN_CMD -r hashicups-nginx-0 -o log "consul-template -config=consul_template.hcl > /tmp/logs/consul-template.log  2>&1 &"

_STAT="$?"

if [ "${_STAT}" -ne 0 ];  then
  log_err "Error. consul-template start error."
  exit 254
fi

md_log "
The process is started in the background, you can check the logs for the process using the log file specified in the configuration.
"

_RUN_CMD -r hashicups-nginx-0 -o log "cat /tmp/consul-template*.log"

_STAT="$?"

if [ "${_STAT}" -ne 0 ];  then
  log_err "Error. consul-template log file not found."
  exit 254
fi

md_log "
Verify that the configuration file got generated correctly.
"

_RUN_CMD -r hashicups-nginx-0 -o log "cat ${NGINX_CONF_PATH}/def_upstreams.conf"

_STAT="$?"

if [ "${_STAT}" -ne 0 ];  then
  log_err "Error. NGINX configuration file not found."
  exit 254
fi

##  H2 -------------------------------------------------------------------------
md_log "
## Verify configuration is generated dynamically"
# ------------------------------------------------------------------------------

md_log '
The configuration file is now managed directly by consul-template and in case of changes in the Consul catalog it is automaticall updated.
Test configuraton dynamic change by removing one of the two instances of `hashicups-frontend`.
'

_RUN_CMD -r hashicups-frontend-0 -o log "~/start_service.sh stop"

_STAT="$?"

if [ "${_STAT}" -ne 0 ];  then
  log_err "Error. NGINX configuration file not found."
  exit 254
fi

sleep 5

_RUN_CMD -r hashicups-nginx-0 -o log "cat ${NGINX_CONF_PATH}/def_upstreams.conf"

_STAT="$?"

if [ "${_STAT}" -ne 0 ];  then
  log_err "Error. NGINX configuration file not found."
  exit 254
fi

_RUN_CMD -r hashicups-frontend-0 -o log "~/start_service.sh start --consul-node"

_STAT="$?"

if [ "${_STAT}" -ne 0 ];  then
  log_err "Error. NGINX configuration file not found."
  exit 254
fi

sleep 5

_RUN_CMD -r hashicups-nginx-0 -o log "cat ${NGINX_CONF_PATH}/def_upstreams.conf"

_STAT="$?"

if [ "${_STAT}" -ne 0 ];  then
  log_err "Error. NGINX configuration file not found."
  exit 254
fi

##  H2 -------------------------------------------------------------------------
md_log "
## Tune configuration with Consul KV"
# ------------------------------------------------------------------------------

md_log '
The configuration obtained configures a basic round robin load-balancing approach. 
This is often enough in most scenarios but, in cases like blue-green or canary deployments, 
you might want to fine tune the configuration to send most of the traffic to an instance of the service.
NGINX uses the `weight` parameter to distribute traffic across the different available upstreams. 
In a static configuration file you can manually define the weight settings for each service instance but,
in a situation when the content of the file is generated automatically by consul-template you need a
different way to pass configuration parameters to NGINX. In this scenario you will use Consul KV to
define the weights for the different instances and will change the template to take these changes into consideration.
'

###  H3 -------------------------------------------------------------------------
md_log "
###  Add configuration in Consul KV"
# ------------------------------------------------------------------------------

md_log '
Insert configuration into Consul KV.
'

_RUN_CMD 'consul kv put weights/hashicups-frontend-1 3'

_STAT="$?"

if [ "${_STAT}" -ne 0 ];  then
  log_err "Error adding key in Consul KV."
  exit 254
fi

###  H3 -------------------------------------------------------------------------
md_log "
### Update ACL policy"
# ------------------------------------------------------------------------------

md_log '
Having the configuration written in Consul KV means that consul-template needs permissions to read
keys from the KV store at least on the paths where the configuration is located. For this example we 
'

md_log '
First, create the proper configuration file for the policy.'

_RUN_CMD 'tee /home/'${username}'/assets/scenario/conf/acl-policy-consul-template-2.hcl > /dev/null << EOF
# ---------------------------------+
# acl-policy-consul-template-2.hcl |
# ---------------------------------+

service "hashicups-frontend" {
  policy = "read"
}

service "hashicups-api" {
  policy = "read"
}

node_prefix "hashicups-frontend" {
  policy = "read"
}

node_prefix "hashicups-api" {
  policy = "read"
}

key_prefix "weights" {
  policy = "read"
}
EOF
'

_RUN_CMD 'consul acl policy update \
          -name "consul-template-policy" \
          -rules @/home/'${username}'/assets/scenario/conf/acl-policy-consul-template-2.hcl'

_STAT="$?"

if [ "${_STAT}" -ne 0 ];  then
  log_err "Error updating policy for consul-template."
  exit 254
fi

md_log '
 Updating the policy automatically extends permissions to the tokes associated with the policy. 
 Verify you can now read the key from the KV store.
'

_RUN_CMD 'export CONSUL_TEMPLATE_TOKEN=`cat '${STEP_ASSETS}'secrets/acl-token-consul-template.json | jq -r ".SecretID"`'
## Exporting variables needs to be done also outside the _RUN_CMD commands. Otherwise environment will not pick them.
export CONSUL_TEMPLATE_TOKEN=`cat ${STEP_ASSETS}secrets/acl-token-consul-template.json | jq -r ".SecretID"`

_STAT="$?"

if [ "${_STAT}" -ne 0 ];  then
  log_err "Token file not found."
  exit 254
fi

_RUN_CMD 'consul kv get -token=${CONSUL_TEMPLATE_TOKEN} weights/hashicups-frontend-1'

_STAT="$?"

if [ "${_STAT}" -ne 0 ];  then
  log_err "Error reading from Consul KV store."
  exit 254
fi

###  H3 ------------------------------------------------------------------------
md_log "
### Generate new configuration file for consul-template"
# ------------------------------------------------------------------------------

md_log "
Create consul-template configuration file."

_RUN_CMD 'tee /home/'${username}'/assets/scenario/conf/hashicups-nginx-0/consul_template_weights.hcl > /dev/null << EOF
# This denotes the start of the configuration section for Consul. All values
# contained in this section pertain to Consul.
consul {
  # This is the address of the Consul agent to use for the connection. 
  # The protocol (http(s)) portion of the address is required.
  address      = "http://localhost:8500"

  # This value can also be specified via the environment variable CONSUL_HTTP_TOKEN.
  token        = "${CONSUL_TEMPLATE_TOKEN}"
}

# This is the log level. This is also available as a command line flag.
# Valid options include (in order of verbosity): trace, debug, info, warn, err
log_level = "info"

# This block defines the configuration for logging to file
log_file {
  # If a path is specified, the feature is enabled 
  path = "/tmp/consul-template.log"
}

# This is the path to store a PID file which will contain the process ID of the
# Consul Template process. This is useful if you plan to send custom signals
# to the process.
pid_file = "/tmp/consul-template.pid"

# This is the signal to listen for to trigger a reload event. The default value 
# is shown below. Setting this value to the empty string will cause 
# consul-template to not listen for any reload signals.
reload_signal = "SIGHUP"

# This is the signal to listen for to trigger a graceful stop. The default value 
# is shown below. Setting this value to the empty string will cause 
# consul-template to not listen for any graceful stop signals.
kill_signal = "SIGINT"

# This block defines the configuration for a template. Unlike other blocks,
# this block may be specified multiple times to configure multiple templates.
template {
  # This is the source file on disk to use as the input template. This is often
  # called the "consul-template template".
  source      = "nginx-upstreams-weights.tpl"

  # This is the destination path on disk where the source template will render.
  # If the parent directories do not exist, consul-template will attempt to
  # create them, unless create_dest_dirs is false.
  destination = "'${NGINX_CONF_PATH}'/def_upstreams.conf"

  # This is the optional command to run when the template is rendered. 
  # The command will only run if the resulting template changes.
  command     = "/home/'${username}'/start_service.sh reload"
}

# This block defines the configuration for a template. Unlike other blocks,
# this block may be specified multiple times to configure multiple templates.
template {
  # This is the source file on disk to use as the input template. This is often
  # called the "consul-template template".
  contents      = "{{ range \$key, \$pairs := tree \"weights/\" }} {{ end }}"

  # This is the destination path on disk where the source template will render.
  # If the parent directories do not exist, consul-template will attempt to
  # create them, unless create_dest_dirs is false.
  destination = "/tmp/mock_template.txt"

  # This is the optional command to run when the template is rendered. 
  # The command will only run if the resulting template changes.
  command     = "kill -1 \`cat /tmp/consul-template.pid\`"
}
EOF
'

_STAT="$?"

if [ "${_STAT}" -ne 0 ];  then
  log_err "Error creating consul-template configuration file."
  exit 254
fi

md_log '
Copy the configuration file on the `hashicups-nginx-0` node.'

_RUN_CMD 'scp -r -i '${SSH_CERT}' /home/'${username}'/assets/scenario/conf/hashicups-nginx-0/consul_template_weights.hcl '${username}'@hashicups-nginx-0:/home/'${username}'/consul_template_weights.hcl'

_STAT="$?"

if [ "${_STAT}" -ne 0 ];  then
  log_err "Error copying configuration file to the remote node."
  exit 254
fi

md_log "
The remaining part of the configuration will be executed directly on the hashicups-nginx-0 node."

_CONNECT_TO hashicups-nginx-0

md_log "
Verify the configuration file for consul-template got correctly copied on the node."

_RUN_CMD -r hashicups-nginx-0 -o hcl "cat /home/'${username}'/consul_template_weights.hcl"

_STAT="$?"

if [ "${_STAT}" -ne 0 ];  then
  log_err "Error. Configuration file not found on the remote node."
  exit 254
fi


md_log "
Create a consul-template template to replace the configuration file and include multiple instances of the services."

_RUN_CMD -r hashicups-nginx-0 'tee /home/'${username}'/nginx-upstreams-weights.tpl > /dev/null << EOF
upstream frontend_upstream {

	{{- range service "hashicups-frontend"}}
		server {{.Address}}:{{.Port}} {{ \$node := .Node -}} weight={{ keyOrDefault (print "weights/" \$node) "1" }};
	{{- end}}
}

upstream api_upstream {
  {{ range service "hashicups-api" -}}
  server {{ .Address }}:{{ .Port }};
  {{ end }}
}
EOF
'

_STAT="$?"

if [ "${_STAT}" -ne 0 ];  then
  log_err "Error creating configuration file."
  exit 254
fi

###  H3 ------------------------------------------------------------------------
md_log "
### Restart consul-templete to use new configuration"
# ------------------------------------------------------------------------------


_RUN_CMD -r hashicups-nginx-0 'kill -9 `cat /tmp/consul-template.pid`'

_STAT="$?"

if [ "${_STAT}" -ne 0 ];  then
  log_err "Error stopping consul template."
  exit 254
fi

md_log "
Start consul-template with the new configuration file.
"

_RUN_CMD -r hashicups-nginx-0 -o log "consul-template -config=consul_template_weights.hcl > /tmp/logs/consul-template.log  2>&1 &"

_STAT="$?"

if [ "${_STAT}" -ne 0 ];  then
  log_err "Error. consul-template start error."
  exit 254
fi

md_log "
The process is started in the background, you can check the logs for the process using the log file specified in the configuration.
"

md_log "
Verify that the configuration file got generated correctly.
"

_RUN_CMD -r hashicups-nginx-0 -o log "cat ${NGINX_CONF_PATH}/def_upstreams.conf"

_STAT="$?"

if [ "${_STAT}" -ne 0 ];  then
  log_err "Error. NGINX configuration file not found."
  exit 254
fi


md_log "
Verify that the configuration changes dynamically with the KV content.
"

_RUN_CMD 'consul kv put weights/hashicups-frontend-1 2'

_STAT="$?"

if [ "${_STAT}" -ne 0 ];  then
  log_err "Error adding key in Consul KV."
  exit 254
fi

sleep 5

_RUN_CMD -r hashicups-nginx-0 -o log "cat ${NGINX_CONF_PATH}/def_upstreams.conf"

_STAT="$?"

if [ "${_STAT}" -ne 0 ];  then
  log_err "Error. NGINX configuration file not found."
  exit 254
fi


_RUN_CMD 'consul kv delete weights/hashicups-frontend-1'

_STAT="$?"

if [ "${_STAT}" -ne 0 ];  then
  log_err "Error adding key in Consul KV."
  exit 254
fi

sleep 5

_RUN_CMD -r hashicups-nginx-0 -o log "cat ${NGINX_CONF_PATH}/def_upstreams.conf"

_STAT="$?"

if [ "${_STAT}" -ne 0 ];  then
  log_err "Error. NGINX configuration file not found."
  exit 254
fi


## =============================================================================
## =============================================================================
## =============================================================================
## =============================================================================
## =============================================================================
## =============================================================================
## =============================================================================

## consul-template -config=consul_template.hcl -once -dry

md_log '
 - [Load balancing services in Consul service mesh with Envoy](/consul/tutorials/developer-mesh/load-balancing-envoy)
 - [Deploy seamless canary deployments with service splitters](/consul/tutorials/developer-mesh/service-splitters-canary-deployment)
'

