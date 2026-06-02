# Detailed Deployment Report: TravelMemory MERN Application on AWS

**Prepared For:** DevOps Assignment  
**Author:** DevOps Engineer / Architect  
**Deployment Stack:** Terraform, Ansible, AWS, Nginx, MongoDB, Node.js/React  

---

## 1. Executive Summary

This report documents the design, automation, and deployment of the **TravelMemory** MERN application. The primary objective is to implement a highly secure, scalable, and automated infrastructure on Amazon Web Services (AWS) using Infrastructure as Code (IaC) with **Terraform**, followed by Configuration Management using **Ansible**.

The solution implements a **two-tier network architecture**, placing the application server in a public subnet and the database server in a private subnet. The integration ensures high performance and security using Nginx as a reverse proxy and PM2 for process monitoring, resolving common operational challenges such as CORS errors, direct port exposure, and database vulnerability.

---

## 2. Infrastructure Design & Terraform Implementation

The infrastructure was provisioned via modular Terraform scripts, ensuring repeatability and consistency.

### 2.1 Networking & Subnet Design
The network is encapsulated inside an AWS VPC with CIDR block `10.0.0.0/16`. Within this VPC, two separate subnets are created:
*   **Public Subnet (`10.0.1.0/24`):** Hosts the Web Server (React & Node.js). A public IP is auto-assigned to the instance upon launch.
*   **Private Subnet (`10.0.2.0/24`):** Hosts the MongoDB Database Server. Instances in this subnet are assigned private IPs only (`10.0.2.x`), making them completely unreachable from the public internet.

To establish connectivity:
*   An **Internet Gateway (IGW)** is attached to the VPC to enable internet access for the public subnet.
*   An **Elastic IP** is allocated and mapped to a **NAT Gateway** deployed in the public subnet. This NAT Gateway allows instances inside the private subnet to securely communicate outbound (e.g., to run package updates via `apt`), but rejects any incoming external requests.
*   **Route Tables** are configured:
    *   Public route table directs `0.0.0.0/0` traffic directly to the IGW.
    *   Private route table directs `0.0.0.0/0` traffic to the NAT Gateway.

### 2.2 EC2 Instance Provisioning
Two EC2 instances are provisioned using the latest **Ubuntu 22.04 LTS** AMI:
1.  **Web Server (`travelmemory-web-server`):** Launched in the Public Subnet, acting as the web entry point. It has an AWS Key Pair associated with it for initial administrator bootstrapping.
2.  **Database Server (`travelmemory-db-server`):** Launched in the Private Subnet, guaranteeing isolation.

### 2.3 Security Group (Firewall) Configuration
We enforced the principle of least privilege using stateful AWS Security Groups:
*   **Web Security Group:**
    *   **Ingress HTTP (80) & HTTPS (443):** Allowed from anywhere (`0.0.0.0/0`) to allow users to access the React frontend.
    *   **Ingress Node Port (3001):** Allowed from anywhere (optional, but Nginx proxy resolves this on port 80).
    *   **Ingress SSH (22):** Strictly restricted to the developer's public IP address (`allowed_ssh_ip` variable).
*   **Database Security Group:**
    *   **Ingress MongoDB (27017):** Strictly restricted to accept traffic *only* originating from the Web Security Group.
    *   **Ingress SSH (22):** Restricted to traffic coming from the Web Security Group, preventing direct SSH attempts from the outside world.

### 2.4 IAM Roles & Instance Profiles
Instances are provisioned with an IAM Instance Profile linked to an IAM Role containing the `AmazonSSMManagedInstanceCore` policy. This grants the AWS Systems Manager (SSM) agent permission to establish secure tunnels, allowing administrators to manage instances via the AWS console without needing to expose SSH port 22 publicly.

---

## 3. Configuration Management & Ansible Implementation

Ansible playbooks are utilized to bootstrap the operating systems, install required runtimes, configure services, and manage application deployment.

### 3.1 Network Traversal (SSH Jump Host / ProxyJump)
Because the database server resides inside the private subnet, Ansible cannot ping or connect to it directly from the control machine. To overcome this, the Ansible inventory (`inventory.ini`) uses an SSH `ProxyCommand`:
```ini
ansible_ssh_common_args='-o ProxyCommand="ssh -W %h:%p -q ubuntu@<webserver_public_ip>"'
```
This maps a multi-hop SSH tunnel, forcing all traffic directed to the private DB server to transparently jump through the public web server.

### 3.2 Database Server Setup (`playbooks/db.yml`)
The database playbook executes the following tasks on the private DB server:
1.  **Repository Setup:** Imports the official MongoDB GPG keys and adds the MongoDB repository list.
2.  **Installation:** Installs the `mongodb-org` metapackage and the modern `mongodb-mongosh` CLI shell.
3.  **Network Configuration:** Modifies `/etc/mongod.conf` to bind MongoDB to `0.0.0.0` (all interfaces) so it can listen for connections from the private network.
4.  **Database Seeding & Users:** Connects to the database and creates:
    *   An admin user with permissions over all databases.
    *   An application user (`travel_user`) with `readWrite` permissions on the `travelmemory` database.
5.  **Authorization Enforced:** Appends the `security: authorization: enabled` block to the config file and restarts MongoDB. This ensures that any subsequent connections require username/password validation.

