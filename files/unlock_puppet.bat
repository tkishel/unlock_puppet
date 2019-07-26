@echo off
SETLOCAL

call "C:\Program Files\Puppet Labs\Puppet\bin\environment.bat"

ruby.exe C:\ProgramData\PuppetLabs\puppet\unlock_puppet.rb
