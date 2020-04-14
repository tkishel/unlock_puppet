#!/opt/puppetlabs/puppet/bin/ruby

# unlock_puppet/tasks/init.rb and unlock_puppet/files/unlock_puppet.rb are similar,
# except that the task does not interact with the pxp-agent service, and raises errors,
# and the script does not read JSON from STDIN.

require 'json'
require 'facter'
require 'puppet'

####

def read_params
  options = {}
  script = true
  if script == true
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
      opts.on('--force_service', 'Force a restart of the puppet and pxp-agent service') do
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

def puppet_binary
  (Facter.value(:os)['family'] == 'windows') ? 'puppet' : '/opt/puppetlabs/bin/puppet'
end

def write_log(message)
  message.tr!('"', "'")
  if Facter.value(:os)['family'] == 'windows'
    `powershell.exe " If ([System.Diagnostics.EventLog]::SourceExists(\"Unlock Puppet\") -eq $False) { New-EventLog -Source \"Unlock Puppet\" -LogName Application } "`
    `powershell.exe " Write-EventLog -Source \"Unlock Puppet\" -LogName Application -EntryType Information -EventID 1234 -Message \"unlock_puppet: #{message}\" "`
  else
    `logger -p local3.info "#{message}"`
  end
end

def kill_process(pid)
  return if pid.zero?
  if Facter.value(:os)['family'] == 'windows'
    `taskkill /f /pid #{pid}`
  else
    `kill -9 #{pid}`
  end
end

def start_service(service)
  `#{puppet_binary} resource service #{service} ensure=running`
  $?
end

def stop_service(service)
  if Facter.value(:os)['family'] == 'windows'
    result = `SC QUERY #{service} | FIND "STATE"`
    if $?.exitstatus.zero?
      service_state = result.split(' ').last.chomp
      if service_state == 'START_PENDING' || service_state == 'STOP_PENDING'
        result = `SC QUERYEX #{service} | FIND "PID"`
        if $?.exitstatus.zero?
          service_pid = result.split(' ').last.chomp.to_i
          if service_pid > 0
            kill_process(service_pid)
            return $?
          end
        end
      end
    end
    `SC STOP #{service}`
  else
    `#{puppet_binary} resource service #{service} ensure=stopped`
  end
  $?
end

def service_status(service)
  `#{puppet_binary} resource service #{service}`
end

def service_enabled(status)
  status.downcase.include?('true')
end

def service_running(status)
  status.downcase.include?('running')
end

####

begin
  report << 'checking puppet agent process, and puppet and pxp-agent services'

  if force_service
    report << 'stopping puppet service'
    stop_service('puppet')
    report << 'stopping pxp-agent service'
    stop_service('pxp-agent')
  end

  if File.file?(lockfile)
    run_pid = File.read(lockfile).to_i
    if force_process
      report << 'killing puppet agent process'
      kill_process(run_pid)
      if File.file?(lockfile)
        report << 'deleting puppet agent process lock file'
        File.delete(lockfile) if File.file?(lockfile)
        report << 'unable to delete puppet agent process lock file' if File.file?(lockfile)
      end
    else
      lockfile_age = (Time.now - File.stat(lockfile).mtime).to_i
      if lockfile_age > [runinterval, runtimeout].max
        report << "puppet agent process lock file age #{lockfile_age} exceeds runinterval #{runinterval} or runtimeout #{runtimeout}"
        report << 'killing puppet agent process'
        kill_process(run_pid)
        if File.file?(lockfile)
          report << 'deleting puppet agent process lock file'
          File.delete(lockfile) if File.file?(lockfile)
          report << 'unable to delete puppet agent process lock file' if File.file?(lockfile)
        end
      end
    end
  end

  puppet_service_status = service_status('puppet')
  pxp_agent_service_status = service_status('pxp-agent')

  if force_service
    report << 'starting puppet service'
    command = start_service('puppet')
    report << 'unable to start puppet service' unless command.exitstatus.zero?
    report << 'starting pxp-agent service'
    command = start_service('pxp-agent')
    report << 'unable to start pxp-agent service' unless command.exitstatus.zero?
  else
    # Puppet Service
    if service_enabled(puppet_service_status)
      if service_running(puppet_service_status)
        if File.file?(lastrunreport)
          lastrunreport_age = (Time.now - File.stat(lastrunreport).mtime).to_i
          # Either [runinterval, runtimeout].max or runinterval
          if lastrunreport_age > [runinterval, runtimeout].max
            report << "last run report age #{lastrunreport_age} exceeds runinterval #{runinterval} or runtimeout #{runtimeout}"
            report << 'stopping puppet service'
            stop_service('puppet')
            report << 'starting puppet service'
            command = start_service('puppet')
            report << 'unable to start puppet service' unless command.exitstatus.zero?
          end
        else
          report << 'last run report absent'
          report << 'stopping puppet service'
          stop_service('puppet')
          report << 'starting puppet service'
          command = start_service('puppet')
          report << 'unable to start puppet service' unless command.exitstatus.zero?
        end
      else
        # status = puppet_service_status.match(/ensure.*?,/m).to_s.split("'")[1]
        # report << "puppet service status: #{status}"
        report << 'puppet service not running'
        report << 'stopping puppet service'
        stop_service('puppet')
        report << 'starting puppet service'
        command = start_service('puppet')
        report << 'unable to start puppet service' unless command.exitstatus.zero?
      end
    end
    # PXP Agent Service
    if service_enabled(pxp_agent_service_status)
      unless service_running(pxp_agent_service_status)
        # status = pxp_agent_service_status.match(/ensure.*?,/m).to_s.split("'")[1]
        # report << "pxp-agent service status: #{status}"
        report << 'pxp-agent service not running'
        report << 'stopping pxp-agent service'
        stop_service('pxp-agent')
        report << 'starting pxp-agent service'
        command = start_service('pxp-agent')
        report << 'unable to start pxp-agent service' unless command.exitstatus.zero?
      end
    end
  end

  # To enable notifications, create unlock_notify.rb in this directory, containing a unlock_notify(result) method.
  # The unlock_notify(result) method must accept one parameter: the 'result' hash.
  notify_library = File.join(__dir__, 'unlock_notify.rb')
  if File.file?(notify_library)
    require notify_library
  end

  result['status'] = 'success'
  unlock_notify(result) if defined?(unlock_notify)
  result['result'] = report.join(', ')
  puts result.to_json
  exit 0
rescue StandardError => e
  result['status'] = 'failure'
  result['result'] = "ENV: #{ENV.inspect}"
  unlock_notify(result) if defined?(unlock_notify)
  result['_error'] = { msg: e.message, kind: 'service/unlock_puppet', details: {} }
  puts result.to_json
  exit 1
end
