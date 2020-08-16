code-to-cloud-practice
===

This project is a small example of the following topics:

- golang hello world
- containerization ([Docker](docker.io))
- orchestration ([Kubernetes](k8s.io))
- automated deployment ([Terraform](terraform.io))

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

Questions
---

---

# Credit

- **Pong game:** [https://gist.github.com/straker/81b59eecf70da93af396f963596dfdc5](https://gist.github.com/straker/81b59eecf70da93af396f963596dfdc5)
- **Host info and k8s** [https://github.com/christianhxc/intro-to-kubernetes](https://github.com/christianhxc/intro-to-kubernetes)