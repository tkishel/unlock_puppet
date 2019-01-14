#!/opt/puppetlabs/puppet/bin/ruby

require 'json'
require 'puppet'

def read_params
  options = {}
  begin
    Timeout.timeout(2) do
      options = JSON.parse(STDIN.read)
    end
  rescue Timeout::Error
    require 'optparse'
    options['delete'] = false
    options['restart'] = 'false'
    parser = OptionParser.new do |opts|
      opts.banner = 'Usage: unlock_puppet.rb [options]'
      opts.separator ''
      opts.separator 'Summary: Unlock puppet agent runs exceeding runtimeout or runinterva'
      opts.separator ''
      opts.separator 'Options:'
      opts.separator ''
      opts.on('--delete', 'Kill the puppet agent process and delete the lock file') do
        options['delete'] = 'true'
      end
      opts.on('--restart', 'Force a restart of the puppet service') do
        options['restart'] = 'true'
      end
      opts.on('-h', '--help', 'Display help') do
        puts opts
        puts
        exit 0
      end
    end
    parser.parse!
  end
  options
end

params = read_params

force_delete  = params['delete'] == 'true'
force_restart = params['restart'] == 'true'

Puppet.initialize_settings

lockfile      = Puppet[:agent_catalog_run_lockfile]
lastrunreport = Puppet[:lastrunreport]
runinterval   = Puppet[:runinterval] || 1800
runtimeout    = Puppet[:runtimeout]  || 1800

result = {}
report = []

def start_puppet_service
  `puppet resource service puppet ensure=running`
  $?
end

def stop_puppet_service
  `puppet resource service puppet ensure=stopped`
  $?
end

def stop_puppet_agent_process(run_pid)
  return if run_pid.zero?
  `kill -9 #{run_pid}`
  $?
end

begin
  report << 'unlocking puppet service'

  if force_delete || force_restart
    report << 'stopping puppet service'
    stop_puppet_service
  end

  if File.file?(lockfile)
    run_pid = File.read(lockfile).to_i
    if force_delete
      report << 'killing puppet agent process'
      stop_puppet_agent_process(run_pid)
      report << 'deleting lock file'
      File.delete(lockfile)
      raise Puppet::Error('unable to delete lock file') if File.file?(lockfile)
    else
      run_time = (Time.now - File.stat(lockfile).mtime).to_i
      if (run_time > runtimeout) || (run_time > runinterval)
        report << "runtime #{run_time} exceeds runtimeout #{runtimeout} or runinterval #{runinterval}"
        report << 'killing puppet agent process'
        stop_puppet_agent_process(run_pid)
        report << 'deleting lock file'
        File.delete(lockfile)
        raise Puppet::Error('unable to delete lock file') if File.file?(lockfile)
      end
    end
  else
    report << 'lock file absent'
  end

  runinterval_restart = false
  if File.file?(lastrunreport)
    lastrun = (Time.now - File.stat(lastrunreport).mtime).to_i
    if lastrun > runinterval
      report << "time since last run #{lastrun} exceeds runinterval #{runinterval}"
      runinterval_restart = true
    end
  else
    report << 'last run report absent'
  end

  if runinterval_restart || force_delete || force_restart
    report << 'starting puppet service'
    command = start_puppet_service
    raise Puppet::Error('unable to start puppet service') unless command.exitstatus.zero?
  end

  result['status'] = 'success'
  result['result'] = report.join(', ')
  puts result.to_json
  exit 0
rescue StandardError => e
  result['status'] = 'failure'
  result['result'] = "ENV: #{ENV.inspect}"
  result['_error'] = { msg: e.message, kind: 'service/unlock_puppet', details: {} }
  puts result.to_json
  exit 1
end
