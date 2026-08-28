# Spring PetClinic - Docker & Kubernetes Deployment

This project demonstrates how to containerize the Spring PetClinic
application with Docker and deploy it on Kubernetes.

The process covered in this project is:

``` text
GitHub Repository
       |
       v
Docker Build
       |
       +--> Clone source code
       |
       +--> Maven build
       |
       +--> Run tests
       |
       v
Docker Image
       |
       v
Kubernetes Deployment
       |
       +--> 2 Spring PetClinic Pods
       |
       v
Kubernetes Service
       |
       v
Port Forward
       |
       v
http://localhost:8080
```

## 1. Project Source

The application source code is taken from:

-   Repository: `https://github.com/ksnksatwik07/spring-petclinic`
-   Branch: `efficient-webjars`

The Docker build clones the repository directly from GitHub.

## 2. Prerequisites

Install/configure the following:

-   Docker Desktop
-   Kubernetes
-   kubectl
-   Git (optional for local source management)

Verify Docker:

``` powershell
docker version
```

Verify Kubernetes:

``` powershell
kubectl version --client
kubectl get nodes
```

The Kubernetes node should show `Ready`.

Example:

``` text
NAME                  STATUS   ROLES           AGE   VERSION
desktop-control-plane Ready    control-plane   ...   ...
```

## 3. Dockerfile

The project uses a multi-stage Docker build.

### Build stage

The build stage:

1.  Uses a Maven + Java 8 image.
2.  Installs Git.
3.  Clones the `efficient-webjars` branch.
4.  Runs Maven.
5.  Runs the project's tests.
6.  Creates the Spring Boot JAR.

### Runtime stage

The runtime stage:

1.  Uses a Java 8 JRE image.
2.  Copies the generated JAR from the build stage.
3.  Exposes port `8080`.
4.  Starts the Spring Boot application.

Use the following `Dockerfile`:

``` dockerfile
# ============================================================
# Stage 1: Clone + Build + Test
# ============================================================
FROM maven:3.8.6-openjdk-8 AS builder

WORKDIR /app

# Install Git
RUN apt-get update \
    && apt-get install -y git \
    && rm -rf /var/lib/apt/lists/*

# Clone the efficient-webjars branch
RUN git clone \
    --branch efficient-webjars \
    --depth 1 \
    https://github.com/ksnksatwik07/spring-petclinic.git .

# Build and run tests
RUN mvn clean package


# ============================================================
# Stage 2: Runtime
# ============================================================
FROM eclipse-temurin:8-jre

WORKDIR /app

# Copy Spring Boot JAR from build stage
COPY --from=builder /app/target/*.jar app.jar

# Spring Boot port
EXPOSE 8080

# Start application
ENTRYPOINT ["java", "-jar", "app.jar"]
```

### Important Maven note

Because the Docker image already provides the Maven executable, use:

``` dockerfile
RUN mvn clean package
```

Do not use:

``` dockerfile
RUN ./mvn clean package
```

`./mvn` does not exist in the Maven base image.

The build uses:

``` dockerfile
RUN mvn clean package
```

which also executes the tests as part of Maven's package lifecycle.

## 4. Build the Docker Image

From the directory containing the Dockerfile:

``` powershell
docker build --no-cache -t spring-petclinic:latest .
```

The build process is:

``` text
Docker
  |
  +--> Clone GitHub repository
  |
  +--> Maven clean
  |
  +--> Compile
  |
  +--> Run tests
  |
  +--> Package JAR
  |
  +--> Create runtime image
```

Verify the image:

``` powershell
docker images spring-petclinic
```

## 5. Kubernetes Configuration

Create the following directory:

``` text
k8s/
├── deployment.yaml
└── service.yaml
```

## 6. Kubernetes Deployment

Create `k8s/deployment.yaml`:

``` yaml
apiVersion: apps/v1
kind: Deployment

metadata:
  name: spring-petclinic

spec:
  replicas: 2

  selector:
    matchLabels:
      app: spring-petclinic

  template:
    metadata:
      labels:
        app: spring-petclinic

    spec:
      containers:
        - name: spring-petclinic

          image: spring-petclinic:latest

          imagePullPolicy: IfNotPresent

          ports:
            - name: http
              containerPort: 8080
              protocol: TCP

          env:
            - name: SERVER_ADDRESS
              value: "0.0.0.0"

            - name: SERVER_PORT
              value: "8080"

          resources:
            requests:
              cpu: "250m"
              memory: "256Mi"

            limits:
              cpu: "500m"
              memory: "512Mi"
```

### Deployment explanation

The Deployment creates two replicas:

``` yaml
replicas: 2
```

Each Pod runs the Spring PetClinic container.

The labels are important:

``` yaml
labels:
  app: spring-petclinic
```

The Service uses the same label to find the Pods.

Spring Boot is configured to listen on all network interfaces:

``` yaml
SERVER_ADDRESS=0.0.0.0
```

