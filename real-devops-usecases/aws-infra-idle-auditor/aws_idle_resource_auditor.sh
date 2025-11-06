#!/bin/bash
################################
# Author: Cheedella Jinesh
# Date: 2025-11-06
# Description: AWS Idle Resource Auditor - audits AWS resources and optionally performs interactive deletions
# Usage (dry-run): ./aws_idle_resource_auditor.sh <aws_profile> <AWS_Region> --age-days N --cpu-days M --cpu-threshold P --dry-run
# Usage (interactive delete): sudo ./aws_idle_resource_auditor.sh <aws_profile> <AWS_Region> --age-days N --cpu-days M --cpu-threshold P --do-delete --confirm
################################

set -o pipefail
set -u

# -------------------------
# Arg parsing
# -------------------------
if [ $# -lt 3 ]; then
    echo "Usage: $0 <aws_profile> <AWS_Region> --age-days N --cpu-days M --cpu-threshold P [--dry-run] [--do-delete --confirm] [--send-email]"
    exit 1
fi

AWS_PROFILE=$1
AWS_REGION=$2
shift 2

# defaults
AGE_DAYS=30
CPU_DAYS=7
CPU_THRESHOLD=5
DRY_RUN=true
DO_DELETE=false
CONFIRM=false
SEND_EMAIL=false
NAME_FALLBACK="N/A"

# parse remaining args
while [[ $# -gt 0 ]]; do
    case $1 in
        --age-days) AGE_DAYS="$2"; shift 2;;
        --cpu-days) CPU_DAYS="$2"; shift 2;;
        --cpu-threshold) CPU_THRESHOLD="$2"; shift 2;;
        --dry-run) DRY_RUN=true; shift;;
        --do-delete) DO_DELETE=true; DRY_RUN=false; shift;;
        --confirm) CONFIRM=true; shift;;
        --send-email) SEND_EMAIL=true; shift;;
        *) echo "Unknown arg: $1"; exit 1;;
    esac
done

# require both flags for deletion
if [ "$DO_DELETE" = true ] && [ "$CONFIRM" != true ]; then
    echo "Error: --do-delete requires --confirm for safety."
    exit 1
fi

# -------------------------
# Dependencies
# -------------------------
for cmd in aws jq date awk grep sort tail bc; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: required command '$cmd' not found. Install and retry."
        exit 2
    fi
done

# -------------------------
# Validate AWS profile works
# -------------------------
if ! aws sts get-caller-identity --profile "$AWS_PROFILE" --region "$AWS_REGION" >/dev/null 2>&1; then
    echo "Error: AWS profile '$AWS_PROFILE' invalid or cannot access AWS API in region $AWS_REGION."
    exit 3
fi

# -------------------------
# Output paths and files
# -------------------------
OUTPUT_BASE=${OUTPUT_BASE:-/var/log/ec2_infra_idle_finder}
REPORT_DIR="$OUTPUT_BASE/reports"
LOG_DIR="$OUTPUT_BASE/logs"
TMP_DIR="$OUTPUT_BASE/tmp"
AUDIT_DIR="$OUTPUT_BASE/audit"
mkdir -p "$REPORT_DIR" "$LOG_DIR" "$TMP_DIR" "$AUDIT_DIR" || { echo "Error: Cannot create output directories under $OUTPUT_BASE"; exit 4; }

TIMESTAMP=$(date +"%Y%m%d")
DATE_ISO=$(date +"%Y-%m-%d")
SUMMARY_LOG="$LOG_DIR/ec2_infra_summary_${TIMESTAMP}.log"
DELETION_AUDIT="$AUDIT_DIR/deletion_audit_${TIMESTAMP}.log"

