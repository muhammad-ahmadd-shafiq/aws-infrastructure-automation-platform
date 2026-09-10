# AWS Infrastructure Automation Platform
 
**End-to-end Infrastructure-as-Code platform** that provisions AWS infrastructure with Terraform, configures it with Ansible, and deploys a containerized application through a fully automated, security-conscious CI/CD pipeline.
 
---
 
## What this is
 
Push to `main`, and the pipeline takes care of everything: linting the infrastructure code, building and publishing a container image, provisioning (or updating) AWS infrastructure with remote, locked Terraform state, and configuring and deploying the application onto that infrastructure with Ansible, with no long-lived SSH access left open on the box afterward.
 
This isn't a toy example. It solves the problems that actually show up when you wire Terraform, Ansible, and GitHub Actions together for real: state locking, CI runners that don't have a fixed IP, private container registries, idempotent re-deploys, and secrets that never touch the repo.
 
## Architecture
 
```
                         push to main
                              │
                              ▼
                 ┌─────────────────────────┐
                 │   Lint & Validate       │
                 │  terraform fmt/validate │
                 │  tflint · checkov       │
                 │  ansible-lint           │
                 └────────────┬────────────┘
                              │
                              ▼
                 ┌─────────────────────────┐
                 │   Build & Push Image    │
                 │  Docker build → GHCR    │
                 │  tagged with commit SHA │
                 └────────────┬────────────┘
                              │
                              ▼
                 ┌─────────────────────────┐
                 │  Provision (Terraform)  │
                 │  VPC · Subnet · SG      │
                 │  EC2 · Key Pair         │
                 │  State: S3 + DynamoDB   │
                 └────────────┬────────────┘
                              │
                              ▼
                 ┌──────────────────────────┐
                 │  Configure & Deploy      │
                 │  (Ansible over SSH)      │
                 │  1. Open SSH for runner  │
                 │     IP only (temporary)  │
                 │  2. Install Docker       │
                 │  3. Auth to GHCR         │
                 │  4. Pull & run image     │
                 │  5. Revoke SSH access    │
                 └──────────────────────────┘
```
 
Every run deploys the **exact image built in that run** (tagged by commit SHA, not `:latest`), so there's no race between "which image is actually on the box" and "which commit triggered the deploy."
 
## Why it's built this way
 
| Design choice | Reason |
|---|---|
| **Remote state (S3 + DynamoDB)** | State isn't local to any one machine or CI runner; concurrent applies are locked, not corrupted. |
| **Dynamic SSH whitelisting** | GitHub-hosted runners don't have a fixed IP. Rather than opening port 22 to the internet permanently, the pipeline authorizes *only its own current IP*, deploys, then revokes it, every single run. |
| **Commit-SHA image tags** | `:latest` is a moving target with no guarantee the tag you pull matches the commit that triggered the deploy. Every deploy references an immutable, specific image. |
| **Private GHCR + scoped pull auth** | The container registry isn't public by default. The deploy step authenticates with a masked, `no_log`-protected credential rather than relying on public image visibility. |
| **Idempotent Ansible roles** | Re-running the pipeline against an already-configured server changes nothing that's already correct, safe to re-run, safe to re-trigger. |
| **Partial Terraform backend config** | The state bucket name never lives in source control; it's injected at `terraform init` time via CI secrets or a local, gitignored `backend.hcl`. |
 
## Repository layout
 
```
terraform/
├── modules/
│   ├── vpc/              # VPC, public subnet, internet gateway, routing
│   ├── security-group/   # Ingress/egress rules
│   ├── ec2/               # Application server
│   └── keypair/           # SSH key pair registration
├── bootstrap/             # One-time: creates the S3 state bucket + DynamoDB lock table
├── backend.tf              # Partial S3 backend (values injected at init time)
├── backend.hcl.example
├── terraform.tfvars.example
└── .tflint.hcl
 
ansible/
├── playbooks/setup.yml
├── roles/
│   ├── common/             # Base packages, system updates
│   ├── docker/             # Docker Engine install & config
│   └── app/                # GHCR auth, image pull, container run
├── inventory/
│   ├── hosts.ini.example    # Template, no real IP/paths committed
│   └── generate_inventory.sh
└── requirements.yml
 
app/                         # Flask dashboard + Dockerfile
 
.github/workflows/deploy.yml # Full CI/CD pipeline
```
 
## Getting started
 
### 1. One-time: create the remote state backend
 
```bash
cd terraform/bootstrap
terraform init
terraform apply -var="bucket_name=<your-globally-unique-bucket-name>"
```
 
This creates a versioned, encrypted, private S3 bucket and a `terraform-locks` DynamoDB table. Only this bootstrap config uses local state, by necessity, since it creates the backend the rest of the project relies on.
 
### 2. Configure GitHub Actions secrets
 
**Settings → Secrets and variables → Actions → New repository secret:**
 
| Secret | Purpose |
|---|---|
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | Terraform apply + dynamic security group management |
| `TF_STATE_BUCKET` | Bucket created in step 1 |
| `MY_IP` | Your IP, used for direct/manual access outside CI |
| `SSH_PUBLIC_KEY` | Injected into the EC2 instance at launch |
| `SSH_PRIVATE_KEY` | Matching private key, used by Ansible over SSH |
| `GHCR_USERNAME` / `GHCR_TOKEN` | Push + authenticate pulls against the container registry |
 
### 3. Push to `main`
 
That's it, lint, build, provision, and deploy all run automatically.
 
## Local development
 
```bash
# Terraform
cd terraform
cp terraform.tfvars.example terraform.tfvars   # fill in your values
cp backend.hcl.example backend.hcl             # fill in your bucket name
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
 
# Ansible (using the printed server_public_ip output)
cd ../ansible
./inventory/generate_inventory.sh <server_ip> ~/.ssh/<your_key>
ansible-playbook playbooks/setup.yml \
  -e "app_dashboard_image=ghcr.io/muhammad-ahmadd-shafiq/cloudops-dashboard:latest" \
  -e "app_ghcr_username=<your-username>" \
  -e "app_ghcr_token=<your-token>"
```
 
## Tech stack
 
- **Provisioning:** Terraform, AWS (VPC, EC2, Security Groups, S3, DynamoDB)
- **Configuration management:** Ansible
- **Containerization:** Docker, GitHub Container Registry
- **CI/CD:** GitHub Actions
- **Linting/security:** TFLint, Checkov, ansible-lint
- **Application:** Flask
## License
 
MIT, see [LICENSE](./LICENSE).
 
## Author
 
**Muhammad Ahmad Shafiq** - [GitHub](https://github.com/muhammad-ahmadd-shafiq)
 