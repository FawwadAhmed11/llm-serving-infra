# AI Inference Infrastructure on AWS

Serving LLM inference at scale is an infrastructure problem as much as a 
modeling problem. Requests are latency-sensitive, GPU memory is the binding 
constraint, and load is unpredictable. This project provisions a 
production-grade inference serving stack on AWS that addresses all three — 
using Terraform for infrastructure, Kubernetes for orchestration, and vLLM 
(mocked for cost) as the inference server.

## Architecture

Traffic enters through an AWS Application Load Balancer in the public subnet 
and routes to a Kubernetes Service inside the cluster. The Service maintains 
a stable endpoint across pod restarts and distributes requests across all 
healthy vLLM replicas running in private subnets. Pods never have public IPs — 
outbound traffic routes through a NAT Gateway, keeping the compute layer 
fully isolated from the internet.

The EKS control plane communicates with worker nodes via AWS PrivateLink — 
a private tunnel between the AWS-managed control plane VPC and the cluster 
VPC, so API server traffic never traverses the public internet.

Worker nodes run in private subnets across two availability zones for 
fault tolerance. Subnets are tagged with Kubernetes discovery tags so EKS 
and Karpenter can identify public vs private subnets without hardcoded IDs — 
a pattern that makes the infrastructure reusable across environments.

## Infrastructure layer — Terraform

Two reusable modules, one environment:

**VPC module** provisions the full networking layer — VPC (10.0.0.0/16), 
public and private subnets across us-east-1a and us-east-1b, Internet Gateway 
for public subnet egress, NAT Gateway with Elastic IP for private subnet 
outbound traffic, and route tables wiring each subnet to the correct gateway. 
Subnets use for_each over CIDR lists — adding a third availability zone 
requires one line change, not a new resource block.

**EKS module** provisions the orchestration layer — the managed control plane, 
a managed node group (t3.medium for CPU, swappable to g5.xlarge for GPU), 
and two IAM roles. The cluster role grants the control plane permission to 
manage ENIs and load balancers inside the VPC. The node role grants worker 
nodes permission to register with the cluster, assign pod IPs via the VPC CNI 
plugin, and pull container images from ECR.

**Remote state** is stored in S3 with versioning and AES256 encryption. 
DynamoDB provides state locking — preventing concurrent applies from corrupting 
the state file. Dev and prod environments share the same bucket with isolated 
key paths.

## Application layer — Kubernetes

**Deployment** runs 2 replicas of the vLLM mock server — a Python HTTP server 
mimicking the OpenAI-compatible vLLM API. Resource requests (250m CPU, 256Mi 
RAM) give the scheduler enough signal to place pods correctly. Limits (500m CPU, 
512Mi RAM) prevent any single pod from starving others on the same node.

**Service** exposes the deployment on port 80 with a stable ClusterIP, 
forwarding to pod port 8000. Named ports allow Prometheus to discover scrape 
targets by name rather than number — decoupling the monitoring config from 
the pod implementation.

**HPA** scales replicas between 2 and 8 based on average CPU utilization 
across the pod fleet. At 70% threshold, new pods are added before the existing 
ones saturate. In production this would be replaced with custom metrics — 
KV cache utilization and queue depth — once Prometheus and the custom metrics 
adapter are wired in.

**Karpenter** provisions nodes on demand when pods are unschedulable. 
A NodePool defines the constraints — on-demand t3.medium or t3.large, 
across both AZs, with a 100 vCPU ceiling to bound cost. An EC2NodeClass 
wires Karpenter to the cluster's private subnets and security group using 
tag selectors — the same tags applied in the VPC module. When traffic drops, 
Karpenter consolidates underutilized nodes within 30 seconds.

**Prometheus + Grafana** are deployed via the kube-prometheus-stack Helm chart. 
Prometheus scrapes per-pod metrics every 15 seconds via a ServiceMonitor. 
Grafana provisions a vLLM inference dashboard via ConfigMap — surfacing 
requests per second, p99 latency, and pod CPU utilization. In production 
this dashboard would be extended with KV cache utilization, queue depth, 
and TTFT once vLLM's native metrics endpoint is wired in.

## GPU swap

The project runs on CPU nodes by default. To serve a real model:
1. Update node_instance_type to g5.xlarge in envs/dev/main.tf
2. Add nvidia.com/gpu: "1" to the deployment resource requests and limits
3. Replace the mock container with vllm/vllm-openai:latest
4. Pass --model and --tensor-parallel-size args to the vLLM server

All networking, autoscaling, and observability config remains unchanged.

## Project structure

terraform-aws-platform/
├── modules/
│   ├── vpc/          # VPC, subnets, IGW, NAT, route tables
│   └── eks/          # EKS cluster, node group, IAM roles
├── envs/
│   └── dev/          # Dev environment — wires vpc + eks modules
│       ├── main.tf
│       ├── backend.tf # S3 remote state + DynamoDB locking
│       └── outputs.tf
└── k8s/
    ├── vllm-mock/    # Deployment, Service, HPA, Karpenter
    └── prometheus/   # Helm install, ServiceMonitor, Grafana dashboard

## Deploy

# Initialize and apply
cd envs/dev
terraform init
terraform plan
terraform apply

# Configure kubectl
aws eks update-kubeconfig --name fawwad-cluster --region us-east-1

# Deploy Kubernetes manifests
kubectl apply -f k8s/vllm-mock/
bash k8s/prometheus/install.sh
kubectl apply -f k8s/prometheus/

# Destroy when done (avoid ongoing costs)
kubectl delete -f k8s/vllm-mock/
kubectl delete -f k8s/prometheus/
terraform destroy