# per resource csv paths (overwrite each run)
EC2_CSV="$REPORT_DIR/ec2_idle_instances_${TIMESTAMP}.csv"
EBS_CSV="$REPORT_DIR/ebs_unattached_volumes_${TIMESTAMP}.csv"
EIP_CSV="$REPORT_DIR/eips_unused_${TIMESTAMP}.csv"
ELB_CSV="$REPORT_DIR/elbs_zero_targets_${TIMESTAMP}.csv"
RDS_CSV="$REPORT_DIR/rds_idle_instances_${TIMESTAMP}.csv"
SNAP_CSV="$REPORT_DIR/snapshots_old_${TIMESTAMP}.csv"
ENI_CSV="$REPORT_DIR/eni_orphan_${TIMESTAMP}.csv"
SG_CSV="$REPORT_DIR/sg_unused_${TIMESTAMP}.csv"

echo "Date,ResourceType,ResourceId,Name,State,RegionAZ,AgeDays,Details,RemediationHint" > "$EC2_CSV"
echo "Date,ResourceType,ResourceId,Name,State,RegionAZ,AgeDays,Details,RemediationHint" > "$EBS_CSV"
echo "Date,ResourceType,ResourceId,Name,State,RegionAZ,AgeDays,Details,RemediationHint" > "$EIP_CSV"
echo "Date,ResourceType,ResourceId,Name,State,RegionAZ,AgeDays,Details,RemediationHint" > "$ELB_CSV"
echo "Date,ResourceType,ResourceId,Name,State,RegionAZ,AgeDays,Details,RemediationHint" > "$RDS_CSV"
echo "Date,ResourceType,ResourceId,Name,State,RegionAZ,AgeDays,Details,RemediationHint" > "$SNAP_CSV"
echo "Date,ResourceType,ResourceId,Name,State,RegionAZ,AgeDays,Details,RemediationHint" > "$ENI_CSV"
echo "Date,ResourceType,ResourceId,Name,State,RegionAZ,AgeDays,Details,RemediationHint" > "$SG_CSV"

# counters
cnt_stopped_instances=0
cnt_idle_instances=0
cnt_unattached_vols=0
cnt_unused_eips=0
cnt_elb_zero=0
cnt_rds_idle=0
cnt_snap_old=0
cnt_eni_orphan=0
cnt_sg_unused=0

# helpers
to_epoch() { date -d "$1" +%s 2>/dev/null || date -d "${1%.*}" +%s 2>/dev/null || echo 0; }
age_days() { ts="$1"; [ -z "$ts" ] && echo 0 && return; now=$(date +%s); then_epoch=$(to_epoch "$ts"); [ -z "$then_epoch" ] && echo 0 && return; awk -v n="$now" -v t="$then_epoch" 'BEGIN{printf "%d", (n - t) / 86400 }'; }

