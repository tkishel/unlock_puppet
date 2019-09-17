# unlock_puppet task

#### Table of Contents

1. [Description](#description)
1. [Setup](#setup)
1. [Usage - Basic](#usage)
1. [Reference - Parameters](#reference)
1. [Alternate Usage](#alternate-usage)
1. [Getting Help - With Tasks](#getting-help)

## Description

This module provides an `unlock_puppet` class and task that ...

* Kills `puppet agent` runs exceeding the maximum of `runinterval` or `runtimeout`.
* Restarts the `Puppet Agent` service (if it is enabled) if the last run report exceeds the maximum of `runinterval` or `runtimeout`.
* Restarts the `Puppet Agent` and/or `PXP Agent` service if it is not running.

This is valuable when a puppet agent process is locked, and/or the puppet or pxp-agent service needs to be restarted.

## Setup

* Install the module

## Usage

### Automated Enforcement

* Apply the `unlock_puppet` class to a node

```puppet
include unlock_puppet
```

The `unlock_puppet` class will create a cron job (or scheduled task) to resolve a locked `puppet agent` process, and/or a stopped `Puppet Agent` or `PXP Agent` service.

### Ad-Hoc Enforcement

The `unlock_puppet` task resolve a locked `puppet agent` process, and/or a stopped `Puppet Agent` service, but will not resolve a stopped `PXP Agent` service.

* Use the `puppet task run` command

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
  result : checking puppet agent process and service, puppet agent process lock file age 86400 exceeds runinterval 1800 or runtimeout 3600, killing puppet agent process, deleting puppet agent process lock file
  status : success

Job completed. 1/1 nodes succeeded.
Duration: 1 sec
```

Rather than specifying the nodes directly via `--nodes` you could use `--query` to query for nodes than have not reported within a cutoff:

```bash
# calculate a `not-responding` datestamp
export CUTOFF_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ" -d "-$(puppet config print runinterval) seconds")

# validate the datestamp using `puppet query`:
date
echo $CUTOFF_DATE
puppet query "nodes { report_timestamp < '$CUTOFF_DATE' }"

# run the task with the query
puppet task run unlock_puppet --query "nodes { report_timestamp < '$CUTOFF_DATE' }"
```

## Reference

### Class Parameters

Note that class parameter(s) are only necessary for resource-like class declarations, which are only necessary to uninstall the resources of this module.

#### ensure

Data type: String

This parameter is optional, with valid options of 'present' (the default) and 'absent'.

To uninstall the cron job (or scheduled task) apply the class using a resource-like class declaration:

```
class { 'unlock_puppet': ensure => absent }
```

### Task Parameters

#### force_agent

Boolean, default: false

Ignore `runinterval` and `runtimeout`, kill the puppet agent process, and delete its lock file.

#### force_service

Boolean, default: false

Ignore `runinterval` and `runtimeout`, and restart the puppet service (even if it is not enabled).

```bash
[root@master]# puppet task run unlock_puppet --nodes agent.example.com force_agent=true force_service=true
Starting job ...
Note: The task will run only on permitted nodes.
New job ID: 2
Nodes: 1

Started on agent.example.com ...
Finished on node agent.example.com
  result : checking puppet agent process and service, stopping puppet service, killing puppet agent process, deleting puppet agent process lock file, starting puppet service
  status : success

Job completed. 1/1 nodes succeeded.
Duration: 4 sec
```

## Alternate Usage

The script executed by this task can be extracted from the `files` directory of this module and run locally on the command line:

```bash
[root@agent]# /usr/local/bin/unlock_puppet.rb
{"status":"success","result":"checking puppet agent process and service, puppet agent process lock file age 86400 exceeds runinterval 1800 or runtimeout 3600, killing puppet agent process, deleting lock file"}
```

The script accepts the same parameters as the task via the following command line options:

```bash
[root@agent]# /usr/local/bin/unlock_puppet.rb --force_agent --force_service
{"status":"success","result":"checking puppet agent process and service, stopping puppet service, killing puppet agent process, deleting puppet agent process lock file, starting puppet service"}
```

## Getting Help

To show help for tasks, run `puppet task run --help`
