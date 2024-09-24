# 🌐 Semantc Infrastructure

![Semantc Logo](https://your-logo-url.com/logo.png) <!-- Replace with your actual logo -->

Welcome to the **Semantc Infrastructure** repository! 🚀 This project leverages **Terraform** to manage and deploy scalable, secure, and client-specific resources on **Google Cloud Platform (GCP)**. Our mission is to provide robust infrastructure solutions that ensure data isolation, security, and efficiency for every client.

## 📋 Table of Contents

- [✨ Introduction](#-introduction)
- [🎯 Goals](#-goals)
- [🏗️ Architecture Overview](#-architecture-overview)
- [⚙️ Key Components](#️-key-components)
- [🚀 Getting Started](#-getting-started)
  - [1. Prerequisites](#1-prerequisites)
  - [2. Setup Instructions](#2-setup-instructions)
- [🔧 Usage](#-usage)
- [🤝 Contributing](#-contributing)
- [🔒 Security](#-security)
- [❓ Troubleshooting](#-troubleshooting)
- [📚 Resources](#-resources)
- [📫 Contact](#-contact)
- [📝 License](#-license)

---

## ✨ Introduction

The **Semantc Infrastructure** project is designed to automate the deployment and management of client-specific resources on GCP using Terraform. By adhering to best practices and the principle of least privilege, we ensure that each client's data and services remain isolated and secure.

## 🎯 Goals

- **Scalability:** Efficiently manage infrastructure for multiple clients with ease.
- **Security:** Implement strict access controls to safeguard client data.
- **Isolation:** Ensure complete separation of resources for each client to prevent data leaks.
- **Automation:** Streamline deployments and updates using Terraform for consistency and reliability.
- **Maintainability:** Facilitate easy modifications and scalability as client needs evolve.

## 🏗️ Architecture Overview

Our infrastructure is built around a modular Terraform setup, enabling reusable components for managing client resources and orchestrating data pipelines. Here's a high-level view:

1. **Master Service Account:** Centralized account with elevated permissions to manage pipelines and deploy resources.
2. **Client Service Accounts:** Dedicated accounts for each client with restricted, read-only access to their specific datasets and storage.
3. **Cloud Run Jobs:** Automated tasks for data ingestion and transformation, running under the master service account.
4. **BigQuery Datasets & Storage Buckets:** Isolated data storage solutions for each client, ensuring data integrity and security.

![Architecture Diagram](https://your-architecture-diagram-url.com/diagram.png) <!-- Replace with your actual architecture diagram -->

## ⚙️ Key Components

- **Terraform Modules:**
  - **Client Resources:** Manages creation of service accounts, BigQuery datasets, and Cloud Storage buckets for each client.
  - **Cloud Run Jobs:** Handles deployment of data ingestion and transformation jobs.
  
- **Service Accounts:**
  - **Master Service Account:** Orchestrates infrastructure and manages data pipelines with necessary permissions.
  - **Client Service Accounts:** Provides clients with limited access to their own resources.

- **Cloud Run Jobs:**
  - **Data Ingestion:** Automates the process of importing data into BigQuery.
  - **Data Transformation:** Processes and transforms raw data into actionable insights.

## 🚀 Getting Started

### 1. Prerequisites

Before diving in, ensure you have the following:

- **Google Cloud Account:** With permissions to create projects and manage IAM roles.
- **Google Cloud SDK (`gcloud`):** [Installation Guide](https://cloud.google.com/sdk/docs/install)
- **Terraform:** [Installation Guide](https://learn.hashicorp.com/tutorials/terraform/install-cli)
- **Service Account Keys:** JSON key files for Terraform and master service accounts.

### 2. Setup Instructions

Follow these steps to set up and deploy the infrastructure:

#### a. Clone the Repository

```bash
git clone https://github.com/your-username/semantc-infrastructure.git
cd semantc-infrastructure/terraform
```

#### b. Configure GCP Project

1. **Create a New Project:**

   ```bash
   gcloud projects create semantc-dev --name="Semantc Development"
   ```

2. **Set the New Project as Active:**

   ```bash
   gcloud config set project semantc-dev
   ```

3. **Enable Required APIs:**

   ```bash
   gcloud services enable run.googleapis.com \
       bigquery.googleapis.com \
       storage.googleapis.com \
       cloudresourcemanager.googleapis.com \
       secretmanager.googleapis.com \
       cloudbuild.googleapis.com \
       logging.googleapis.com \
       monitoring.googleapis.com
   ```

#### c. Create Service Accounts

1. **Terraform Service Account:**

   ```bash
   gcloud iam service-accounts create terraform-sa \
       --display-name="Terraform Service Account"
   ```

2. **Master Service Account:**

   ```bash
   gcloud iam service-accounts create master-sa \
       --display-name="Master Service Account for Pipelines"
   ```

3. **Client Service Accounts:**

   For each client (e.g., `client1`, `client2`):

   ```bash
   gcloud iam service-accounts create client1-sa \
       --display-name="Service Account for Client1"
   
   # Repeat for other clients
   ```

#### d. Assign IAM Roles

1. **Assign Roles to Terraform Service Account:**

   *⚠️ **Warning:** Assigning `roles/owner` is not recommended for production. It's better to assign specific roles based on your needs.*

   ```bash
   gcloud projects add-iam-policy-binding semantc-dev \
       --member="serviceAccount:terraform-sa@semantc-dev.iam.gserviceaccount.com" \
       --role="roles/owner"
   ```

2. **Assign Roles to Master Service Account:**

   ```bash
   gcloud projects add-iam-policy-binding semantc-dev \
       --member="serviceAccount:master-sa@semantc-dev.iam.gserviceaccount.com" \
       --role="roles/run.admin"
   
   gcloud projects add-iam-policy-binding semantc-dev \
       --member="serviceAccount:master-sa@semantc-dev.iam.gserviceaccount.com" \
       --role="roles/bigquery.admin"
   
   gcloud projects add-iam-policy-binding semantc-dev \
       --member="serviceAccount:master-sa@semantc-dev.iam.gserviceaccount.com" \
       --role="roles/storage.admin"
   ```

3. **Assign Read-Only Roles to Client Service Accounts:**

   ```bash
   # BigQuery Read Access for Client1
   gcloud projects add-iam-policy-binding semantc-dev \
       --member="serviceAccount:client1-sa@semantc-dev.iam.gserviceaccount.com" \
       --role="roles/bigquery.dataViewer"
   
   # Cloud Storage Read Access for Client1
   gcloud projects add-iam-policy-binding semantc-dev \
       --member="serviceAccount:client1-sa@semantc-dev.iam.gserviceaccount.com" \
       --role="roles/storage.objectViewer"
   
   # Repeat for other clients
   ```

#### e. Generate Service Account Keys

1. **Terraform Service Account Key:**

   ```bash
   gcloud iam service-accounts keys create ~/terraform-sa-key.json \
       --iam-account=terraform-sa@semantc-dev.iam.gserviceaccount.com
   ```

2. **Master Service Account Key:** *(If needed)*

   ```bash
   gcloud iam service-accounts keys create ~/master-sa-key.json \
       --iam-account=master-sa@semantc-dev.iam.gserviceaccount.com
   ```

> **⚠️ Security Note:** Store these JSON key files securely. Do **not** commit them to version control.

#### f. Configure Authentication for Terraform

Set the `GOOGLE_APPLICATION_CREDENTIALS` environment variable to point to your Terraform service account key:

```bash
export GOOGLE_APPLICATION_CREDENTIALS="~/terraform-sa-key.json"
```

> **Tip:** Add this line to your shell profile (e.g., `.bashrc` or `.zshrc`) for persistence.

---

## 🔧 Usage

With the setup complete, you can now manage your infrastructure using Terraform. Here's how:

1. **Navigate to the Terraform Directory:**

   ```bash
   cd terraform/
   ```

2. **Initialize Terraform:**

   This command initializes the Terraform working directory, downloading necessary providers and modules.

   ```bash
   terraform init
   ```

3. **Validate Configuration:**

   Ensure that the Terraform files are syntactically correct and internally consistent.

   ```bash
   terraform validate
   ```

4. **Plan the Deployment:**

   Review the changes Terraform will make to your infrastructure.

   ```bash
   terraform plan
   ```

5. **Apply the Configuration:**

   Deploy the infrastructure as defined in your Terraform files.

   ```bash
   terraform apply
   ```

   - **Confirm** by typing `yes` when prompted.

---

## 🤝 Contributing

We welcome contributions from the community! Whether it's reporting issues, suggesting features, or submitting pull requests, your input helps us improve.

### How to Contribute

1. **Fork the Repository**
2. **Create a Feature Branch**

   ```bash
   git checkout -b feature/YourFeature
   ```

3. **Commit Your Changes**
4. **Push to the Branch**

   ```bash
   git push origin feature/YourFeature
   ```

5. **Open a Pull Request**

   Describe your changes and submit the PR for review.

> **Note:** Please ensure that your contributions adhere to the project's coding standards and best practices.

---

## 🔒 Security

Security is paramount. We adhere to the principle of least privilege, ensuring that each service account has only the permissions necessary to perform its tasks. Here's how we maintain security:

- **Service Account Isolation:** Separate accounts for Terraform management, master operations, and client-specific access.
- **Read-Only Access for Clients:** Clients can only read their own data, preventing unauthorized modifications.
- **Secure Key Management:** Service account keys are stored securely and never committed to version control.
- **Regular Audits:** Periodic reviews of IAM roles and permissions to ensure compliance and security.

---

## ❓ Troubleshooting

Encountered an issue? Here are some common problems and solutions:

### 1. **API Errors**

**Error Message:**
```
Error: Error when reading or editing Project Service semantc-dev/run.googleapis.com: googleapi: Error 403: Cloud Resource Manager API has not been used in project...
```

**Solution:**
- **Enable the Cloud Resource Manager API:**
  ```bash
  gcloud services enable cloudresourcemanager.googleapis.com --project=semantc-dev
  ```
- **Ensure Correct Project is Set:**
  ```bash
  gcloud config set project semantc-dev
  ```
- **Retry Terraform Command:**
  ```bash
  terraform apply
  ```

### 2. **Authentication Issues**

**Solution:**
- **Verify `GOOGLE_APPLICATION_CREDENTIALS`:**
  ```bash
  echo $GOOGLE_APPLICATION_CREDENTIALS
  # Should output the path to your Terraform service account key
  ```
- **Re-authenticate with Service Account:**
  ```bash
  gcloud auth activate-service-account --key-file=~/terraform-sa-key.json
  ```

### 3. **Permission Denied Errors**

**Solution:**
- **Ensure Service Accounts Have Correct Roles:**
  Review and adjust IAM roles assigned to each service account as necessary.

### 4. **API Not Enabled**

**Solution:**
- **Enable Missing APIs:**
  ```bash
  gcloud services enable <API_NAME> --project=semantc-dev
  ```
  Replace `<API_NAME>` with the required API (e.g., `run.googleapis.com`).

---

## 📚 Resources

- [Terraform Documentation](https://www.terraform.io/docs)
- [Google Cloud IAM Roles](https://cloud.google.com/iam/docs/understanding-roles)
- [Google Cloud Storage Docs](https://cloud.google.com/storage/docs)
- [Google BigQuery Docs](https://cloud.google.com/bigquery/docs)
- [Google Cloud Run Docs](https://cloud.google.com/run/docs)
- [Terraform Best Practices](https://www.terraform.io/docs/language/best-practices/index.html)

---

## 📫 Contact

Have questions or need support? Reach out to us!

- **Fernando Máximo Ferreira**
- **Email:** fernando.maximo@example.com
- **GitHub:** [@fernandomaximoferreira](https://github.com/fernandomaximoferreira)
- **LinkedIn:** [Fernando Máximo Ferreira](https://www.linkedin.com/in/fernandomaximoferreira)

---

## 📝 License

This project is licensed under the [MIT License](LICENSE).

---

> **⚠️ Disclaimer:** Ensure that all sensitive information, such as service account keys, is stored securely and not exposed in version control systems or public repositories.