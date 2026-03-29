## Overview
This project provisions a cloud infrastructure environment on Google Cloud Platform using Terraform. I built it to demonstrate hands-on experience with infrastructure as code, GCP core services, and security best practices relevant to cloud engineering roles.

The codebase follows a modular file structure — separating networking, compute, storage, and IAM into their own files. Making each layer easy to understand, maintain, and extend independently.

## Architecture

The codebase is organized into separate files by responsibility:

### `main.tf`
Initializes the Google Cloud provider and configures the GCS remote backend for Terraform state storage. Remote state ensures the state file is accessible to all team members rather than living on a single local machine. Provider variables are referenced from `variables.tf` for cleaner configuration.

### `compute.tf`
Provisions the Compute Engine VM and reserves a static external IP address. The VM uses the `e2-micro` machine type — Google's current generation general purpose instance. Network tags (`web`, `dev`) control which firewall rules apply to the instance. Labels track environment, project, and provisioning method for cost attribution and auditing. The VM is attached to a dedicated service account and SSH access is configured dynamically by reading the public key from the local filesystem at apply time. A static external IP is reserved and attached to the VM ensuring a consistent public IP that survives restarts — preventing SSH firewall rules from breaking after a reboot.

### `network.tf`
Defines the VPC network and two firewall rules:
- **allow-ssh** — restricts SSH access to port 22 from a single IP address, implementing least privilege networking
- **allow-http** — allows HTTP/HTTPS traffic on ports 80 and 443 from the internet, scoped to VMs tagged `web`

### `storage.tf`
Provisions a Cloud Storage bucket with:
- **Versioning** — retains up to 3 versions of any object for compliance and recovery
- **Lifecycle rules** — automatically deletes versions beyond the 3 most recent and aborts incomplete multipart uploads after 24 hours to manage storage costs
- **Uniform bucket level access** — enforces IAM based access control across all objects

### `iam.tf`
Creates a dedicated service account for the VM and grants it `roles/storage.objectViewer` — read only access to Cloud Storage. This implements least privilege at the identity layer — the VM can read from the bucket but cannot write, delete, or modify bucket settings.

### `apis.tf`
Enables the required GCP APIs — Compute, Storage, and IAM — so the configuration is fully self contained. Any user can clone this repo and run `terraform apply` against a fresh GCP project without manually enabling APIs. Each resource that depends on an API uses `depends_on` to ensure correct provisioning order.

### `variables.tf`
Declares input variables for project ID, region, and zone. Values are supplied via `terraform.tfvars` which is excluded from version control to keep sensitive values out of the repository.

### `outputs.tf`
Surfaces key values after apply — public IP address for SSH access, internal IP, and storage bucket name for easy reference.

## Security Decisions

Several deliberate security decisions were made throughout this project:

**Least privilege networking** — SSH access is restricted to a single IP address using CIDR `/32` notation. Only the authorized machine can reach port 22 — the entire internet is blocked. HTTP traffic is scoped to VMs tagged `web` only.

**Least privilege IAM** — the VM runs under a dedicated service account granted only `roles/storage.objectViewer` — read only access to Cloud Storage. It cannot write, delete, or modify bucket settings or any other GCP resource.

**Custom VPC** — all resources run inside an explicitly defined VPC rather than the GCP default network. The default VPC has permissive firewall rules and no intentional segmentation — a custom VPC gives full control over every network decision.

**Dynamic SSH key injection** — the SSH public key is read dynamically from the local filesystem at apply time using Terraform's `file()` function. No credentials are hardcoded in the codebase or pushed to version control.

**Uniform bucket level access** — enforces IAM based access control across every object in the storage bucket. Individual objects cannot have their own public permissions — all access is controlled through IAM.

**Data protection** — `force_destroy = false` on the storage bucket prevents accidental deletion of data. Terraform will refuse to destroy the bucket if it contains objects.

**Auditable infrastructure** — all resources are labeled with `managed_by = terraform` making it immediately clear which resources are managed as code and which were created manually — important for compliance audits and ATO engagements.

**Remote state security** — Terraform state is stored in a private GCS bucket rather than locally. State files contain sensitive resource details and should never be committed to version control or stored on individual machines.

## Prerequisites

The following tools must be installed and configured before deploying this project:

- **Terraform** (v1.0+) — [Install guide](https://developer.hashicorp.com/terraform/install)
- **Google Cloud SDK** (gcloud CLI) — [Install guide](https://cloud.google.com/sdk/docs/install)
- **A GCP account** with billing enabled and a project created
- **An SSH key pair** — generate with `ssh-keygen -t rsa -b 4096`

### Authentication
Authenticate the gcloud CLI with your Google account:
```bash
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
```

### Configuration
Create a `terraform.tfvars` file in the project root with your project ID:
```hcl
project = "your-gcp-project-id"
```

Note: `terraform.tfvars` is excluded from version control via `.gitignore` to keep sensitive values out of the repository.

## Usage

### Deploy
Once prerequisites are met, run the following commands in order:
```bash
# Initialize Terraform and configure the remote backend
terraform init

# Validate the configuration
terraform validate

# Preview the infrastructure changes
terraform plan

# Deploy the infrastructure to GCP
terraform apply
```

Type `yes` when prompted to confirm the apply.

### Access the VM
Once deployed, SSH into the VM using the public IP output:
```bash
ssh -i ~/.ssh/id_rsa YOUR_USERNAME@$(terraform output -raw public_ip)
```

### Destroy
When finished, tear down all infrastructure:
```bash
terraform destroy
```

> Note: The storage bucket must be empty before destroy will complete. 
> Delete any objects first with:
> ```bash
> gcloud storage rm gs://BUCKET_NAME/** --project=YOUR_PROJECT_ID
> ```