# GCP Terraform Demo

## Overview
This project provisions a cloud infrastructure environment on Google Cloud Platform using Terraform. I built it over a weekend to get hands-on experience with infrastructure as code and GCP core services — coming from an AWS background, I wanted to see how the two platforms compare in practice.

The codebase is organized into separate files by responsibility — networking, compute, storage, and IAM each live in their own file. This makes it easier to navigate, edit, and extend without digging through one large configuration file.

## Architecture

### `main.tf`
The entry point for the configuration. Sets up the Google Cloud provider and configures a GCS remote backend so the Terraform state file lives in Cloud Storage rather than on my local machine. This is important in team environments where multiple engineers need access to the same state.

### `compute.tf`
Where the VM lives. I used an `e2-micro` instance — Google's current general purpose machine type. The VM is tagged `web` and `dev` which controls which firewall rules apply to it. I also reserved a static external IP so the public address doesn't change every time the VM restarts, which would otherwise break SSH access. The VM runs under a dedicated service account rather than using broad default credentials.

### `network.tf`
Defines the VPC network and two firewall rules. SSH is locked down to a single IP address — supplied through a variable so it never gets hardcoded into the repo. HTTP and HTTPS traffic is open to the internet but only applies to VMs tagged `web`.

### `storage.tf`
Provisions a Cloud Storage bucket with versioning enabled so older versions of files are retained for recovery and compliance. Two lifecycle rules keep things tidy — one automatically cleans up old object versions when there are more than three newer ones, and another aborts incomplete multipart uploads after 24 hours so failed uploads don't quietly accumulate storage costs.

### `iam.tf`
Creates a dedicated service account for the VM and grants it read-only access to Cloud Storage using `roles/storage.objectViewer`. The VM can read from the bucket but can't write, delete, or touch anything else in the project. Least privilege in practice.

### `apis.tf`
Enables the Compute, Storage, and IAM APIs so the config is fully self-contained. Without this, running `terraform apply` against a fresh GCP project would fail with API disabled errors. Each downstream resource uses `depends_on` to ensure the APIs are enabled before Terraform tries to create anything that needs them.

### `variables.tf`
Declares input variables for project ID, region, zone, and allowed SSH IP. Actual values live in `terraform.tfvars` which is excluded from version control.

### `outputs.tf`
Prints useful values to the terminal after apply — public IP for SSH access, internal IP, and the storage bucket name.

## Security Decisions

Security was a deliberate focus throughout this project rather than an afterthought:

**Least privilege networking** — SSH is restricted to a single IP using `/32` CIDR notation. The entire internet is blocked from port 22. HTTP traffic is scoped to tagged VMs only — not the whole network.

**Least privilege IAM** — the VM's service account only has `roles/storage.objectViewer`. It can read from the bucket and nothing else. No broad editor or owner roles.

**Custom VPC** — everything runs inside an explicitly defined VPC. GCP's default network has permissive firewall rules and no intentional segmentation — I didn't want to rely on defaults I didn't control.

**Dynamic SSH key injection** — the SSH public key is read from the local filesystem at apply time using `file()`. No credentials are hardcoded in the config or pushed to GitHub.

**Uniform bucket level access** — individual objects in the bucket can't have their own public permissions. All access goes through IAM.

**Data protection** — `force_destroy = false` on the bucket means Terraform will refuse to delete it if there are objects inside. I hit this error during testing and it worked exactly as intended.

**Auditable infrastructure** — every resource is labeled with `managed_by = terraform` so it's immediately clear which resources are managed as code versus created manually. Important for compliance audits.

**Remote state** — state is stored in a private GCS bucket, not on my laptop. State files contain sensitive resource details and shouldn't live on individual machines or get committed to version control.

## Prerequisites

