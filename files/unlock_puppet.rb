#!/opt/puppetlabs/puppet/bin/ruby

# unlock_puppet/tasks/init.rb and unlock_puppet/files/unlock_puppet are identical

require 'json'
require 'facter'
require 'puppet'

####

def read_params
  options = {}
  begin
    Timeout.timeout(2) do
      options = JSON.parse(STDIN.read)
    end
  rescue Timeout::Error
    require 'optparse'
    options['force_process'] = 'false'
    options['force_service'] = 'false'
    parser = OptionParser.new do |opts|
      opts.banner = 'Usage: unlock_puppet.rb [options]'
      opts.separator ''
      opts.separator 'Summary: Unlock puppet agent runs exceeding runinterval or runtimeout'
      opts.separator ''
      opts.separator 'Options:'
      opts.separator ''
      opts.on('--force_process', 'Force a kill of the puppet agent process, and delete its lock file') do
        options['force_process'] = 'true'
      end
      opts.on('--force_service', 'Force a restart of the puppet service') do
        options['force_service'] = 'true'
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

force_process = params['force_process'] == 'true'
force_service = params['force_service'] == 'true'

Puppet.initialize_settings

lockfile      = Puppet[:agent_catalog_run_lockfile]
lastrunreport = Puppet[:lastrunreport]
runinterval   = Puppet[:runinterval] || 1800
runtimeout    = Puppet[:runtimeout]  || 1800

result = {}
report = []

####

def kill_process(run_pid)
  return if run_pid.zero?
  if Facter.value(:os)['family'] == 'windows'
    `taskkill /f /pid #{run_pid}`
  else
    `kill -9 #{run_pid}`
  end
  $?
end

def stop_service(service)
  `puppet resource service #{service} ensure=stopped`
  $?
end

def start_service(service)
  `puppet resource service #{service} ensure=running`
  $?
end

def service_status(service)
  `puppet resource service #{service}`
end

def service_enabled(status)
  status.include?('true')
end

def service_running(status)
  status.include?('running')
end

####

begin
  report << 'checking puppet agent process and service'

  if force_service
    report << 'stopping puppet service'
    stop_service('puppet')
  end

  if File.file?(lockfile)
    run_pid = File.read(lockfile).to_i
    if force_process
      report << 'killing puppet agent process'
      kill_process(run_pid)
      if File.file?(lockfile)
        report << 'deleting puppet agent process lock file'
        File.delete(lockfile) if File.file?(lockfile)
        raise StandardError('unable to delete puppet agent process lock file') if File.file?(lockfile)
      end
    else
      lockfile_age = (Time.now - File.stat(lockfile).mtime).to_i
      if lockfile_age > runinterval || lockfile_age > runtimeout
        report << "puppet agent process lock file age #{lockfile_age} exceeds runinterval #{runinterval} or runtimeout #{runtimeout}"
        report << 'killing puppet agent process'
        kill_process(run_pid)
        if File.file?(lockfile)
          report << 'deleting puppet agent process lock file'
          File.delete(lockfile) if File.file?(lockfile)
          raise StandardError('unable to delete puppet agent process lock file') if File.file?(lockfile)
        end
      end
    end
  end

  puppet_service_status = service_status('puppet')

  if force_service
    report << 'starting puppet service'
    command = start_service('puppet')
    raise StandardError('unable to start puppet service') unless command.exitstatus.zero?
  elsif service_enabled(puppet_service_status)
    if service_running(puppet_service_status)
      if File.file?(lastrunreport)
        lastrunreport_age = (Time.now - File.stat(lastrunreport).mtime).to_i
        if lastrunreport_age > runinterval
          report << "last run report age #{lastrunreport_age} exceeds runinterval #{runinterval}"
          report << 'stopping puppet service'
          stop_service('puppet')
          report << 'starting puppet service'
          command = start_service('puppet')
          raise StandardError('unable to start puppet service') unless command.exitstatus.zero?
        end
      else
        report << 'last run report absent'
        report << 'stopping puppet service'
        stop_service('puppet')
        report << 'starting puppet service'
        command = start_service('puppet')
        raise StandardError('unable to start puppet service') unless command.exitstatus.zero?
      end
    else
      report << 'puppet service not running'
      report << 'stopping puppet service'
      stop_service('puppet')
      report << 'starting puppet service'
      command = start_service('puppet')
      raise StandardError('unable to start puppet service') unless command.exitstatus.zero?
    end
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
