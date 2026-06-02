# TravelMemory MERN Stack Deployment on AWS

This project automates the deployment of the **TravelMemory** MERN (MongoDB, Express, React, Node.js) application onto a secure, two-tier AWS infrastructure.

The provisioning is managed using **Terraform**, and the configuration management & application deployment is orchestrated using **Ansible**.

---

## 🏛️ System Architecture

The following diagram illustrates the secure network layout, showing how components interact across the public and private subnets.

```mermaid
graph TD
    subgraph Internet ["Public Internet"]
        user["User's Browser"]
    end

    subgraph AWS ["AWS Cloud (VPC: 10.0.0.0/16)"]
        subgraph PublicSubnet ["Public Subnet (10.0.1.0/24)"]
            igw["Internet Gateway"]
            nat["NAT Gateway"]
            
            subgraph WebServer ["Web Server EC2 (t2.micro)"]
                nginx["Nginx (Port 80)"]
                react["React Frontend (Static Files)"]
                express["Express.js App (Port 3001, PM2)"]
            end
        end

        subgraph PrivateSubnet ["Private Subnet (10.0.2.0/24)"]
            subgraph DBServer ["Database Server EC2 (t2.micro)"]
                mongodb["MongoDB (Port 27017)"]
            end
        end
    end

    %% Network Routes
    user -->|HTTP: Port 80| nginx
    nginx -->|Serves Static Files| react
    nginx -->|Reverse Proxy: /api/*| express
    express -->|Port 27017 (Auth)| mongodb
    DBServer -->|Outbound Updates| nat
    nat -->|Outbound Traffic| igw
    igw -->|Internet| Internet

    %% Security restrictions
    style PrivateSubnet fill:#ffe6e6,stroke:#ff0000,stroke-width:1px
    style PublicSubnet fill:#e6f2ff,stroke:#0066cc,stroke-width:1px
    style WebServer fill:#ffffff,stroke:#333,stroke-width:2px
    style DBServer fill:#ffffff,stroke:#333,stroke-width:2px
```

### Key Security & Architectural Features:
1. **Network Isolation:** The Database Server is located in a private subnet, preventing direct ingress from the internet. The Web Server is in a public subnet to accept user traffic.
2. **Reverse Proxying:** Nginx acts as a reverse proxy, serving the compiled React static files and forwarding `/api/` calls to the local Node.js backend. This protects the backend from direct exposure and solves Cross-Origin Resource Sharing (CORS) complexities.
3. **SSM Managed Instances:** Instances are associated with an IAM Instance Profile containing the `AmazonSSMManagedInstanceCore` policy, allowing secure administration access via AWS Systems Manager without leaving SSH Port 22 open to the world.
4. **NAT Gateway Routing:** The private database server downloads updates and security patches through the NAT Gateway, while remaining shielded from incoming external connections.

---

## 🚀 Getting Started

### Prerequisites & AWS Configuration

Ensure the following tools are installed on your control system:
*   **Terraform** (>= 1.0.0)
*   **Ansible** (if running on Windows, use **WSL** or a Linux control host)
*   **AWS CLI** (installed and configured)

Follow these step-by-step instructions to set up your AWS environment before deploying:

