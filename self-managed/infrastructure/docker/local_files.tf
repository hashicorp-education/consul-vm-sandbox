resource "null_resource" "clean_local_files" {
  
  provisioner "local-exec" {
    # Bootstrap script called with private_ip of each node in the cluster
    command = "rm -rf ${path.module}/../../../var/assets/*"
  }

  provisioner "local-exec" {
    # Bootstrap script called with private_ip of each node in the cluster
    command = "rm -rf ${path.module}/../../../var/logs/*"
  }
}