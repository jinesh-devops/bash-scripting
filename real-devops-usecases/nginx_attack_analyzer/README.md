# Nginx Attack Analyzer

This script helps Security / DevOps engineers automatically detect suspicious / abusive traffic inside NGINX access logs.

It scans only the last **10,000 log lines** (performance optimized) and identifies abnormal patterns like:

- High request spike from same IP
- Suspicious User Agents (curl / python / bots / scanners)
- Sensitive endpoints probing (`/wp-admin`, `/phpmyadmin`, `/login`, `.env`, etc)
- Excessive 4xx or 5xx error generation

### Why this script?

In real production, attacks start very silently (scan → brute force → enumeration) and most companies initially do not have WAF / IDS fully configured.

NGINX logs grow very large (GBs) and manual investigation becomes impossible.

This script automates the detection and gives immediate visibility into suspicious IPs **before major impact**.

---

## Detection Logic Table

| Detection Type         | What it means                                                    |
| ---------------------- | ---------------------------------------------------------------- |
| High Request Spike     | Bot or scanner hammering endpoints at high rate                  |
| Too many 4xx           | Hitting invalid URIs repeatedly (brute force / scan pattern)     |
| Too many 5xx           | Causing app failure / API stress                                 |
| Suspicious UserAgent   | python, curl, bot, spider, scanner etc                           |
| Sensitive Path Probe   | `/wp-admin`, `/login`, `/phpmyadmin`, `xmlrpc.php`, `.env` etc   |

---

## Requirements

A Linux machine with NGINX logs.

### Dependencies required:
- awk  
- grep  
- tail  
- sort  
- head  

---

## Usage

bash nginx_attack_analyzer.sh /var/log/nginx/access.log 200
200 here means - any IP making more than 200 requests will be flagged.

## Output Storage Location

All generated suspicious IP CSV reports are saved under:
/var/log/nginx_attack_analyzer/reports/


