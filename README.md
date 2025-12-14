# ☁️ AWS Cloud Crypto Dashboard

> **Status:** Active Development  
> **Type:** Personal Learning Portfolio

## 📖 About The Project
This project is a personal initiative designed to challenge and expand my expertise in **Cloud Architecture**, **DevOps**, and **Full-Stack Integration**.

The primary goal is not just to build a dashboard, but to implement a robust, scalable, and automated cloud infrastructure. It serves as a practical playground to test my knowledge of **AWS**, **Infrastructure as Code (Terraform)**, **CI/CD pipelines**, and **Python**. It prioritizes technical growth and a deep understanding of how managed services interact in a production-like environment.

## 🏗️ Architecture & Tech Stack
The application operates on a fully serverless architecture, provisioned and maintained via code:

* **Infrastructure as Code (IaC):**
    * **Terraform:** Manages the provisioning of all AWS resources (S3, API Gateway, Lambda, DynamoDB, SNS), ensuring reproducible and consistent environments.
* **CI/CD & Automation:**
    * **GitHub Actions:** Automated pipeline that builds and deploys frontend updates to S3 and backend logic to Lambda on every push.
* **Frontend:**
    * **HTML5 / CSS3 / JavaScript:** Custom dashboard using Chart.js for data visualization.
    * **AWS S3 (Static Website Hosting):** Hosts the frontend assets.
* **Backend & Compute:**
    * **AWS API Gateway:** Secure REST API entry point.
    * **AWS Lambda (Python 3.x):** Serverless functions for data retrieval and business logic.
    * **AWS SNS (Simple Notification Service):** Publishes alerts based on market volatility.
* **Database:**
    * **AWS DynamoDB:** NoSQL database storing historical crypto market data.

## 🚀 Current Features
* **Infrastructure as Code:** Entire cloud stack is defined in Terraform, allowing for rapid tear-down and re-deployment.
* **Automated CI/CD:** Zero-touch deployment; changes pushed to the repository are automatically deployed to the live AWS environment via GitHub Actions.
* **Smart Volatility Alerts:** An integrated **SNS** notification system triggers an alert to subscribers (Email/SMS) whenever the price of Bitcoin shifts significantly.
* **Live Data Visualization:** Renders historical crypto price trends using Chart.js.
* **Serverless Architecture:** Fully managed backend scaling automatically with demand.
* **CORS Handling:** Secure cross-origin resource sharing between the S3 bucket and API Gateway.

## 🗺️ Roadmap & Future Learning (To-Do)
With the core infrastructure and automation complete, the focus shifts to security, optimization, and user management:

- [ ] **Authentication:** Implement **AWS Cognito** to add user login and secure specific API endpoints.
- [ ] **Content Delivery & Security:** Place **AWS CloudFront** (CDN) in front of the S3 bucket for HTTPS, caching, and lower latency globally.
- [ ] **Custom Domain:** Configure **AWS Route53** to manage a custom domain name (e.g., `my-crypto-dash.com`).
- [ ] **Advanced Security:** Attach **AWS WAF** (Web Application Firewall) to the API Gateway/CloudFront to block malicious traffic.
- [ ] **Data Analytics:** Implement **AWS Athena** or **Glue** to run SQL queries on historical data archived in S3 (Data Lake concept).
- [ ] **Unit Testing:** Add Python unit tests (`pytest`) to the CI/CD pipeline to verify Lambda logic before deployment.

---
*Created by [nvan-lae] — Documenting my journey into the Cloud.*
