## Kubernetes Cluster Operations at DigitalOcean
<!-- .slide: data-background="#0080FF" -->
Dan Norris

@protochron


## Kubernetes
<!-- .slide: data-transition="fade-out" -->
* Open source framework for running applications
* Makes running containers simple at scale
* [kubernetes.io](kubernetes.io)

Note:
Kubernetes is an open-source platform for automating deployment,
scaling, and operations of application containers across clusters of hosts.


<!-- .slide: data-background-image="/assets/architecture.png" data-background-size="90% 90%" data-transition="fade-out" -->


## Kubernetes Control Plane
* apiserver
* kube-controller-manager
* kube-scheduler


## Control Plane HA
* Run all components on same node
* Multiple nodes for redundancy
* Leader-election for services that keep track of state
* State is stored in etcd


## Kubernetes Resources
* [The Children's Illustrated Guide to Kubernetes](https://deis.com/blog/2016/kubernetes-illustrated-guide/)
* [Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way)
* [Kubernetes Documentation](http://kubernetes.io/docs/)


## Kubernetes at DigitalOcean
<!-- .slide: data-background="#0080FF" -->


## DigitalOcean Control Center (DOCC)
* Internal development platform that is geared toward simplifying application deployment
* Kubernetes provides the backbone
* Adds DO application best practices using a custom JSON manifest
  * alerting
  * service discovery
  * logging
  * metrics


<!-- .slide: data-background-image="/assets/map/map.png" data-background-size="100% auto" -->


## Bootstrapping a Region
* 5 etcd servers
* 3 control plane servers (apiserver, controller-manager, kube-scheduler)
* 3+ kubelets


## Math
* (5 + 3 + 3) \* 14 = 154 droplets (!)  <!-- .element: class="fragment" -->
* Add kubelets as needed as new services spin up or are migrated <!-- .element: class="fragment" -->


## How do you manage so many droplets?!
<!-- .slide: data-background="#0080FF" data-foreground="#000" data-transition="fade-out" -->


## The old way
* Statically allocate droplets (doctl or API) <!-- .element: class="fragment" -->
* Provision using Chef <!-- .element: class="fragment" -->
* Works great for small services, falls apart when launching 100s of droplets <!-- .element: class="fragment" -->


![Terraform](/assets/readme.png)
<!-- .slide: data-background="#000" data-transition="fade-out" -->


## Terraform
<!-- .slide: data-transition="fade-out" -->
  > Terraform provides a common configuration to launch infrastructure — from
  > physical and virtual servers to email and DNS providers. Once launched,
  > Terraform safely and efficiently changes infrastructure as the
  > configuration is evolved.

Condense provisioning and maintenance into a single tool


## Terraform Modules
>Modules in Terraform are self-contained packages of Terraform configurations
>that are managed as a group. Modules are used to create reusable components in
>Terraform as well as for basic code organization.

* Droplet
* etcd
* Kubernetes


## Droplet Module
Provides common configuration for launching droplets and provisioning using Chef
<pre><code data-trim data-noescape>
.
├── droplet
│   ├── create_token.sh
│   ├── main.tf
│   ├── outputs.tf
│   └── variables.tf
</code></pre>


## Droplet Module
### variables.tf
<pre><code data-trim data-noescape>
variable droplet_count {
  description = "Number of droplets to launch"
  default     = 1
}

variable droplet_region {
  description = "Region to launch in"
}

variable droplet_image {
  description = "Image to boot"
}

variable droplet_size {
  description = "Size of the droplet"
}

variable droplet_chef_environment {
  description = "Chef environment to apply"
  default     = "production"
}

variable droplet_chef_url {
  description = "URL of the Chef server"
}

variable droplet_chef_version {
  description = "Version of Chef to install on the droplet"
}

variable droplet_chef_roles {
  description = "A comma-delimited list of Chef roles to apply to the droplet"
  default     = ""
}

variable droplet_chef_validation_key {
  description = "The key to use to authenticate against the Chef server for the first run"
}

variable droplet_chef_user_name {
  description = "The username associated with the chef_validation_key"
}

variable droplet_name {
  description = "The name to apply to the droplets"
}

variable droplet_cluster_name {
  description = "The cluster to generate a certificate for"
}

variable droplet_vault_role {
  description = "The type of certificate to provision"
}

variable droplet_ssh_key_fingerprint {
  description = "The fingerprint of the ssh key to use"
}

variable droplet_ssh_private_key {
  description = "The private key to use when ssh'ing to the droplet"
}

variable droplet_api_token {
  description = "The digitalocean API token to use to create droplets"
}
</code></pre>


## Droplet Module
### main.tf
<pre><code data-trim data-noescape>
provider "digitalocean" {
    token = "${var.droplet_api_token}"
}

resource digitalocean_droplet "droplet" {
  count                 = "${var.droplet_count}"
  image                 = "${var.droplet_image}"
  region                = "${var.droplet_region}"
  size                  = "${var.droplet_size}"
  name                  = "${format("${var.droplet_name}%02d.%s", count.index + 1, lookup(var.droplet_regions, var.droplet_region))}"

  ssh_keys = ["${var.droplet_ssh_key_fingerprint}"]

  provisioner "remote-exec" {
    inline = [
      "mkdir -p /opt/vault_tokens/",
      "echo '$CHEF_URL' >> /etc/hosts",
    ]
  }

  provisioner "local-exec" {
    command = "${path.module}/create_token.sh ${var.droplet_cluster_name} ${var.droplet_vault_role} ${format("${var.droplet_name}%02d.%s", count.index + 1, lookup(var.droplet_regions, var.droplet_region))}"
  }

  provisioner "file" {
    source      = "/tmp/${format("${var.droplet_name}%02d.%s", count.index + 1, lookup(var.droplet_regions, var.droplet_region))}"
    destination = "/opt/vault_tokens/token"
  }

  provisioner "chef" {
    environment            = "${var.droplet_chef_environment}"
    attributes_json        = "{\"docc\": {\"cluster_name\": \"${var.droplet_cluster_name}\"}}"
    run_list               = ["${split(",", var.droplet_chef_roles)}"]
    node_name              = "${format("${var.droplet_name}%02d.%s", count.index + 1, lookup(var.droplet_regions, var.droplet_region))}"
    server_url             = "${var.droplet_chef_url}"
    version                = "${var.droplet_chef_version}"
    validation_client_name = "${var.droplet_chef_user_name}"
    validation_key         = "${var.droplet_chef_validation_key}"
    ssl_verify_mode        = ":verify_none"
  }

  connection {
    type  = "ssh"
    user  = "root"
    private_key = "${var.droplet_ssh_private_key}"
    agent = false
  }

  lifecycle = {
    create_before_destroy = true
  }
}
</code></pre>


## Droplet Module
### outputs.tf
<pre><code data-trim data-noescape>
output "ipv4s" {
  value = "${join(", ", digitalocean_droplet.droplet.*.ipv4_address)}"
}

output "server_names" {
  value = "${join(", ", digitalocean_droplet.droplet.*.name)}"
}
</code></pre>


## Vault tokens?
<!-- .slide: data-background="#0080FF" data-transition="fade-out" -->


![Vault](/assets/logo-big.png)
<!-- .slide: data-background="000" data-transition="fade-out" -->


## Vault + Kubernetes
<!-- .slide: data-transition="fade-out" -->
* Use Vault to store secrets
  * Vault acts as the CA to issue certs to the cluster
* [consul-template](https://github.com/hashicorp/consul-template)
  * renews token
  * replaces expired certificates


<!-- .slide: data-background-image="/assets/blog.png" data-background-size="100% auto" data-transition="fade-out" -->


## https://www.digitalocean.com/company/blog/vault-and-kubernetes/
<!-- .slide: data-transition="fade-out" -->


## etcd Module
<!-- .slide: data-transition="fade-out" -->
Creates an Etcd cluster
<pre><code data-trim data-noescape>
.
├── etcd
│   ├── flannel_init.sh
│   ├── main.tf
│   ├── outputs.tf
│   └── variables.tf
</code></pre>


## etcd Module
### variables.tf
<pre><code data-trim data-noescape>
variable "etcd_count" {
  description = "# of etcd servers"
}

variable "etcd_size" {
  description = "Size of the droplet"
}

variable "etcd_vault_role" {
  description = "Role to look up in Vault"
}

variable "etcd_flannel_subnet" {
  description = "A subnet CIDR to use for Flannel"
}

variable "etcd_flannel_vxlan_id" {
  description = "A VXLAN id to use for the Flannel overlay"
}

variable "etcd_chef_roles" {
  default = "role[delivery-kubernetes-etcd]"
}
</code></pre>


## etcd Module
### main.tf
<pre><code data-trim data-noescape>
module "etcd" {
  source                      = "../droplet"
  droplet_count               = "${var.etcd_count}"
  droplet_region              = "${var.region}"
  droplet_size                = "${var.etcd_size}"
  droplet_name                = "${var.cluster_name}-etcd"
  droplet_cluster_name        = "${var.cluster_name}"
  droplet_vault_role          = "${var.etcd_vault_role}"
  droplet_chef_user_name      = "${var.chef_user_name}"
  droplet_chef_roles          = "${var.etcd_chef_roles}"
  droplet_chef_validation_key = "${var.chef_validation_key}"
  droplet_ssh_key_fingerprint = "${var.ssh_key_fingerprint}"
  droplet_ssh_private_key     = "${var.droplet_ssh_private_key}"
  droplet_chef_environment    = "${var.chef_environment}"
  droplet_api_token           = "${var.droplet_api_token}"
}

resource "null_resource" "flannel" {
  triggers {
    droplets = "${module.etcd.server_names}"
  }

  connection {
    host    = "${element(split(",", module.etcd.ipv4s), 0)}"
    timeout = "30s"
    type  = "ssh"
    user  = "root"
    private_key = "${var.droplet_ssh_private_key}"
    agent = false
  }

  provisioner "file" {
    source      = "${path.module}/flannel_init.sh"
    destination = "/tmp/flannel_init.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/flannel_init.sh",
      "/tmp/flannel_init.sh ${element(split(",", module.etcd.server_names), 1)} ${var.etcd_flannel_subnet} ${var.etcd_flannel_vxlan_id}",
    ]
  }
}
</code></pre>


## Kubernetes Module
* Creates a kubernetes cluster
* Chef provides the metadata to find the correct etcd cluster
<pre><code data-trim data-noescape>
.
├── kubernetes
│   ├── main.tf
│   ├── outputs.tf
│   └── variables.tf
</code></pre>


## Kubernetes Module
### variables.tf
<pre><code data-trim data-noescape>
variable "apiserver_count" {
  description = "# of apiserver servers"
}

variable "apiserver_size" {
  description = "Size of the droplet"
}

variable "cluster_name" {
  description = "Name of the cluster"
}

variable "apiserver_vault_role" {
  description = "Role to look up in Vault"
}

variable "apiserver_chef_roles" {
  default = "role[delivery-kubernetes-apiserver],role[delivery-kubernetes-controller],role[delivery-kubernetes-scheduler]"
}

## Kubelet
variable "kubelet_count" {
  description = "# of kubelet servers"
}

variable "kubelet_size" {
  description = "Size of the droplet"
}

variable "kubelet_vault_role" {
  description = "Role to look up in Vault"
}

variable "kubelet_chef_roles" {
  default = "role[delivery-kubernetes-kubelet]"
}
</code></pre>


## Kubernetes Module
### main.tf
<pre><code>
module "apiserver" {
  source                      = "../droplet"
  droplet_count               = "${var.apiserver_count}"
  droplet_size                = "${var.apiserver_size}"
  droplet_region              = "${var.region}"
  droplet_name                = "${var.cluster_name}-apiserver"
  droplet_cluster_name        = "${var.cluster_name}"
  droplet_vault_role          = "${var.apiserver_vault_role}"
  droplet_chef_user_name      = "${var.chef_user_name}"
  droplet_chef_validation_key = "${var.chef_validation_key}"
  droplet_ssh_key_fingerprint = "${var.ssh_key_fingerprint}"
  droplet_ssh_private_key     = "${var.droplet_ssh_private_key}"
  droplet_chef_environment    = "${var.chef_environment}"
  droplet_chef_roles          = "${var.apiserver_chef_roles}"
  droplet_api_token           = "${var.droplet_api_token}"
}

module "kubelet" {
  source                      = "../droplet"
  droplet_count               = "${var.kubelet_count}"
  droplet_size                = "${var.kubelet_size}"
  droplet_region              = "${var.region}"
  droplet_name                = "${var.cluster_name}-kubelet"
  droplet_cluster_name        = "${var.cluster_name}"
  droplet_vault_role          = "${var.kubelet_vault_role}"
  droplet_chef_user_name      = "${var.chef_user_name}"
  droplet_chef_validation_key = "${var.chef_validation_key}"
  droplet_ssh_key_fingerprint = "${var.ssh_key_fingerprint}"
  droplet_ssh_private_key     = "${var.droplet_ssh_private_key}"
  droplet_chef_environment    = "${var.chef_environment}"
  droplet_chef_roles          = "${var.kubelet_chef_roles}"
  droplet_api_token           = "${var.droplet_api_token}"
}
</code></pre>


## Cluster Operations
* Create a cluster
* Add new nodes
* Update/replace nodes
* Remove old nodes


## Cluster Operations
### Create a cluster
* Get personal token from Vault (Github authentication)
* Export secrets to a <code>secrets.tfvars</code> file
* Create a top-level module + variables file
* <code>terraform apply</code>

<pre><code data-trim>
terraform apply -var-file=~/secrets.tfvars -var-file=terraform.tfvars
</code></pre>


## Cluster Operations
### Add Kubelet
* Edit <code>variables.tfvars</code>
<pre><code data-trim data-noescape>
  region = "nyc3"
  chef_environment = "production"

  etcd_count = "5"
  etcd_size = "2gb"
  etcd_flannel_vxlan_id = "1001"

  apiserver_count = "3"
  apiserver_size = "16gb"

  kubelet_count = "4" # was previously 3
  kubelet_size = "64gb"
</code></pre>

* apply <!-- .element: class="fragment" -->
<pre><code data-trim data-noescape>
terraform apply -var-file=~/secrets.tfvars -var-file=terraform.tfvars
</code></pre> <!-- .element: class="fragment" -->


## Cluster Operations
### Replace Kubelet
* Mark a kublet as needing to be replaced in Terraform
* Re-apply
<pre><code data-trim>
terraform taint -module=kubernetes.kubelet digitalocean_droplet.droplet.3
terraform apply -var-file=~/secrets.tfvars -var-file=terraform.tfvars
</code></pre> <!-- .element: class="fragment" -->


## Cluster Opertations
### Delete Kubelet
* Edit <code>variables.tfvars</code>
<pre><code data-trim data-noescape>
  region = "nyc3"
  chef_environment = "production"

  etcd_count = "5"
  etcd_size = "2gb"
  etcd_flannel_vxlan_id = "1001"

  apiserver_count = "3"
  apiserver_size = "16gb"

  kubelet_count = "3" # was previously 4
  kubelet_size = "64gb"
</code></pre>

* apply <!-- .element: class="fragment" -->
<pre><code data-trim data-noescape>
terraform apply -var-file=~/secrets.tfvars -var-file=terraform.tfvars
</code></pre> <!-- .element: class="fragment" -->


## Benefits
### State
* The state of the cluster is always known -- it's in version control!
  * Changes are reviewed
  * Terraform lets you preview changes
* Shared state


## Benefits
* One unified tool for all operations


## See it in Action
https://github.com/protochron/k8s-coreos-digitalocean
