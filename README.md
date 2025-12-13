# Serverless Crypto Data Pipeline

## Overview
This project is a fully automated, serverless data pipeline built on AWS. It ingests real-time Bitcoin prices from the Coinbase API, streams the data for processing, detects significant price drops, and archives the history for analysis.

The entire infrastructure is defined as code (IaC) using Terraform, demonstrating modern DevOps and cloud engineering practices.

## Architecture
1. **Ingestion**: An AWS CloudWatch Event Rule triggers a **Lambda (Producer)** function every minute.
2. **Streaming**: The producer fetches the current BTC price and pushes it to an **AWS Kinesis Data Stream**.
3. **Processing**: An **AWS Lambda (Consumer)** function is triggered by the Kinesis stream to process records in batches.
4. **Alerting**: If the price drops below a defined threshold (configured via Terraform), an alert is published to **AWS SNS**.
5. **Storage**: All price data is normalized and persisted to **AWS DynamoDB** for historical tracking.

## Tech Stack
* **Infrastructure as Code**: Terraform (AWS Provider)
* **Cloud Provider**: Amazon Web Services (AWS)
    * **Compute**: AWS Lambda (Python 3.9)
    * **Streaming**: Amazon Kinesis Data Streams
    * **Database**: Amazon DynamoDB (NoSQL)
    * **Messaging**: Amazon SNS (Simple Notification Service)
    * **Orchestration**: Amazon EventBridge (CloudWatch Events)
* **Language**: Python 3.9 (Boto3 SDK)
* **External API**: Coinbase Public API

## Key Features
* **Real-time Processing**: Low-latency streaming of financial data using Kinesis.
* **Automated Alerting**: Immediate SNS notifications when market conditions meet specific criteria (e.g., "Crash Alert").
* **Serverless Scalability**: Fully managed compute and database resources that scale to zero when not in use.
* **Secure & Robust**: Implements Least Privilege IAM roles and defined resource policies.

## Deployment
This project is deployed using Terraform:
```bash
terraform init
terraform apply
```

### Source Analysis
This README reflects the specific architecture found in your uploaded files:
* **Producer Logic**: I identified the ingestion flow where a CloudWatch Event Rule (`every-minute-trigger`) triggers the Producer Lambda, which queries the Coinbase API and writes to a Kinesis stream named `crypto-price-stream`.
* **Consumer Logic**: The Consumer Lambda is configured to read from that Kinesis stream, check if the price is below the environment variable `PRICE_THRESHOLD` (set to "85000" in your Terraform config), send an SNS notification to `crypto-price-alerts`, and finally save the item to the `CryptoData` DynamoDB table.
* **Infrastructure**: The use of Terraform is confirmed by the `main.tf` and `.tfstate` files, which define the provider as `eu-west-3` and manage all IAM roles and resources.
