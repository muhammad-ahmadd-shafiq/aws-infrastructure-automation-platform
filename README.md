# AWS Infrastructure Automation Platform

Infrastructure-as-Code project that provisions an AWS VPC + EC2 instance with
**Terraform**, configures it with **Ansible**, and deploys a containerized
Flask dashboard through a **GitHub Actions** CI/CD pipeline backed by
**remote Terraform state** (S3 + DynamoDB locking).

## Architecture

```
┌─────────────┐   push to main   ┌───────────────────────────────────────────┐
│  Developer  │ ───────────────► │              GitHub Actions                │
└─────────────┘                  │                                             │
                                  │  1. terraform-lint / ansible-lint          │
                                  │  2. build-and-push  → GHCR image (:sha)    │
                                  │  3. terraform-apply → VPC, SG, EC2, key    │
                                  │     (state in S3, locked via DynamoDB)     │
                                  │  4. configure-and-deploy → Ansible over    │
                                  │     SSH: installs Docker, pulls :sha       │
                                  │     image, runs the container              │
                                  └───────────────────────────────────────────┘
```

## Repo layout

```
terraform/
  modules/{vpc,security-group,ec2,keypair}/   # infra building blocks
  bootstrap/                                  # one-time: creates the S3 state
                                               # bucket + DynamoDB lock table
  backend.tf                                  # partial S3 backend config
  backend.hcl.example                         # template for local backend config
  terraform.tfvars.example                    # template for required variables
  .tflint.hcl                                 # lint rules

ansible/
  playbooks/setup.yml                         # common + docker + app roles
  roles/{common,docker,app}/
  inventory/
    hosts.ini.example                         # template — no real IP/paths committed
    generate_inventory.sh                     # writes the real hosts.ini from an IP

app/                                           # Flask dashboard + Dockerfile

.github/workflows/deploy.yml                  # full CI/CD pipeline
```

## One-time setup

1. **Create the remote state backend** (run once, locally, with your AWS
   credentials configured):
   ```bash
   cd terraform/bootstrap
   terraform init
   terraform apply -var="bucket_name=<your-unique-bucket-name>"
   ```
   This creates the S3 bucket (versioned, encrypted, private) and the
   `terraform-locks` DynamoDB table.

2. **Set GitHub Actions secrets** (Settings → Secrets and variables →
   Actions):

   | Secret | Purpose |
   |---|---|
   | `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | Terraform apply |
   | `TF_STATE_BUCKET` | Bucket created in step 1 |
   | `MY_IP` | Your IP in CIDR form, for the SSH/app security group rule |
   | `SSH_PUBLIC_KEY` | Injected into the EC2 instance via the keypair module |
   | `SSH_PRIVATE_KEY` | Matching private key, used by Ansible to connect |
   | `GHCR_USERNAME` / `GHCR_TOKEN` | Push the app image to GitHub Container Registry |

3. Push to `main`. The pipeline lints, builds and pushes the image,
   provisions/updates infrastructure, then configures the server and
   deploys the exact image built in that run.

## Local development

```bash
# Terraform
cd terraform
cp terraform.tfvars.example terraform.tfvars   # fill in your values
cp backend.hcl.example backend.hcl             # fill in your bucket name
terraform init -backend-config=backend.hcl
terraform plan
terraform apply

# Ansible (after apply, using the printed server_public_ip output)
cd ../ansible
./inventory/generate_inventory.sh <server_ip> ~/.ssh/id_ed25519
ansible-playbook playbooks/setup.yml \
  -e "dashboard_image=ghcr.io/muhammad-ahmadd-shafiq/cloudops-dashboard:latest"
```

## Notes

- `hosts.ini` and `backend.hcl` are gitignored — only the `.example`
  templates are committed.
- Terraform state is never local in the main config; only `terraform/bootstrap`
  (which creates the backend itself) uses local state, by necessity.
- The app role recreates the container on every run so a redeploy always
  picks up the freshly built image tag rather than a cached `:latest`.

## License

MIT — see [LICENSE](./LICENSE).
