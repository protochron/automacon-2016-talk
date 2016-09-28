## Kubernetes Cluster Operations at DigitalOcean
Dan Norris

@protochron


## Kubernetes
<!-- .slide: data-transition="fade-out" -->
> Kubernetes is an open-source platform for automating deployment, scaling, and
> operations of application containers across clusters of hosts, providing
> container-centric infrastructure.

Note:
Kubernetes is an open-source platform for automating deployment,
scaling, and operations of application containers across clusters of hosts.


<!-- .slide: data-background-image="/assets/architecture.png" data-background-size="90% 90%" data-transition="fade-out" -->


## Etcd
<!-- .slide: data-background-image="/assets/etcd-glpyh-color.png" data-background-size="auto" -->
* Distributed key-value store
* Stores Kuberentes state


## Flannel
* Overlay network by CoreOS
* Gives a routable IP to each container


## Kubernetes at DigitalOcean


## DigitalOcean Control Center (DOCC)
* Internal runtime platform
* Kubernetes provides the backbone


## DOCC Features
* Adds DO application best practices using a custom JSON manifest
  * alerting
  * service discovery
  * logging
  * metrics
* Users submit jobs using an API that wraps Kubernetes


<!-- .slide: data-background-image="/assets/map/map.png" data-background-size="100% auto" -->


## Bootstrapping a Region
* 5 etcd servers
* 3 control plane servers (apiserver, controller-manager, kube-scheduler)
* 3+ kubelets


## Base Amount of Droplets
* 11 \* 14 = 154 droplets (!)  <!-- .element: class="fragment" -->
* Add kubelets as needed as new services spin up or are migrated <!-- .element: class="fragment" -->


## How do you manage so many droplets?!
<!-- .slide: data-transition="fade-out" -->


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

* Declarative infrastructure
* Benefit: combine provisioning and maintenance


## Terraform Modules
>Modules in Terraform are self-contained packages of Terraform configurations
>that are managed as a group. Modules are used to create reusable components in
>Terraform as well as for basic code organization.

* Droplet <!-- .element: class="fragment" -->
* etcd <!-- .element: class="fragment" -->
* Kubernetes <!-- .element: class="fragment" -->


## Droplet Module
Provides common configuration for launching droplets and provisioning using Chef
* Combines the launch and provision steps <!-- .element: class="fragment" -->

![Droplet](/assets/droplet.png) <!-- .element: class="fragment" -->


## Tokens?
<!-- .slide: data-transition="fade-out" -->


<!-- .slide: data-background-image="/assets/blog.png" data-background-size="100% auto" data-transition="fade-out" -->

Note:
Vault acts as a CA for Kubernetes. Means that we can fully secure the cluster automatically


## http://do.co/vault
<!-- .slide: data-transition="fade-out" -->


## etcd Module
<!-- .slide: data-transition="fade-out" -->
Creates an Etcd cluster
* Imports the droplet module

![Droplet](/assets/etcd.png) <!-- .element: class="fragment" -->


## Kubernetes Module
Creates a kubernetes cluster
* Also imports the droplet module
* Chef provides the metadata to find the correct etcd cluster

![Droplet](/assets/kubernetes.png) <!-- .element: class="fragment" -->


## Cluster Operations
<!-- .slide: data-transition="fade-out" -->


## Cluster Operations
* Create a cluster
* Add new nodes
* Update/replace nodes
* Remove old nodes


## Cluster Operations
### Create a cluster
* Export secrets to a <code>secrets.tfvars</code> file
* Create a top-level cluster module + variables file
* <code>terraform apply -var-file=~/secrets.tfvars -var-file=cluster.tfvars


## Cluster Operations
### Add Kubelet
* Edit <code>variables.tfvars</code>
<pre><code data-trim data-noescape>
  kubelet_count = "4" # was previously 3
</code></pre>
* <code data-trim data-noescape> terraform apply -var-file=~/secrets.tfvars -var-file=cluster.tfvars </code>


## Cluster Operations
### Replace Kubelet
* Mark a kubelet as needing to be replaced in Terraform
* Re-apply
<pre><code data-trim>
terraform taint -module=kubernetes.kubelet digitalocean_droplet.droplet.3
terraform apply -var-file=~/secrets.tfvars -var-file=cluster.tfvars
</code></pre> <!-- .element: class="fragment" -->


## Cluster Opertations
### Delete Kubelet
* Edit <code>variables.tfvars</code>
<pre><code data-trim data-noescape>
  kubelet_count = "3" # was previously 4
</code></pre> <!-- .element: class="fragment" -->
* terraform apply -var-file=~/secrets.tfvars -var-file=cluster.tfvars <!-- .element: class="fragment" -->
* Assumes that no jobs are running on the node <!-- .element: class="fragment" -->
* kubectl drain, kubectl delete node <!-- .element: class="fragment" -->


## Benefits
<!-- .slide: data-transition="fade-out"-->


## Benefits
### Cluster State
* Everything is in version control! <!-- .element: class="fragment" -->
* Changes are reviewed <!-- .element: class="fragment" -->
* Terraform lets you preview changes <!-- .element: class="fragment" -->


## Benefits
### Tooling
* One unified tool for all operations
* Take the **fear** out of making changes


## Recap
* Codifying infrastructure makes managing many Kubernetes clusters easier
* Terraform made cluster operations simple and predictable
* Vault secures the cluster automatically


## See it in Action
https://github.com/protochron/k8s-coreos-digitalocean


## Get the slides
docker pull protochron/automacon-2016


## Thanks for listening!

@protochron


## Resources
### Kubernetes
* [The Children's Illustrated Guide to Kubernetes](https://deis.com/blog/2016/kubernetes-illustrated-guide/)
* [Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way)
* [Kubernetes Documentation](http://kubernetes.io/docs/)


## Resources
### Terraform
