code-to-cloud-practice
===

This project is a small example of the following topics:

- golang hello world
- containerization ([Docker](docker.io))
- orchestration ([Kubernetes](k8s.io))
- automated deployment ([Terraform](terraform.io))
- Kubernetes Chaos

Overview
---

Usage
---

### Webserver - code

1. Run app as `$ go run src/*.go`
2. Access the webserver on your browser as http://localhost:8080

> Note: You can set a different port like `$ PORT=8999 go run src/*.go`

### Container

1. Build the image with 

    ```bash
    $ cd src/
    $ docker build -t hackerman/hello-pong:v1.0 .
    $ #docker login
    $ docker push hackerman/hello-pong:v1.0
    ```

2. Run the image exposing port 8080 on 8082 like

    ```bash
    $ docker run -it -p 8082:8080 hackerman/hello-pong:v1.0
    2020/08/16 18:25:06 Server listening on port 8080
    ```

### EKS

1. [Create IAM role](https://docs.aws.amazon.com/eks/latest/userguide/service_IAM_role.html#create-service-role), also attach S3 permissions
2. Create a [new cluster](https://learn.hashicorp.com/tutorials/terraform/eks)

### Persistence

Create an S3 bucket 

`$ aws s3 mb s3://hello-pong-tf-bucket --region us-east-2`
`$ aws s3api put-bucket-versioning --bucket hello-pong-tf-bucket --versioning-configuration Status=Enabled`

Then add the following section into a .tf file 

```
terraform {
  ...

  backend "s3" {
    bucket = "hello-pong-state-bucket"
    key    = "eks/terraform.tfstate"
    region = "us-east-2"
  }
}
```

Just like that, you enable terraform state saving and can delete the server automatically.

Deploy Pipeline
---

### Job - docker-image-build

This job builds the docker image and pushes it into [Docker Hub](https://hub.docker.com/repository/docker/hackerman/hello-pong) if the event happened on a tagged commit.

### Job - provision-k8s-cluster

This job creates an eks cluster

> Note: DO NOT use the name "terraform" to name your terraform folder containing .tf files. It collides with the created binary to execute pipeline's processes and fails with no reasonable output: "Error: No configuration files", as if directory was empty or `working-directory` property was incorrectly set. Unluckily, I couldn't find a source to confirm this but that was the observed behaviour.

Questions
---

---

# Credit and Sources

- **Pong game:** [https://gist.github.com/straker/81b59eecf70da93af396f963596dfdc5](https://gist.github.com/straker/81b59eecf70da93af396f963596dfdc5)
- **Host info and k8s** [https://github.com/christianhxc/intro-to-kubernetes](https://github.com/christianhxc/intro-to-kubernetes)
- **Docker image build and push:** [https://github.com/marketplace/actions/build-and-push-docker-images](https://github.com/marketplace/actions/build-and-push-docker-images)
- **K8s Chaos Github Action:** [https://github.com/marketplace/actions/kubernetes-chaos](https://github.com/marketplace/actions/kubernetes-chaos)
- **Terraform Github Action:** [https://github.com/marketplace/actions/hashicorp-setup-terraform](https://github.com/marketplace/actions/hashicorp-setup-terraform)
- **Terraform EKS Cluster:** [https://github.com/hashicorp/learn-terraform-provision-eks-cluster](https://github.com/hashicorp/learn-terraform-provision-eks-cluster)
- **Low CPU on workers issue:** [https://managedkube.com/kubernetes/k8sbot/troubleshooting/pending/pod/2019/02/22/pending-pod.html](https://managedkube.com/kubernetes/k8sbot/troubleshooting/pending/pod/2019/02/22/pending-pod.html)
- **Terraform init bucket config:** [https://github.com/ArunaLakmal/Terraform-Backend](https://github.com/ArunaLakmal/Terraform-Backend)