### 3.3 Web Server Setup & Deployment (`playbooks/web.yml`)
The web playbook automates the deployment of the Node.js/React application:
1.  **Runtime Environment:** Installs Git, Nginx, and Node.js v18 (via the NodeSource repository).
2.  **Repository Management:** Clones the `TravelMemory` repository to `/var/www/travelmemory`.
3.  **Dependency Resolution:** Runs `npm install` inside both the `/backend` and `/frontend` subdirectories.
4.  **Backend Environment Generation:** Generates the backend `.env` file containing the port `3001` and the `MONGO_URI`. The connection string dynamically fetches the private IP of the database server from the inventory.
5.  **Frontend Compilation:** Sets `REACT_APP_BACKEND_URL` to point to the server's public IP `/api` endpoint, and compiles the React application via `npm run build`, generating static HTML/JS assets.
6.  **Nginx Reverse Proxy:** Creates a server block configuration in Nginx:
    *   Root requests (`/`) are routed to the compiled static folder `/var/www/travelmemory/frontend/build`.
    *   Requests starting with `/api/` are proxied internally to `http://localhost:3001/` (the Express backend).
7.  **Process Management:** Installs PM2 globally. PM2 manages the Node backend process, ensuring it auto-restarts on system failure or crash, and runs seamlessly in the background.

---

## 4. Component Interaction & Data Flow

Understanding how components interact is critical for maintaining this multi-tier architecture.

```
+------------------------------------------------------------------------------------------+
|                                    1. USER BROWSER                                       |
+--------------------------------------------+---------------------------------------------+
                                             |
                   Request Webpage           |            API Call (/api/trip)
                    (HTTP Port 80)           |               (HTTP Port 80)
                                             v
+--------------------------------------------+---------------------------------------------+
|                                    2. WEB SERVER (EC2)                                   |
|   +----------------------------------------+-----------------------------------------+   |
|   |                              NGINX (Reverse Proxy)                               |   |
|   +-------------------+------------------------------------+-------------------------+   |
|                       |                                    |                             |
|         Serves        |                                    |  Forward to                 |
|      Static Files     |                                    |  Localhost:3001             |
|                       v                                    v                             |
|   +-------------------+--------------------+   +-----------+-------------------------+   |
|   |         React Compiled Assets          |   |       Express.js Server (PM2)       |   |
|   |       (Location: /frontend/build)      |   |            (Port: 3001)             |   |
|   +----------------------------------------+   +-----------+-------------------------+   |
+------------------------------------------------------------|-----------------------------+
                                                             |
                                                             | Connect and Query
                                                             | (Private Link - Port 27017)
                                                             v
+------------------------------------------------------------+-----------------------------+
|                                  3. DATABASE SERVER (EC2)                                |
|   +----------------------------------------------------------------------------------+   |
|   |                                  MongoDB Server                                  |   |
|   |                            (Location: Private Subnet)                            |   |
|   +----------------------------------------------------------------------------------+   |
+------------------------------------------------------------------------------------------+
```

1.  **Client-Side Initialization:** The client accesses the web server IP via port `80`. Nginx serves the compiled React HTML and Javascript assets.
2.  **State Management & Requests:** When a user adds a travel memory, React fires an Axios HTTP POST request to `http://<web-server-public-ip>/api/trip`.
3.  **Reverse Proxying:** Nginx intercepts the request at `/api/trip`, strips the `/api` prefix, and forwards it to the local Express backend running on `http://localhost:3001/trip`.
4.  **Database CRUD Operations:** The Express backend parses the incoming request, authenticates against MongoDB on the private database server (`10.0.2.x:27017`), writes the JSON payload containing the memory details, and returns a JSON response back to the client via Nginx.

---

## 5. Security Hardening

To prepare the application for production, we implemented multiple layers of defense:

1.  **VPC-level Network Access Control Lists (NACLs) and Security Groups:** The database has zero public exposure. MongoDB cannot be reached unless connections originate from the Web Server security group on port 27017.
2.  **SSH Key Security:** Root logins are disabled via standard SSH configurations. Administrators must use the non-privileged `ubuntu` user with a registered SSH key-pair to authenticate.
3.  **MongoDB Authentication:** Even if an attacker gains access to the private network, they cannot read or write to MongoDB without providing valid credentials (`travel_user` / `TravelSecurePassword456`) which are securely passed via env files.
4.  **HTTP Security Headers:** Nginx is configured with security headers (such as `X-Frame-Options` to prevent clickjacking, `X-Content-Type-Options` to block MIME sniffing, and `X-XSS-Protection` to prevent cross-site scripting), aligning with OWASP best practices.
5.  **API Gateway Isolation:** The backend Express server runs on port 3001 and only binds to localhost requests or Nginx. There is no need to expose port 3001 directly to the outside world, minimizing the attack surface.

---

## 6. Conclusion

This deployment successfully shifts the **TravelMemory** MERN application from a development sandbox to a production-ready, automated AWS layout. 

*   **Terraform** managed the physical infrastructure, establishing a clear separation of security zones.
*   **Ansible** removed the friction of server updates, repository cloning, database security setup, and configuration syncing.
*   **Nginx** and **PM2** provided the process isolation, speed, and safety needed to serve users efficiently.

This modular structure is fully automated, enabling developers to tear down and rebuild the entire staging or production cluster in minutes with zero manual configuration.