and port:

``` yaml
SERVER_PORT=8080
```

## 7. Kubernetes Service

Create `k8s/service.yaml`:

``` yaml
apiVersion: v1
kind: Service

metadata:
  name: spring-petclinic

spec:
  type: NodePort

  selector:
    app: spring-petclinic

  ports:
    - name: http
      protocol: TCP
      port: 80
      targetPort: 8080
```

The Service maps:

``` text
Service port 80
      |
      v
Pod port 8080
```

The Service selector:

``` yaml
selector:
  app: spring-petclinic
```

must match the Pod label:

``` yaml
labels:
  app: spring-petclinic
```

If these do not match, the Service will have no endpoints.

## 8. Deploy to Kubernetes

First, verify Kubernetes:

``` powershell
kubectl get nodes
```

Apply the Deployment:

``` powershell
kubectl apply -f k8s/deployment.yaml
```

Apply the Service:

``` powershell
kubectl apply -f k8s/service.yaml
```

Or apply both:

``` powershell
kubectl apply -f k8s/
```

## 9. Verify the Deployment

Check the Deployment:

``` powershell
kubectl get deployment spring-petclinic
```

Expected:

``` text
NAME               READY   UP-TO-DATE   AVAILABLE
spring-petclinic   2/2     2            2
```

Check the Pods:

``` powershell
kubectl get pods
```

Expected:

``` text
NAME                                READY   STATUS
spring-petclinic-xxxxxxxxxx-xxxxx   1/1     Running
spring-petclinic-xxxxxxxxxx-yyyyy   1/1     Running
```

The Pods may initially show `0/1 Running` while Spring Boot is starting.
Wait until they become `1/1 Running`.

## 10. Check Pod Labels

Run:

``` powershell
kubectl get pods --show-labels
```

The Pods should contain:

``` text
app=spring-petclinic
```

This label is required by the Service selector.

## 11. Check the Service

Run:

``` powershell
kubectl get service spring-petclinic
```

Example:

``` text
NAME               TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)
spring-petclinic   NodePort   10.x.x.x        <none>        80:32xxx/TCP
```

## 12. Check Service Endpoints

Run:

``` powershell
kubectl get endpoints spring-petclinic
```

Expected:

``` text
NAME               ENDPOINTS
spring-petclinic   10.x.x.x:8080,10.x.x.x:8080
```

If the result shows:

``` text
<none>
```

check:

``` powershell
kubectl get pods --show-labels
```

and make sure the Pod labels match the Service selector.

## 13. Check Application Logs

Check the Spring Boot logs:

``` powershell
kubectl logs deployment/spring-petclinic
```

The application should show messages similar to:

``` text
Tomcat started on port(s): 8080 (http)
Started PetClinicApplication
```

This confirms that Spring Boot is listening on port `8080`.

To view a specific Pod:

``` powershell
kubectl get pods
```

Then:

``` powershell
kubectl logs <POD_NAME>
```

Example:

``` powershell
kubectl logs spring-petclinic-xxxxxxxxxx-xxxxx
```

## 14. Test the Application Inside a Pod

Get a Pod name:

``` powershell
kubectl get pods
```

Open a shell:

``` powershell
kubectl exec -it <POD_NAME> -- sh
```

Inside the container:

``` sh
wget -qO- http://localhost:8080
```

Then exit:

``` sh
exit
```

This verifies that the application is listening on port `8080` inside
the container.

## 15. Access the Application Using Port Forwarding

Use the Kubernetes Service:

``` powershell
kubectl port-forward service/spring-petclinic 8080:80
```

Expected:

``` text
Forwarding from 127.0.0.1:8080 -> 8080
Forwarding from [::1]:8080 -> 8080
```

The port-forward command is supposed to remain running. It is
maintaining the connection between the local machine and Kubernetes.

Do not close that terminal while using the application.

Open a browser:

``` text
http://localhost:8080
```

## 16. Troubleshooting

### Docker daemon error

If you see:

``` text
failed to connect to the docker API
```

make sure Docker Desktop is running.

Then verify:

``` powershell
docker version
```

### Dockerfile not found

If you see:

``` text
failed to read dockerfile
open Dockerfile: no such file or directory
```

make sure you are running the build from the directory containing the
Dockerfile:

``` powershell
dir
```

Then:

``` powershell
docker build -t spring-petclinic:latest .
```

### Maven command not found

Use:

``` dockerfile
RUN mvn clean package
```

not:

``` dockerfile
RUN ./mvn clean package
```

### Kubernetes Pods are `0/1`

Check:

``` powershell
kubectl get pods
```

Then:

``` powershell
kubectl logs deployment/spring-petclinic
```

Spring Boot may simply still be starting. Wait until:

``` text
1/1 Running
```

### Service has no endpoints

Check:

``` powershell
kubectl get endpoints spring-petclinic
```

If it shows `<none>`, compare:

``` powershell
kubectl get pods --show-labels
```

