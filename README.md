# unlock_puppet task

#### Table of Contents

1. [Description](#description)
1. [Usage - Basic](#usage)
1. [Reference - Parameters](#reference)
1. [Alternate Usage](#alternate-usage)
1. [Getting Help - With Tasks](#getting-help)

## Description

This module provides the `unlock_puppet` task.

This task allows you unlock puppet agent runs exceeding the configured `runtimeout` or `runinterval`.

This is valuable when a puppet agent process is locked, and/or the puppet service needs to be started or restarted.

## Usage

Install the module.

Use the `puppet task run` command, specifying the task and the nodes you need to unlock:

```bash
puppet task run unlock_puppet --nodes agent.example.com
```

```bash
[root@master]# puppet task run unlock_puppet --nodes agent.example.com
Starting job ...
Note: The task will run only on permitted nodes.
New job ID: 1
Nodes: 1

Started on agent.example.com ...
Finished on node agent.example.com
  result : unlocking puppet service, runtime 86400 exceeds runtimeout 3600 or runinterval 1800, killing puppet agent process, deleting lock file
  status : success

Job completed. 1/1 nodes succeeded.
Duration: 1 sec
```

Rather than specifying the nodes directly via `--nodes` you could use `--query`:

```
# Calculate a `not-responding` datestamp
export CUTOFF_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ" -d "-$(puppet config print runinterval) seconds")

# Validate the datestamp using `puppet query`:
date
echo $CUTOFF_DATE
puppet query "nodes { report_timestamp < '$CUTOFF_DATE' }"

# Run the task with the query
puppet task run unlock_puppet --query "nodes { report_timestamp < '$CUTOFF_DATE' }"
```

## Reference

### Parameters

#### delete

Boolean, default: false

Ignore `runtimeout` or `runinterval`, kill the puppet agent process, and delete its lock file.

#### restart

Boolean, default: false

Ignore `runtimeout` or `runinterval`, and restart the puppet service.

```bash
[root@master]# puppet task run unlock_puppet --nodes agent.example.com delete=true restart=true
Starting job ...
Note: The task will run only on permitted nodes.
New job ID: 2
Nodes: 1

Started on agent.example.com ...
Finished on node agent.example.com
  result : unlocking puppet service, stopping puppet service, killing puppet agent process, deleting lock file, starting puppet service
  status : success

Job completed. 1/1 nodes succeeded.
Duration: 4 sec
```

## Alternate Usage

The script executed by this task can be extracted from this module and run locally on the command line:

```bash
[root@agent]# /usr/local/bin/unlock_puppet.rb
{"status":"success","result":"unlocking puppet service, runtime 86400 exceeds runtimeout 3600 or runinterval 1800, killing puppet agent process, deleting lock file"}
```

The script accepts the same parameters as the task via the following command line options:

```bash
[root@agent]# /usr/local/bin/unlock_puppet.rb --delete --restart
{"status":"success","result":"unlocking puppet service, stopping puppet service, killing puppet agent process, deleting lock file, starting puppet service"}
```

Executing the script in a cron job (or scheduled task) can be a valuable preventive measure to keep Puppet running on problem nodes ... until you identify and resolve the root cause of Puppet agent runs locking, and/or the Puppet service stopping.

```
0 4 * * * /usr/local/bin/unlock_puppet.rb
```

## Getting Help

To show help for tasks, run `puppet task run --help`
