# AWS Infra Idle Resource Auditor

This is a Bash based AWS cost optimization automation utility that identifies idle / unused AWS resources and optionally performs interactive cleanup safely.

### Purpose
To reduce unwanted cloud costs by continuously auditing AWS Infrastructure for idle resources such as unused EIPs, stopped EC2 instances, unattached EBS volumes, inactive Load Balancers, etc.

---

## Features

| Resource Type | Detection Logic | Delete Support |
|---------------|-----------------|----------------|
| EC2 Instances | Stopped instances older than X days OR low CPU avg below threshold | Yes (Interactive) |
| EBS Volumes | Unattached unused EBS volumes older than X days | Yes (Interactive) |
| Elastic IPs | EIPs not attached to any instance | Yes (Interactive) |
| ELB / Target Groups | Target groups with zero healthy targets | Yes (Interactive) |
| RDS Instances | Low CPU average (Report Only) | **No** |
| Snapshots | very old snapshots not used recently | Yes (Interactive) |
| ENIs | Orphan ENIs not attached to anything | Yes (Interactive) |
| Security Groups | Unused SGs not attached to any ENIs | Yes (Interactive)**(limited)** |

---

## Output Structure

Outputs are generated under:

/var/log/ec2_infra_idle_finder/
├── reports/ # CSV reports per category
├── logs/ # summary run level logs
└── audit/ # deletion audit logs (only when --do-delete used)


### Output Files Example

| File | Description |
|------|-------------|
| ec2_idle_instances_YYYYMMDD.csv | Idle EC2 instances |
| ebs_unattached_volumes_YYYYMMDD.csv | Old unused volumes |
| eips_unused_YYYYMMDD.csv | Unassociated public EIPs |
| elbs_zero_targets_YYYYMMDD.csv | Load balancers with no active targets |
| rds_idle_instances_YYYYMMDD.csv | RDS idle instances (no delete) |
| snapshots_old_YYYYMMDD.csv | Old snapshots beyond age |
| eni_orphan_YYYYMMDD.csv | Orphan network interfaces |
| sg_unused_YYYYMMDD.csv | Unused security groups |

A daily summary line is appended into:

/var/log/ec2_infra_idle_finder/logs/ec2_infra_summary_YYYYMMDD.log

## Usage

### Dry Run mode (no modify) - DEFAULT

bash aws_idle_resource_auditor.sh <aws_profile> <region> --age-days N --cpu-days M --cpu-threshold P --dry-run
bash aws_idle_resource_auditor.sh default us-east-1 --age-days 30 --cpu-days 7 --cpu-threshold 5 --dry-run

Interactive Delete Mode
bash aws_idle_resource_auditor.sh default us-east-1 --age-days 30 --cpu-days 7 --cpu-threshold 5 --do-delete --confirm

| Argument            | Meaning                                                   | Default |
| ------------------- | --------------------------------------------------------- | ------- |
| `--age-days N`      | Age threshold to consider old resources                   | 30      |
| `--cpu-days M`      | CPU metric lookback days (RDS/EC2)                        | 7       |
| `--cpu-threshold P` | CPU % threshold to consider instance idle                 | 5       |
| `--dry-run`         | (default) No deletion performed                           | true    |
| `--do-delete`       | Enable deletion mode                                      | false   |
| `--confirm`         | Double safety confirmation flag required with --do-delete | false   |
| `--send-email`      | future feature placeholder (SES notification)             | false   |

## Requirements

- AWS CLI v2 installed and configured
- IAM user / role with minimum read permissions for:
  - EC2
  - EBS
  - Elastic IP
  - ELB / Target Groups
  - RDS (read only)
  - Snapshots
  - ENI
  - Security Groups
- CloudWatch Read Metrics Access (for CPU evaluation)
- Bash shell (Linux)

## Future Enhancements Roadmap

- SES based email notification for daily report summary
- S3 archival of historical reports
- Terraform cost drift detection



