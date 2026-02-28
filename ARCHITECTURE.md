# Architecture Diagram

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
            PIP["Public IP Address"]
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