#### 1. AWS Account & IAM User Configuration
1. Sign in to the [AWS Management Console](https://aws.amazon.com/).
2. Open the **IAM (Identity and Access Management)** dashboard.
3. Navigate to **Users** and click **Create User**.
4. Set a user name (e.g., `travelmemory-deployer`).
5. Under **Permissions options**, select **Attach policies directly** and attach the **AdministratorAccess** managed policy (needed for VPC, EC2, NAT Gateway, Security Group, and IAM Profile management).
6. Click **Create User**.
7. Select the newly created user, click the **Security credentials** tab, scroll down to **Access keys**, and click **Create access key**.
8. Select **Command Line Interface (CLI)** as the use case, check the confirmation, and click **Next** and **Create access key**.
9. **Crucial:** Download the `.csv` file containing your **Access Key ID** and **Secret Access Key**. Store them securely.

#### 2. Local AWS CLI Authentication
1. Install the [AWS CLI](https://aws.amazon.com/cli/) on your local machine.
2. Open a terminal (Git Bash, WSL, or Command Prompt) and run:
   ```bash
   aws configure
   ```
3. Enter the parameters when prompted:
   *   **AWS Access Key ID:** *[Paste your Access Key ID]*
   *   **AWS Secret Access Key:** *[Paste your Secret Access Key]*
   *   **Default region name:** `us-east-1` (or your preferred region)
   *   **Default output format:** `json`
4. Test the authentication by querying AWS S3:
   ```bash
   aws s3 ls
   ```

#### 3. SSH Key Pair Generation
You need local SSH credentials to establish secure connections with the instances:
1. Open a terminal and run the key-generator command:
   ```bash
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa
   ```
2. Press Enter to skip the passphrase.
3. This creates:
   *   Private Key: `~/.ssh/id_rsa` (configured in Ansible)
   *   Public Key: `~/.ssh/id_rsa.pub` (uploaded to AWS via Terraform)
4. Copy the public key text to paste into `terraform.tfvars`:
   ```bash
   cat ~/.ssh/id_rsa.pub
   ```

---

## 🛠️ Step 1: Provision Infrastructure with Terraform

1. Open your terminal and navigate to the `terraform/` directory:
   ```bash
   cd terraform
   ```

2. Initialize the Terraform backend and provider plugins:
   ```bash
   terraform init
   ```

3. Open `terraform.tfvars` and customize your configuration. Specifically, provide your SSH public key content and specify your local public IP for SSH ingress:
   ```hcl
   project_name   = "travelmemory"
   aws_region     = "us-east-1"
   allowed_ssh_ip = "YOUR_PUBLIC_IP/32" # Restricts SSH access to your IP only
   ssh_public_key = "ssh-rsa AAAAB3NzaC..." # Paste your actual public key content here
   ```

4. Preview the resources Terraform plans to create:
   ```bash
   terraform plan
   ```

5. Provision the infrastructure on AWS:
   ```bash
   terraform apply
   ```
   *(Review the resources and type `yes` when prompted)*

6. **Save the Outputs:** Once complete, Terraform will print outputs similar to:
   ```text
   web_server_public_ip = "54.210.35.42"
   web_server_public_dns = "ec2-54-210-35-42.compute-1.amazonaws.com"
   db_server_private_ip = "10.0.2.247"
   ```

---

## 🔧 Step 2: Configure & Deploy with Ansible

With the servers provisioned, use Ansible to configure MongoDB, install Node.js/NPM, and deploy the application.

1. Navigate to the `ansible/` directory:
   ```bash
   cd ../ansible
   ```

2. Update `inventory.ini` with the IPs output by Terraform:
   - Put the `web_server_public_ip` in the `[web]` group.
   - Put the `db_server_private_ip` in the `[db]` group.

   Example `inventory.ini`:
   ```ini
   [web]
   webserver ansible_host=54.210.35.42 ansible_user=ubuntu

   [db]
   dbserver ansible_host=10.0.2.247 ansible_user=ubuntu

   [db:vars]
   ansible_ssh_common_args='-o ProxyCommand="ssh -W %h:%p -q -o StrictHostKeyChecking=no ubuntu@54.210.35.42"'
   ```

3. Ensure your local SSH private key matches the public key uploaded to AWS, and update the `private_key_file` path in `ansible.cfg` if needed:
   ```ini
   private_key_file = ~/.ssh/id_rsa
   ```

4. Verify communication with your EC2 servers:
   ```bash
   ansible all -m ping
   ```

5. Run the master deployment playbook:
   ```bash
   ansible-playbook site.yml
   ```

---

## 🔍 Step 3: Verification

1. After Ansible completes, open your web browser.
2. Navigate to the public IP of your Web Server:
   `http://<web_server_public_ip>/` (e.g., `http://54.210.35.42/`).
3. Add a few travel entries (trips) to verify the React frontend successfully communicates with the Node.js backend and writes the records to the MongoDB database.
