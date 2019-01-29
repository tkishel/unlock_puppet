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

This is valuable when a puppet agent process is locked or the puppet service needs to be started or restarted.

## Usage

Install the module.

Use the `puppet task run` command, specifying the task and the nodes you need to unlock:

```bash
puppet task run unlock_puppet --nodes agent.example.com
```

```bash
[root@pe-master]# puppet task run unlock_puppet --nodes agent.example.com
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

## Reference

### Parameters

#### delete

Boolean, default: false

Ignore `runtimeout` or `runinterval` and kill the puppet agent process and delete its lock file.

#### restart

Boolean, default: false

Ignore `runtimeout` or `runinterval` and restart the puppet service.

```bash
[root@pe-master]# puppet task run unlock_puppet --nodes agent.example.com delete=true restart=true
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

The script executed by the task can be run locally on the command line:

```bash
[root@pe-master]# unlock_puppet.rb
{"status":"success","result":"unlocking puppet service, runtime 86400 exceeds runtimeout 3600 or runinterval 1800, killing puppet agent process, deleting lock file"}
```

Specify task parameters via command line options:

```bash
[root@pe-master]# unlock_puppet.rb --delete --restart
{"status":"success","result":"unlocking puppet service, stopping puppet service, killing puppet agent process, deleting lock file, starting puppet service"}
```

The script can be scheduled via a cron job or scheduled task:

```puppet
node 'pe-agent' {
  include unlock_puppet
}
```

This is valuable as a preventive measure, to reset puppet on problem nodes ... until you resolve the root cause.

## Getting Help

To show help for tasks, run `puppet task run --help`
