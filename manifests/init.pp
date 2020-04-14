# Unlock a locked Puppet Service

class unlock_puppet (
  Enum[present, absent] $ensure = present,
) {

  $posixes_script = '/opt/puppetlabs/puppet/bin/unlock_puppet.rb'
  $windows_script = 'C:/ProgramData/PuppetLabs/puppet/unlock_puppet.rb'
  $windows_batch  = 'C:/ProgramData/PuppetLabs/puppet/unlock_puppet.bat'

  if ($facts['os']['family'] == 'windows') {
    $unlock_puppet_script = $windows_script
  } else {
    $unlock_puppet_script = $posixes_script
  }

  file { 'unlock puppet script':
    ensure => $ensure,
    path   => $unlock_puppet_script,
    source => 'puppet:///modules/unlock_puppet/unlock_puppet.rb',
    mode   => '0755'
  }

  if ($facts['os']['family'] == 'windows') {
    file { 'unlock puppet batch script':
      ensure => $ensure,
      path   => $windows_batch,
      source => 'puppet:///modules/unlock_puppet/unlock_puppet.bat',
      mode   => '0755'
    }
    scheduled_task { 'unlock puppet':
      ensure  => $ensure,
      command => $windows_batch,
      trigger => {
        schedule         => 'daily',
        start_time       => '04:15',
        minutes_interval => '60',
        minutes_duration => '720',
      },
      require => [ File['unlock puppet batch script'], File['unlock puppet script']],
    }
  } else {
    cron { 'unlock puppet':
      ensure  => $ensure,
      command => $unlock_puppet_script,
      user    => 'root',
      hour    => '*',
      minute  => '15',
      require => File['unlock puppet script'],
    }
  }

}
