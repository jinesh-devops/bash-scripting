## Advanced DevOps Automation Scripts

This folder contains advanced level Bash automation scripts focused on AWS Cloud, Container Security and Kubernetes Observability.  
These scripts demonstrate real world production troubleshooting + preventive automation used in modern DevOps.

---

### 1) Script: **aws_cost_analyzer.sh**

**Purpose**  
Calculates daily AWS cost per service (EC2, EBS, S3, RDS, ELB, Lambda, EKS etc), generates CSV report and stores historical cost summary.  
Helps detect sudden cost spikes early and improves Cloud FinOps visibility.

**Tools Used**
- AWS CLI  
- bash  
- bc  
- AWS Cost Explorer API

---

### 2) Script: **container_vulnerability_scanner.sh**

**Purpose**  
Scans Docker images using Trivy and reports CRITICAL / HIGH / MEDIUM vulnerability counts against threshold limits.  
Also stores results into CSV log for historical tracking.

**Tools Used**
- Docker  
- Trivy Security Scanner  
- jq  
- bash  
- bc

---

### 3) Script: **k8s_pod_failure_analyzer.sh**

**Purpose**  
Monitors Kubernetes pods across namespaces and detects failures like CrashLoopBackOff, OOMKilled, ImagePullBackOff, ErrImagePull, PendingTooLong and NodeNotReady.  
Writes detailed per-issue CSV + summary alerts for proactive troubleshooting.

**Tools Used**
- kubectl  
- jq  
- bash  
- bc