with the Service selector:

``` yaml
selector:
  app: spring-petclinic
```

### Port forwarding gives connection refused

Check:

``` powershell
kubectl get pods
```

The Pods should be:

``` text
1/1 Running
```

Then check:

``` powershell
kubectl logs deployment/spring-petclinic
```

Look for:

``` text
Tomcat started on port(s): 8080
```

Also check:

``` powershell
kubectl get endpoints spring-petclinic
```

The endpoints should contain Pod IPs on port `8080`.

## 17. Useful Kubernetes Commands

Get all resources:

``` powershell
kubectl get all
```

Get Pods:

``` powershell
kubectl get pods
```

Get Pods with more information:

``` powershell
kubectl get pods -o wide
```

Get Services:

``` powershell
kubectl get services
```

Get Deployments:

``` powershell
kubectl get deployments
```

Describe a Pod:

``` powershell
kubectl describe pod <POD_NAME>
```

View logs:

``` powershell
kubectl logs <POD_NAME>
```

Follow logs:

``` powershell
kubectl logs -f <POD_NAME>
```

View Deployment details:

``` powershell
kubectl describe deployment spring-petclinic
```

Scale the application:

``` powershell
kubectl scale deployment spring-petclinic --replicas=5
```

Check the result:

``` powershell
kubectl get pods
```

Return to two replicas:

``` powershell
kubectl scale deployment spring-petclinic --replicas=2
```

## 18. Clean Up Kubernetes Resources

Delete the application:

``` powershell
kubectl delete -f k8s/
```

Or delete individually:

``` powershell
kubectl delete deployment spring-petclinic
kubectl delete service spring-petclinic
```

## 19. Current Architecture

The current setup is:

``` text
                         GitHub
                           |
                           | git clone
                           v
                    Maven Build + Test
                           |
                           v
                  Docker Image
              spring-petclinic:latest
                           |
                           v
                    Kubernetes
                           |
                 +---------+---------+
                 |                   |
                 v                   v
              Pod 1               Pod 2
           Spring Boot          Spring Boot
             :8080                :8080
                 |                   |
                 +---------+---------+
                           |
                           v
                    Kubernetes
                      Service
                        :80
                           |
                           v
                    Port Forward
                     localhost:8080
                           |
                           v
                    Spring PetClinic
```

## 20. Current Project Status

The following has been completed:

-   [x] Spring PetClinic source cloned from GitHub
-   [x] Docker multi-stage build created
-   [x] Maven build configured
-   [x] Tests executed during Docker build
-   [x] Docker image created
-   [x] Kubernetes cluster verified
-   [x] Kubernetes Deployment created
-   [x] Two application replicas deployed
-   [x] Kubernetes Service created
-   [x] Service endpoints verified
-   [x] Spring Boot application verified on port 8080
-   [x] Kubernetes port forwarding configured
-   [x] Application accessed through `localhost:8080`

## 21. Future Improvements

The current PetClinic deployment is suitable for learning Docker and
Kubernetes fundamentals. The next improvements can include:

1.  Deploy PostgreSQL in Kubernetes.
2.  Use a PersistentVolume and PersistentVolumeClaim for database
    storage.
3.  Store database credentials in a Kubernetes Secret.
4.  Use ConfigMaps for application configuration.
5.  Add readiness and liveness probes after establishing the correct
    application startup behavior.
6.  Add an Ingress instead of relying on port forwarding.
7.  Add Horizontal Pod Autoscaling.
8.  Configure rolling updates and rollback.
9.  Add Docker image publishing to a container registry.
10. Create a GitHub Actions CI/CD pipeline.
11. Separate development and production Kubernetes configurations.

## 22. End-to-End Command Summary

Build the image:

``` powershell
docker build --no-cache -t spring-petclinic:latest .
```

Check Kubernetes:

``` powershell
kubectl get nodes
```

Deploy:

``` powershell
kubectl apply -f k8s/
```

Check Pods:

``` powershell
kubectl get pods
```

Check Deployment:

``` powershell
kubectl get deployment spring-petclinic
```

Check Service:

``` powershell
kubectl get service spring-petclinic
```

Check endpoints:

``` powershell
kubectl get endpoints spring-petclinic
```

Check logs:

``` powershell
kubectl logs deployment/spring-petclinic
```

Access the application:

``` powershell
kubectl port-forward service/spring-petclinic 8080:80
```

Then open:

``` text
http://localhost:8080
```

------------------------------------------------------------------------

## Conclusion

This project demonstrates a complete basic containerization and
Kubernetes deployment workflow for Spring PetClinic:

**GitHub → Maven → Tests → Docker → Kubernetes Deployment → Pods →
Service → Port Forwarding → Application**

The deployment currently runs two Spring PetClinic replicas in
Kubernetes. For a more production-oriented architecture, the next major
step is to externalize the database using PostgreSQL with Kubernetes
persistent storage and configuration management.
