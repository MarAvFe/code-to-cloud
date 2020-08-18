code-to-cloud-practice
===

This project is a small example of the following topics:

- golang web hello world
- containerization ([Docker](docker.io))
- orchestration ([Kubernetes](k8s.io))
- continuous integration [Github Actions](https://github.com/features/actions)
- infrastructure as code ([Terraform](terraform.io))
- cloud services [AWS](https://aws.amazon.com/)
- Kubernetes Chaos

Overview
---

This project deploys a simple webpage built into a docker image, replicated 5 times in a aws kubernetes cluster. The cluster and all resources are AWS based and created automatically with a terraform configuration. All of these actions are triggered by github actions CI/CD tool.

---

Usage
---

### Webserver - code

A simple Go webserver which prints server IP address to verify load balancing of infra. Along with a fun pong game.

1. Run app as `$ go run src/*.go`
2. Access the webserver on your browser as http://localhost:8080

> Note: Set a different port like `$ PORT=8999 go run src/*.go`

### Containerize

Build an [image for Docker Hub](https://hub.docker.com/repository/docker/hackerman/hello-pong/). With a lightweight alpine linux base.

1. Build the image with 

    ```bash
    $ cd src/
    $ docker build -t hackerman/hello-pong:v1.0 .
    $ # docker login
    $ docker push hackerman/hello-pong:v1.0
    ```

2. Run the image exposing container port 8080 on host 8082 like

    ```bash
    $ docker run -it -p 8082:8080 hackerman/hello-pong:v1.0
    2020/08/16 18:25:06 Server listening on port 8080
    ```

    then go ahead an browse to [http://localhost:8082](http://localhost:8082)

### Infrastructure

Terraform was used to create the following infrastructure in aws

```s
vpc: hello-pong-vpc
├── eks: hello-pong-eks-xxxx
│    ├── ec2: t2.micro
│    ├── ec2: t2.micro
│    └── ec2: t2.small
├── elb
├── subnets
├── security groups
└── s3: hello-pong-state-bucket
```

**Glossary:**

- vpc: virtual private cloud
- eks: elastic kubernetes service
- elastic compute cloud (k8s nodes)
- elb: elastic load balancer (through worker nodes)
- s3: simple storage service

### EKS

Elastic Kubernetes Service provides a master node to manage a k8s cluster, joining other ec2 nodes to create deployment pods as required.

1. [Create IAM role](https://docs.aws.amazon.com/eks/latest/userguide/service_IAM_role.html#create-service-role), also attach S3 permissions (AWSS3FullAccess)
2. Create a [new cluster](https://learn.hashicorp.com/tutorials/terraform/eks) with aws eks

The cluster includes: 

1. [Deployment](./k8s/deployment.yml): Creates 5 replicas of the webserver pod with "hello-pong" label
2. [Load balancer](./k8s/service.yml): Distribute requests among the 5 created pods

### Persistence

Create an S3 bucket. This is a manual step to avoid destruction of this resource on `$ terraform destroy`

```bash
$ aws s3 mb s3://hello-pong-state-bucket --region us-east-2
$ aws s3api put-bucket-versioning --bucket hello-pong-state-bucket --versioning-configuration Status=Enabled
```

Then add the following section into a .tf file 

```yml
terraform {
  ...

  backend "s3" {
    # bucket = "hello-pong-state-bucket"  # managed by tf init parameter
    # key    = "eks/terraform.tfstate"    # managed by tf init parameter
    region = "us-east-2"
  }
}
```

This enables S3 as terraform backend, where the infrastructure state will be saved (`terraform.tfstate`). State persistence enables the destruction of the infrastructure from a separate CI task. First time deployment pipeline is run, it creates the file. Every other time, it updates it's content. It's also read by the terraform destroy action.

---

Pipelines
---

### Job - docker-image-build

This job compiles new code, builds the docker image and pushes it into [Docker Hub](https://hub.docker.com/repository/docker/hackerman/hello-pong) if the event happened on a tagged commit (enabling image versioning: v1.1, 1.12).

### Job - provision-k8s-cluster

This job provisions all the aws infra required to run the eks cluster, and updates the pods with new versions of the software. The following actions are performed (roughly):

- **Checkout:** Get the code for webserver, deployments, infra updates
- **Configure AWS environment:** Setup aws-cli for the pipeline interactions
- **Setup Terraform:** Setup terraform command
- **Terraform fmt, init, validate, plan:** Verify the terraform configuration is set and sound
- **Terraform Apply:** Provision aws infra with terraform
- **Configure kubectl:** Get created cluster's credentials and configure kubectl for cluster management
- **K8s Deployment:** Create or update k8s pods as required

---

Main implementation issues
---

The following are issues that took a lot of time to solve:

### S3 bucket terraform configuration

This is more a hack than an issue. It'd be good to fix. For some reason, the bucket name and state file key were not read from terraform configuration (comented out in [./tf/versions.tf:6](./tf/versions.tf)).

Solved by using ["`--backend-config=`" flag](https://gitlab.com/arunalakmal/TCAWSKubeDeploy/-/blob/master/.gitlab-ci.yml#L30) on deploy pipeline.

### Cluster insufficient resources

After the first k8s deployment, the website was live under the elb public IP. However, the following error appeared in 5/6 pods that were expected to run:

```txt
0/3 nodes are available: 3 Insufficient cpu.
```

This first configuration included three t2.micro ec2 nodes. Using kubernetes-metrics-scaper, those nodes seemed very low on cpu consumption, which caused confusion; how can that be a cpu issue if cpu consumption seems to be very low? Each of the three nodes, was running 4 pods. Most of those were standard pods (I figure) required to join the node into the cluster and the metrics service.

 [This post](https://managedkube.com/kubernetes/k8sbot/troubleshooting/pending/pod/2019/02/22/pending-pod.html) was the only reference found to this problem. After that, I played a little bit with nodes sizes, concluding into a good fit of two t2.micro instances and one t2.small to run the 5 pods set on deployment

### Terraform source (`.tf`) folder name

The `tf/` folder was previously called `terraform/` to group every terraform configuration file ("`.tf`").

Once the project was pushed and the github actions started to run, the "Setup Terraform" [action](https://github.com/marketplace/actions/hashicorp-setup-terraform) would download terraform. When "`$ terraform init`" was run, the process printed 

>"Error: No configuration files"

Leading to solve the issue by setting the `working-directory` with a flag (` $ terraform init terraform/` ) and failing. Then setting the `working-directory` with the [`defaults` property](https://docs.github.com/en/actions/reference/workflow-syntax-for-github-actions#defaults) from github actions jobs. This would still not solve the problem.

After trying with renaming the folder to `tf/`, the issue disappeared. It seems the github action creates a collision with `terraform/` folder name. Unluckily, I couldn't find a source to confirm this but that was the observed behaviour.

### Terraform Wrapper (github action)

After creating all the infrastructure, github requires 2 terraform outputs to configure kubectl and deploy to k8s:

- cluster's name
- cluster's kubeconfig data (credentials)

The terraform cli behavior to read an output is the folowing:

```bash
$ terraform output cluster_name
hello-pong-eks-xxxx
```

But when running said command inside github actions, output received would be similar to

```bash
$ terraform output cluster_name
[command]/home/runner/work/_temp/a15b4c47-57cb-45cb-8187-bb37cde344e3/terraform-bin output kubectl_con
fig hello-pong-eks-xxxx ::debug::stdout: hello-pong-eks-xxxx ::debug::stderr: ::debug::exitcode: 0
```

After some hours of debugging, I learnt that Terraform setup github action [states](https://github.com/hashicorp/setup-terraform/#inputs):

> - `terraform_wrapper` - (optional) Whether or not to install a wrapper to wrap subsequent calls of the `terraform` binary and expose its STDOUT, STDERR, and exit code as outputs named `stdout`, `stderr`, and `exitcode` respectively. Defaults to `true`.

The unexpected output search brought no useful results on the internet, becoming a tough to debug issue. After some more debugging I found out that the format "`::debug::stdout: `" is a github actions standard or seems to be an under the hood debugging tool. At first, I wasn't even able to pin the issue to terraform, to github actions, to base64 shell tool (which [steebchen/kubectl](https://github.com/marketplace/actions/kubernetes-cli-kubectl) required)

The final solution was to simply disable the wrapper in the pipeline:

```yaml
steps:
- uses: hashicorp/setup-terraform@v1
  with:
    terraform_wrapper: false
```

### kubectl server not started in pipeline

Once the terraform, aws-cli, kubectl were all setup, it was time to deploy to k8s-cluster. It printed out a cryptic message of 

```
The connection to the server localhost:8080 was refused - did you specify the right host or port?
```

This was a very straightforward and quick issue to solve thanks to [this answer](https://stackoverflow.com/a/51122584) that stated:

> you need to specify kubeconfig for kubectl like this.
>
> `kubectl --kubeconfig .kube/config  get nodes`

---

## TODO

- [ ] Autoscaling
- [ ] Create IAM role with Terraform
- [ ] Create and destroy (somehow) S3 bucket with Terraform

# Credit and Sources

- **Pong game:** [https://gist.github.com/straker/81b59eecf70da93af396f963596dfdc5](https://gist.github.com/straker/81b59eecf70da93af396f963596dfdc5)
- **Host info and k8s** [https://github.com/christianhxc/intro-to-kubernetes](https://github.com/christianhxc/intro-to-kubernetes)
- **Docker image build and push:** [https://github.com/marketplace/actions/build-and-push-docker-images](https://github.com/marketplace/actions/build-and-push-docker-images)
- **K8s Chaos Github Action:** [https://github.com/marketplace/actions/kubernetes-chaos](https://github.com/marketplace/actions/kubernetes-chaos)
- **Terraform Github Action:** [https://github.com/marketplace/actions/hashicorp-setup-terraform](https://github.com/marketplace/actions/hashicorp-setup-terraform)
- **Terraform EKS Cluster:** [https://github.com/hashicorp/learn-terraform-provision-eks-cluster](https://github.com/hashicorp/learn-terraform-provision-eks-cluster)
- **Low CPU on workers issue:** [https://managedkube.com/kubernetes/k8sbot/troubleshooting/pending/pod/2019/02/22/pending-pod.html](https://managedkube.com/kubernetes/k8sbot/troubleshooting/pending/pod/2019/02/22/pending-pod.html)
- **Terraform init bucket config:** [https://github.com/ArunaLakmal/Terraform-Backend](https://github.com/ArunaLakmal/Terraform-Backend)
- **Github action kubectl server not started:** [https://stackoverflow.com/a/51122584](https://stackoverflow.com/a/51122584)
- **And lots of other lost links**