#!/bin/bash
# Cron Job Monitoring Script
# Description: Monitors execution of security cron jobs

MONITOR_LOG="/var/log/cron_monitor.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# Function to log messages
log_message() {
 echo "[$DATE] $1" | tee -a "$MONITOR_LOG"
}

# Function to check if cron service is running
check_cron_service() {
 log_message "Checking cron service status..."

 if systemctl is-active --quiet crond; then
 log_message "Cron service is running"
 return 0
 elif systemctl is-active --quiet cron; then
 log_message "Cron service is running"
 return 0
 else
 log_message "ERROR: Cron service is not running!"
 return 1
 fi
}

# Function to verify cron jobs are scheduled
verify_cron_jobs() {
 log_message "Verifying security cron jobs..."

 CRON_COUNT=$(crontab -l 2>/dev/null | grep -c "security-scripts")

 if [ "$CRON_COUNT" -gt 0 ]; then
 log_message "Found $CRON_COUNT security cron jobs"
 crontab -l | grep "security-scripts" | while read line; do
 log_message "Scheduled: $line"
 done
 else
 log_message "WARNING: No security cron jobs found!"
 fi
}

# Function to check recent executions
check_recent_executions() {
 log_message "Checking recent cron executions..."

 # Check various log locations for cron execution
 if [ -f /var/log/cron ]; then
 RECENT_RUNS=$(grep "security-scripts" /var/log/cron | tail -5)
 elif [ -f /var/log/syslog ]; then
 RECENT_RUNS=$(grep "CRON.*security-scripts" /var/log/syslog | tail -5)
 else
 log_message "Cron logs not found"
 return
 fi

 if [ -n "$RECENT_RUNS" ]; then
 log_message "Recent executions:"
 echo "$RECENT_RUNS" | tee -a "$MONITOR_LOG"
 else
 log_message "No recent executions found"
 fi
}

# Function to check log file sizes and rotation
check_log_files() {
 log_message "Checking security log files..."

 LOG_FILES=("/var/log/security_audit.log" "/var/log/port_security.log" "/var/log/patch_management.log")

 for logfile in "${LOG_FILES[@]}"; do
 if [ -f "$logfile" ]; then
 SIZE=$(du -h "$logfile" | cut -f1)
 LINES=$(wc -l < "$logfile")
 log_message "$logfile: Size=$SIZE, Lines=$LINES"

 # Check if log file is getting too large
 SIZE_BYTES=$(stat -c%s "$logfile")
 if [ "$SIZE_BYTES" -gt 10485760 ]; then # 10MB
 log_message "WARNING: $logfile is larger than 10MB"
 fi
 else
 log_message "Log file not found: $logfile"
 fi
 done
}

# Function to generate monitoring report
generate_report() {
 REPORT_FILE="/var/log/cron_monitoring_report.txt"

 {
 echo "Cron Job Monitoring Report"
 echo "========================="
 echo "Generated: $DATE"
 echo

 echo "Cron Service Status:"
 systemctl status crond 2>/dev/null || systemctl status cron 2>/dev/null
 echo

 echo "Scheduled Security Jobs:"
 crontab -l 2>/dev/null | grep "security-scripts" || echo "None found"
 echo

 echo "Recent Security Script Executions:"
 if [ -f /var/log/master_security.log ]; then
 tail -10 /var/log/master_security.log
 else
 echo "No execution logs found"
 fi

 } > "$REPORT_FILE"

 log_message "Monitoring report generated: $REPORT_FILE"
}

# Main execution
main() {
 log_message "=== Cron Monitoring Started ==="

 check_cron_service
 verify_cron_jobs
 check_recent_executions
 check_log_files
 generate_report

 log_message "=== Cron Monitoring Completed ==="
}

# Execute main function
main
