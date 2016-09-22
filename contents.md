## Kubernetes Cluster Operations at DigitalOcean
<!-- .slide: data-background="#0080FF" -->
Dan Norris

@protochron


## Kubernetes
* Container orchestration by Google
* Makes running Docker containers simple at scale
* [kubernetes.io](kubernetes.io)
* TODO: insert image

Note:
Here's an example of some notes


## Kubernetes Architecture
* TODO: insert diagram
* (highlight different componens)

## Kubernetes Control Plane
* apiserver
* kube-controller-manager
* kube-scheduler


## Control Plane HA
* Run all components on same node
* Multiple nodes for redundancy
* Leader-election for services that keep track of state


## Kubernetes State
* Stored in etcd
* Requires a different method of updates than stateless nodes


## Cluster Operations
* Add new nodes
* Remove old nodes
* Update nodes

