# Azure Web Server – Architecture Diagram

## Scenario
Single Ubuntu web server in Azure, managed by Terraform. Public access for **SSH** (22) and **HTTP** (80).

---

## Architecture Diagram (Mermaid)

```mermaid
flowchart TB
    subgraph TF["Terraform (IaC)"]
        direction TB
        TFFILES[".tf files"]
    end

    subgraph AZ["Azure Subscription"]
        RG["Resource Group"]

        subgraph NET["Networking"]
            VNET["Virtual Network"]
            SNET["Subnet"]
            PIP["Public IP"]
            NSG["Network Security Group"]
        end

        subgraph COMP["Compute"]
            NIC["NIC"]
            WEBVM["Ubuntu VM\n(Web Server)"]
        end
    end

    subgraph INTERNET["Internet"]
        USER["Users / Clients"]
    end

    TFFILES --> RG
    RG --> VNET
    RG --> PIP
    RG --> NSG
    VNET --> SNET
    RG --> WEBVM
    SNET --> NIC
    PIP --> NIC
    NIC --> WEBVM
    NSG --> NIC

    USER -->|"HTTP :80"| PIP
    USER -->|"SSH :22"| PIP
```

---

## Component Summary

| Component | Purpose |
|-----------|---------|
| **Resource Group** | Logical container for all resources in this solution |
| **Virtual Network + Subnet** | Network isolation for the VM |
| **Public IP** | Single public address for SSH and HTTP access |
| **Network Security Group** | Allow inbound TCP 22 (SSH) and 80 (HTTP); deny other inbound by default |
| **Ubuntu VM** | Web server; latest supported Ubuntu LTS |

---

## Traffic Flow

- **HTTP (80):** Internet → Public IP → NSG (allow 80) → NIC → Ubuntu VM (web server).
- **SSH (22):** Internet → Public IP → NSG (allow 22) → NIC → Ubuntu VM (SSH).

Terraform provisions and manages all Azure resources above.