- **Terraform** (v1.0+) — [Install guide](https://developer.hashicorp.com/terraform/install)
- **Google Cloud SDK** — [Install guide](https://cloud.google.com/sdk/docs/install)
- **A GCP account** with billing enabled and a project created
- **An SSH key pair** — generate with `ssh-keygen -t rsa -b 4096`

### Authentication
```bash
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
```

### Configuration
Create a `terraform.tfvars` file in the project root:
```hcl
project        = "your-gcp-project-id"
allowed_ssh_ip = "your-public-ip"
```

> Your public IP can be found by running `curl -4 ifconfig.me`

> `terraform.tfvars` is excluded from version control via `.gitignore` — your project ID and IP address never get pushed to the repository.

## Usage

### Deploy
```bash
# Initialize Terraform and configure the remote backend
terraform init

# Validate the configuration
terraform validate

# Preview what will be created
terraform plan

# Deploy to GCP
terraform apply
```

Type `yes` when prompted.

### Access the VM
```bash
ssh -i ~/.ssh/id_rsa YOUR_USERNAME@$(terraform output -raw public_ip)
```

### Destroy
```bash
terraform destroy
```

> The storage bucket must be empty before destroy will complete. Delete any objects first:
> ```bash
> gcloud storage rm gs://BUCKET_NAME/** --project=YOUR_PROJECT_ID
> ```

## What I'd Add in Production

This was built as a demo so some corners were cut intentionally. Here's what a production version would look like:

**No public IP on the VM** — right now the VM has a public IP for convenience. In a real environment it would be private only, with access through a bastion host or Google's IAP tunnel so there's no direct internet exposure.

**Bastion host** — one hardened jump server that everyone SSHs through. Shrinks the attack surface to a single controlled entry point.

**Cloud SQL** — a managed database in a private subnet with no public IP, automated backups, and connection logging for audit trails.

**VPC flow logs** — captures network traffic metadata across the VPC. Essential for security monitoring and ATO compliance documentation.

**Cloud Logging and Monitoring** — alerts for failed SSH attempts, unusual API calls, resource utilization spikes. You need visibility into what's happening in production.

**OS Login** — ties SSH access to IAM roles and Google identities instead of managing individual SSH key files. Access can be granted and revoked centrally.

**Customer Managed Encryption Keys (CMEK)** — for IL4/IL5 federal workloads, default GCP encryption may not meet compliance requirements. CMEK gives the customer full control over their encryption keys.

**CI/CD pipeline** — in production, Terraform never runs from someone's laptop. Changes go through pull requests, `terraform plan` runs automatically, a reviewer approves, and `terraform apply` runs through Cloud Build or GitHub Actions.

**Assured Workloads** — GCP's compliance product for regulated and government workloads. Enforces FedRAMP and DoD IL4/IL5 requirements — directly relevant to federal client engagements.

## GCP to AWS Service Mapping

My cloud background is primarily AWS from working with the Daily Dispatch application at PLADcloud. Building this project meant mapping what I already knew to GCP equivalents. The architecture patterns are the same — the service names are just different.

| AWS | GCP | Purpose |
|---|---|---|
| EC2 | Compute Engine | Virtual machines |
| VPC | VPC | Private network isolation |
| Security Groups | Firewall Rules | Network traffic control |
| S3 | Cloud Storage | Object storage |
| RDS / Aurora | Cloud SQL | Managed relational database |
| ECS | GKE / Cloud Run | Container orchestration |
| ALB | Cloud Load Balancing | Traffic distribution |
| IAM Roles | IAM / Service Accounts | Identity and access management |
| CloudWatch | Cloud Logging & Monitoring | Observability and alerting |
| AWS Config | Security Command Center | Security posture management |
| CodePipeline | Cloud Build | CI/CD pipelines |
| Secrets Manager | Secret Manager | Secrets and credential storage |

The Daily Dispatch app at PLADcloud ran on ECS, Aurora, an ALB, and a VPC — the same architecture pattern as GKE, Cloud SQL, a Load Balancer, and a VPC in GCP. The concepts transferred directly, the syntax just needed to change.