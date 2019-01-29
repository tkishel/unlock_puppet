# Configure a cron or scheduled task to keep the puppet agent service running.
#
# @summary Keep the puppet agent service running.

class unlock_puppet {

  $posix_script   = '/opt/puppetlabs/puppet/bin/unlock_puppet.rb'
  $windows_batch  = 'C:/ProgramData/PuppetLabs/puppet/unlock_puppet.bat'
  $windows_script = 'C:/ProgramData/PuppetLabs/puppet/unlock_puppet.rb'

  if ($facts['os']['family'] == 'windows') {
    file { 'unlock puppet batch':
      path   => $windows_batch,
      source => 'puppet:///modules/unlock_puppet/unlock_puppet.bat',
      mode   => '0755'
    }
    $unlock_puppet_script = $windows_script
    scheduled_task { 'unlock puppet':
      command => $windows_batch,
      trigger => { schedule   => 'daily', start_time => '04:00' },
      require => [ File['unlock puppet batch'], File['unlock puppet script']],
    }
  } else {
    $unlock_puppet_script = $posix_script
    cron { 'unlock puppet':
      command => $unlock_puppet_script,
      user    => 'root',
      hour    => '4',
      minute  => '0',
      require => File['unlock puppet script'],
    }
  }
  file { 'unlock puppet script':
    path   => $unlock_puppet_script,
    source => 'puppet:///modules/unlock_puppet/unlock_puppet.rb',
    mode   => '0755'
  }
}