log_deletion() { echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1 $2 $3 $4" >> "$DELETION_AUDIT"; }

confirm_and_delete() {
    # $1 prompt message, $2 action string (eval'ed), $3 resource type label, $4 resource id
    prompt="$1"; action="$2"; rtype="$3"; rid="$4"
    echo
    echo "ATTENTION: interactive deletion action"
    echo "$prompt"
    echo "Type YES to proceed, anything else to skip:"
    read -r answer
    if [ "$answer" = "YES" ]; then
        if eval "$action"; then
            log_deletion "DELETED" "$rtype" "$rid" "$action"
            echo "Deleted: $rtype $rid"
        else
            echo "Delete action failed for $rid (check permissions)"
        fi
    else
        echo "Skipped deletion for $rid"
    fi
}

# -------------------------
# 1) Stopped EC2 instances older than AGE_DAYS
# -------------------------
echo "Checking stopped EC2 instances (older than $AGE_DAYS days)..."
stopped_json=$(aws ec2 describe-instances --profile "$AWS_PROFILE" --region "$AWS_REGION" --filters Name=instance-state-name,Values=stopped)
stopped_ids=$(echo "$stopped_json" | jq -r '.Reservations[].Instances[]?.InstanceId' 2>/dev/null || true)
for iid in $stopped_ids; do
    inst=$(echo "$stopped_json" | jq -r --arg id "$iid" '.Reservations[].Instances[] | select(.InstanceId==$id)')
    launch=$(echo "$inst" | jq -r '.LaunchTime // empty')
    name=$(echo "$inst" | jq -r '.Tags[]? | select(.Key=="Name") | .Value' 2>/dev/null || echo "")
    [ -z "$name" ] && name="$NAME_FALLBACK"
    az=$(echo "$inst" | jq -r '.Placement.AvailabilityZone // empty')
    age=$(age_days "$launch")
    if [ "$age" -ge "$AGE_DAYS" ]; then
        cnt_stopped_instances=$((cnt_stopped_instances+1))
        details="LaunchTime=${launch}"
        hint="Consider snapshot/terminate or keep if required"
        printf "%s,EC2,%s,%s,stopped,%s,%s,%s,%s\n" "$DATE_ISO" "$iid" "$name" "$az" "$age" "$details" "$hint" >> "$EC2_CSV"
        if [ "$DO_DELETE" = true ]; then
            prompt="Terminate stopped EC2 instance $iid (Name=$name, Age=${age}d)?"
            delete_cmd="aws ec2 terminate-instances --profile \"$AWS_PROFILE\" --region \"$AWS_REGION\" --instance-ids $iid >/dev/null 2>&1"
            confirm_and_delete "$prompt" "$delete_cmd" "EC2" "$iid"
        fi
    fi
done

# -------------------------
# 2) Running EC2 instances low CPU (offer STOP)
# -------------------------
echo "Checking running EC2 instances CPU average over last $CPU_DAYS days (threshold $CPU_THRESHOLD%) ..."
running_json=$(aws ec2 describe-instances --profile "$AWS_PROFILE" --region "$AWS_REGION" --filters Name=instance-state-name,Values=running)
running_ids=$(echo "$running_json" | jq -r '.Reservations[].Instances[]?.InstanceId' 2>/dev/null || true)
END_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
START_TIME=$(date -u -d "$CPU_DAYS days ago" +"%Y-%m-%dT%H:%M:%SZ")
for iid in $running_ids; do
    inst=$(echo "$running_json" | jq -r --arg id "$iid" '.Reservations[].Instances[] | select(.InstanceId==$id)')
    name=$(echo "$inst" | jq -r '.Tags[]? | select(.Key=="Name") | .Value' 2>/dev/null || echo "")
    [ -z "$name" ] && name="$NAME_FALLBACK"
    az=$(echo "$inst" | jq -r '.Placement.AvailabilityZone // empty')
    cw=$(aws cloudwatch get-metric-statistics --profile "$AWS_PROFILE" --region "$AWS_REGION" \
        --namespace AWS/EC2 --metric-name CPUUtilization \
        --start-time "$START_TIME" --end-time "$END_TIME" --period 3600 \
        --statistics Average --dimensions Name=InstanceId,Value="$iid" 2>/dev/null)
    avg=$(echo "$cw" | jq -r '.Datapoints[].Average' 2>/dev/null | awk '{sum += $1; c++} END { if (c>0) printf "%.2f", sum/c; else print "0.00"}')
    [ -z "$avg" ] && avg="0.00"
    launch=$(echo "$inst" | jq -r '.LaunchTime // empty')
    age=$(age_days "$launch")
    if awk "BEGIN{exit !($avg < $CPU_THRESHOLD)}"; then
        cnt_idle_instances=$((cnt_idle_instances+1))
        details="CPU_avg=${avg}% over ${CPU_DAYS}d; LaunchTime=${launch}"
        hint="Consider stop/resize/hibernate; snapshot root volume first"
        printf "%s,EC2,%s,%s,running,%s,%s,%s,%s\n" "$DATE_ISO" "$iid" "$name" "$az" "$age" "$details" "$hint" >> "$EC2_CSV"

        if [ "$DO_DELETE" = true ]; then
            echo
            echo "Found low-CPU running EC2 $iid (Name=$name, CPU_avg=${avg}%)."
            echo "Type YES to STOP this instance, anything else to skip:"
            read -r ans2
            if [ "$ans2" = "YES" ]; then
                if aws ec2 stop-instances --profile "$AWS_PROFILE" --region "$AWS_REGION" --instance-ids "$iid" >/dev/null 2>&1; then
                    log_deletion "STOPPED" "EC2" "$iid" "Stopped by auditor (low CPU)"
                    echo "Stopped instance $iid"
                else
                    echo "Failed to stop instance $iid"
                fi
            else
                echo "Skipped stopping $iid"
            fi
        fi
    fi
done

# -------------------------
# 3) Unattached EBS volumes
# -------------------------
echo "Scanning for unattached EBS volumes..."
vols=$(aws ec2 describe-volumes --profile "$AWS_PROFILE" --region "$AWS_REGION" --filters Name=status,Values=available)
vol_ids=$(echo "$vols" | jq -r '.Volumes[]?.VolumeId' 2>/dev/null || true)
for vid in $vol_ids; do
    vol=$(echo "$vols" | jq -r --arg id "$vid" '.Volumes[] | select(.VolumeId==$id)')
    create=$(echo "$vol" | jq -r '.CreateTime // empty')
    az=$(echo "$vol" | jq -r '.AvailabilityZone // empty')
    size=$(echo "$vol" | jq -r '.Size // empty')
    name=$(echo "$vol" | jq -r '.Tags[]? | select(.Key=="Name") | .Value' 2>/dev/null || echo "")
    [ -z "$name" ] && name="$NAME_FALLBACK"
    age=$(age_days "$create")
    if [ "$age" -ge "$AGE_DAYS" ]; then
        cnt_unattached_vols=$((cnt_unattached_vols+1))
        details="Size=${size}GiB; CreateTime=${create}"
        hint="Consider snapshot then delete if not required"
        printf "%s,EBS,%s,%s,available,%s,%s,%s,%s\n" "$DATE_ISO" "$vid" "$name" "$az" "$age" "$details" "$hint" >> "$EBS_CSV"

        if [ "$DO_DELETE" = true ]; then
            prompt="Delete unattached EBS volume $vid (Name=$name, Size=${size}GiB, Age=${age}d)?"
            delete_cmd="aws ec2 delete-volume --profile \"$AWS_PROFILE\" --region \"$AWS_REGION\" --volume-id $vid >/dev/null 2>&1"
            confirm_and_delete "$prompt" "$delete_cmd" "EBS" "$vid"
        fi
    fi
done

# -------------------------
# 4) Unused Elastic IPs
# -------------------------
echo "Scanning for unused Elastic IPs..."
addresses=$(aws ec2 describe-addresses --profile "$AWS_PROFILE" --region "$AWS_REGION")
allocs=$(echo "$addresses" | jq -r '.Addresses[]?.AllocationId' 2>/dev/null || true)
for aid in $allocs; do
    addr=$(echo "$addresses" | jq -r --arg id "$aid" '.Addresses[] | select(.AllocationId==$id)')
    assoc=$(echo "$addr" | jq -r '.AssociationId // empty')
    pubip=$(echo "$addr" | jq -r '.PublicIp // empty')
    instanceid=$(echo "$addr" | jq -r '.InstanceId // empty')
    if [ -z "$assoc" ]; then
        cnt_unused_eips=$((cnt_unused_eips+1))
        details="PublicIp=${pubip}"
        hint="Release EIP to avoid charges"
        printf "%s,EIP,%s,%s,unassociated,%s,%s,%s,%s\n" "$DATE_ISO" "$aid" "$pubip" "$AWS_REGION" "NA" "$details" "$hint" >> "$EIP_CSV"

        if [ "$DO_DELETE" = true ]; then
            prompt="Release unassociated EIP $pubip (AllocationId=$aid)?"
            delete_cmd="aws ec2 release-address --profile \"$AWS_PROFILE\" --region \"$AWS_REGION\" --allocation-id $aid >/dev/null 2>&1"
            confirm_and_delete "$prompt" "$delete_cmd" "EIP" "$aid"
        fi
    else
        if [ -n "$instanceid" ]; then
            state=$(aws ec2 describe-instances --profile "$AWS_PROFILE" --region "$AWS_REGION" --instance-ids "$instanceid" 2>/dev/null | jq -r '.Reservations[].Instances[].State.Name' 2>/dev/null || echo "")
            if [ "$state" = "stopped" ]; then
                cnt_unused_eips=$((cnt_unused_eips+1))
                details="PublicIp=${pubip};assoc_to_stopped=${instanceid}"
                hint="Release EIP or reassign"
                printf "%s,EIP,%s,%s,associated_to_stopped,%s,%s,%s,%s\n" "$DATE_ISO" "$aid" "$pubip" "$AWS_REGION" "NA" "$details" "$hint" >> "$EIP_CSV"

                if [ "$DO_DELETE" = true ]; then
                    prompt="Release EIP $pubip associated to stopped instance $instanceid?"
                    delete_cmd="aws ec2 release-address --profile \"$AWS_PROFILE\" --region \"$AWS_REGION\" --allocation-id $aid >/dev/null 2>&1"
                    confirm_and_delete "$prompt" "$delete_cmd" "EIP" "$aid"
                fi
            fi
        fi
    fi
done

# -------------------------
# 5) ELB/TargetGroups (report only)
# -------------------------
echo "Scanning ELBv2 target groups for zero healthy targets..."
tg_arns=$(aws elbv2 describe-target-groups --profile "$AWS_PROFILE" --region "$AWS_REGION" 2>/dev/null | jq -r '.TargetGroups[]?.TargetGroupArn' 2>/dev/null || true)
for arn in $tg_arns; do
    tg=$(aws elbv2 describe-target-health --profile "$AWS_PROFILE" --region "$AWS_REGION" --target-group-arn "$arn" 2>/dev/null)
    healthy=$(echo "$tg" | jq -r '.TargetHealthDescriptions[]?.TargetHealth?.State' 2>/dev/null | grep -c "healthy" || true)
    total=$(echo "$tg" | jq -r '.TargetHealthDescriptions[]?.TargetHealth?.State' 2>/dev/null | wc -l || true)
    if [ -z "$total" ] || [ "$total" -eq 0 ] || [ "$healthy" -eq 0 ]; then
        meta=$(aws elbv2 describe-target-groups --profile "$AWS_PROFILE" --region "$AWS_REGION" --target-group-arns "$arn" 2>/dev/null | jq -r '.TargetGroups[0]')
        name=$(echo "$meta" | jq -r '.TargetGroupName // empty')
        [ -z "$name" ] && name="$NAME_FALLBACK"
        cnt_elb_zero=$((cnt_elb_zero+1))
        details="zero_or_unhealthy_targets"
        hint="Investigate target group $name; no automatic deletion performed"
        printf "%s,ELB,%s,%s,unused,%s,%s,%s,%s\n" "$DATE_ISO" "$arn" "$name" "$AWS_REGION" "NA" "$details" "$hint" >> "$ELB_CSV"
    fi
done

# -------------------------
# 6) RDS idle detection (REPORT ONLY - no deletion)
# -------------------------
echo "Scanning RDS instances for low CPU (report only)..."
dbs=$(aws rds describe-db-instances --profile "$AWS_PROFILE" --region "$AWS_REGION" 2>/dev/null | jq -r '.DBInstances[]?.DBInstanceIdentifier' 2>/dev/null || true)
END_TIME_RDS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
START_TIME_RDS=$(date -u -d "$CPU_DAYS days ago" +"%Y-%m-%dT%H:%M:%SZ")
for db in $dbs; do
    dbmeta=$(aws rds describe-db-instances --profile "$AWS_PROFILE" --region "$AWS_REGION" --db-instance-identifier "$db" 2>/dev/null | jq -r '.DBInstances[0]')
    name=$(echo "$dbmeta" | jq -r '.DBInstanceIdentifier // empty')
    [ -z "$name" ] && name="$NAME_FALLBACK"
    createTime=$(echo "$dbmeta" | jq -r '.InstanceCreateTime // empty')
    age=$(age_days "$createTime")
    cw=$(aws cloudwatch get-metric-statistics --profile "$AWS_PROFILE" --region "$AWS_REGION" \
        --namespace AWS/RDS --metric-name CPUUtilization \
        --start-time "$START_TIME_RDS" --end-time "$END_TIME_RDS" --period 3600 \
        --statistics Average --dimensions Name=DBInstanceIdentifier,Value="$db" 2>/dev/null)
    avg=$(echo "$cw" | jq -r '.Datapoints[].Average' 2>/dev/null | awk '{sum += $1; c++} END { if (c>0) printf "%.2f", sum/c; else print "0.00"}')
    [ -z "$avg" ] && avg="0.00"
    if awk "BEGIN{exit !($avg < $CPU_THRESHOLD)}"; then
        cnt_rds_idle=$((cnt_rds_idle+1))
        details="CPU_avg=${avg}% over ${CPU_DAYS}d"
        hint="RDS is report-only. Do NOT delete automatically; consider manual review"
        printf "%s,RDS,%s,%s,available,%s,%s,%s,%s\n" "$DATE_ISO" "$db" "$name" "$AWS_REGION" "$age" "$details" "$hint" >> "$RDS_CSV"
    fi
done

# -------------------------
# 7) Snapshots old (delete optional) - use process-substitution to avoid subshell issues
# -------------------------
echo "Scanning snapshots older than $AGE_DAYS days..."
aws ec2 describe-snapshots --owner-ids self --profile "$AWS_PROFILE" --region "$AWS_REGION" 2>/dev/null \
    | jq -r '.Snapshots[]? | "\(.SnapshotId)\t\(.StartTime)\t\(.VolumeId // "")\t\(.Description // "")"' \
    > "$TMP_DIR/snapshots_list_${TIMESTAMP}.tsv" 2>/dev/null || true

while IFS=$'\t' read -r sid start vol desc; do
    [ -z "$sid" ] && continue
    age=$(age_days "$start")
    if [ "$age" -ge "$AGE_DAYS" ]; then
        cnt_snap_old=$((cnt_snap_old+1))
        summary_desc=$(echo "$desc" | sed 's/[,]/ /g')
        details="Volume=${vol}; StartTime=${start}"
        hint="Review snapshot; delete if obsolete"
        printf "%s,SNAPSHOT,%s,%s,completed,%s,%s,%s,%s\n" "$DATE_ISO" "$sid" "$summary_desc" "$AWS_REGION" "$age" "$details" "$hint" >> "$SNAP_CSV"
        if [ "$DO_DELETE" = true ]; then
            prompt="Delete snapshot $sid (Desc='${summary_desc}', Age=${age}d)?"
            delete_cmd="aws ec2 delete-snapshot --profile \"$AWS_PROFILE\" --region \"$AWS_REGION\" --snapshot-id $sid >/dev/null 2>&1"
            confirm_and_delete "$prompt" "$delete_cmd" "SNAPSHOT" "$sid"
        fi
    fi
done < "$TMP_DIR/snapshots_list_${TIMESTAMP}.tsv"

# -------------------------
# 8) ENI orphan (available) - delete optional
# -------------------------
echo "Scanning ENIs in 'available' state..."
enis=$(aws ec2 describe-network-interfaces --profile "$AWS_PROFILE" --region "$AWS_REGION" --filters Name=status,Values=available 2>/dev/null)
eni_ids=$(echo "$enis" | jq -r '.NetworkInterfaces[]?.NetworkInterfaceId' 2>/dev/null || true)
for eni in $eni_ids; do
    meta=$(echo "$enis" | jq -r --arg id "$eni" '.NetworkInterfaces[] | select(.NetworkInterfaceId==$id)')
    create_time=$(echo "$meta" | jq -r '.Attachment.CreateTime // empty')
    age=$(age_days "$create_time")
    name_tag=$(echo "$meta" | jq -r '.TagSet[]? | select(.Key=="Name") | .Value' 2>/dev/null || echo "")
    [ -z "$name_tag" ] && name_tag="$NAME_FALLBACK"
    details=$(echo "$meta" | jq -r '{SubnetId: .SubnetId, VpcId: .VpcId} | to_entries | map("\(.key)=\(.value)") | join(";")')
    cnt_eni_orphan=$((cnt_eni_orphan+1))
    hint="Investigate and delete if unused"
    printf "%s,ENI,%s,%s,available,%s,%s,%s,%s\n" "$DATE_ISO" "$eni" "$name_tag" "$AWS_REGION" "$age" "$details" "$hint" >> "$ENI_CSV"
    if [ "$DO_DELETE" = true ]; then
        prompt="Delete orphan ENI $eni (Name=$name_tag, Age=${age}d)?"
        delete_cmd="aws ec2 delete-network-interface --profile \"$AWS_PROFILE\" --region \"$AWS_REGION\" --network-interface-id $eni >/dev/null 2>&1"
        confirm_and_delete "$prompt" "$delete_cmd" "ENI" "$eni"
    fi
done

# -------------------------
# 9) Security Groups unused
# -------------------------
echo "Scanning Security Groups for unused (no ENI attachments)..."
used_sgs=$(aws ec2 describe-network-interfaces --profile "$AWS_PROFILE" --region "$AWS_REGION" 2>/dev/null | jq -r '.NetworkInterfaces[]?.Groups[]?.GroupId' 2>/dev/null || true)
aws ec2 describe-security-groups --profile "$AWS_PROFILE" --region "$AWS_REGION" 2>/dev/null \
    | jq -c '.SecurityGroups[]? | {GroupId:.GroupId,GroupName:.GroupName,Description:.Description,Tags:.Tags}' > "$TMP_DIR/all_sgs_${TIMESTAMP}.json"

declare -A used_map
for id in $used_sgs; do used_map["$id"]=1; done

while read -r sg_json; do
    gid=$(echo "$sg_json" | jq -r '.GroupId')
    gname=$(echo "$sg_json" | jq -r '.GroupName')
    gdesc=$(echo "$sg_json" | jq -r '.Description' | sed 's/,/ /g')
    has_donotdelete=$(echo "$sg_json" | jq -r '.Tags[]? | select(.Key=="DoNotDelete") | .Value' 2>/dev/null || echo "")
    [ -z "$gname" ] && gname="$NAME_FALLBACK"
    if [ -z "${used_map[$gid]:-}" ]; then
        if [ "$gname" = "default" ] || [ "$has_donotdelete" = "true" ]; then
            continue
        fi
        cnt_sg_unused=$((cnt_sg_unused+1))
        hint="Review before delete; ensure no references in templates"
        printf "%s,SG,%s,%s,unused,%s,%s,%s,%s\n" "$DATE_ISO" "$gid" "$gname" "$AWS_REGION" "NA" "$gdesc" "$hint" >> "$SG_CSV"
        if [ "$DO_DELETE" = true ]; then
            prompt="Delete unused Security Group $gid (Name=$gname)?"
            delete_cmd="aws ec2 delete-security-group --profile \"$AWS_PROFILE\" --region \"$AWS_REGION\" --group-id $gid >/dev/null 2>&1"
            confirm_and_delete "$prompt" "$delete_cmd" "SG" "$gid"
        fi
    fi
done < "$TMP_DIR/all_sgs_${TIMESTAMP}.json"

# -------------------------
# Summary logging
# -------------------------
SUMMARY_LINE="[$(date +"%Y-%m-%d %H:%M:%S")] profile=${AWS_PROFILE} region=${AWS_REGION} stopped_instances=${cnt_stopped_instances} idle_instances=${cnt_idle_instances} unattached_volumes=${cnt_unattached_vols} unused_eips=${cnt_unused_eips} orphan_enis=${cnt_eni_orphan} elb_zero_targets=${cnt_elb_zero} rds_idle=${cnt_rds_idle} snapshots_old=${cnt_snap_old} sg_unused=${cnt_sg_unused}"
echo "$SUMMARY_LINE" >> "$SUMMARY_LOG"

# console output
echo "Audit completed."
echo "Summary: $SUMMARY_LINE"
echo "Reports generated under: $REPORT_DIR"
echo "Summary log: $SUMMARY_LOG"
if [ -f "$DELETION_AUDIT" ]; then
    echo "Deletion audit log: $DELETION_AUDIT"
fi

exit 0

