@echo off
SETLOCAL

call "C:\Program Files\Puppet Labs\Puppet\bin\environment.bat"

"C:\Program Files\Puppet Labs\Puppet\sys\ruby\bin\ruby.exe" C:\ProgramData\PuppetLabs\puppet\unlock_puppet.rb

