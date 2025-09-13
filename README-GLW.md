# GLW Deployment and Batch Job Guide

This guide explains how to deploy the GLW metadata to a Salesforce org and how to run/schedule the overdue orders batch process.

## Prerequisites

- Salesforce CLI installed (`sf` or legacy `sfdx`).
- Authorized default org (e.g., `sf org login web -d -a myOrg`).

## Deploy the Source

Using the new `sf` CLI:

```
sf project deploy start -d force-app -w 10
```

Using legacy `sfdx` CLI:

```
sfdx force:source:deploy -p force-app -w 10
```

## Run the Overdue Orders Batch (One-Time)

From the CLI (runs in the default org):

```
sf apex run --code "Database.executeBatch(new GLW_OverdueOrderBatch(), 200);" -w 10
```

Legacy `sfdx` equivalent:

```
sfdx force:apex:execute -f - <<'EOF'
Database.executeBatch(new GLW_OverdueOrderBatch(), 200);
EOF
```

Notes:

- The scope size is optional; default is 200. You can adjust it based on volume.

## Schedule the Batch to Run Daily

Option 1 — via Setup UI:

- Setup → Apex Classes → Schedule Apex → New
- Job Name: `GLW Daily Overdue Orders`
- Apex Class: `GLW_OverdueOrderScheduler`
- Frequency: Daily, choose a time

Option 2 — programmatically (Execute Anonymous):

```
System.schedule(
    'GLW Daily Overdue Orders',
    GLW_OverdueOrderScheduler.dailyCron(2, 0),
    new GLW_OverdueOrderScheduler()
);
```

This example runs daily at 02:00 org time. Adjust hour/minute as needed.

## Monitor and Manage Jobs

- Monitor: Setup → Apex Jobs
- Unschedule: Setup → Scheduled Jobs (Delete) or via Apex:

```
// Replace with the Id of the scheduled job
System.abortJob('707xxxxxxxxxxxx');
```

## Related Files (for reference)

- Batch: `force-app/main/default/classes/GLW_OverdueOrderBatch.cls`
- Scheduler: `force-app/main/default/classes/GLW_OverdueOrderScheduler.cls`
- Overdue flag field: `force-app/main/default/objects/GLW_Order__c/fields/GLW_FlagOverdue__c.field-meta.xml`

## Troubleshooting

- Ensure your default org is set (`sf org list --all`) and authenticated.
- If deploy fails, try deploying only changed paths first and review the CLI error for missing dependencies.
- Check Apex Jobs for failures and open the job’s debug log for details.

