#!/usr/bin/ruby
#
# MCollective-based plugin to check that puppet agent on a specified
# node is not disabled, and either is or is not running.
#
# Note the arguments this plugins accepts do NOT conform to the
# Nagios/Monitoring Plugins specification, as MCollective::Client
# handles the option parsing for us, and injects the default set
# of options for all mco programs.
#
# The latest version of this script lives at:
# <https://github.com/jantman/nagios-scripts/blob/master/check_puppet_agent_mco.rb>
#
# Please file bug/feature requests and submit patches through
# the above GitHub repository. Feedback and patches are greatly
# appreciated; patches are preferred as GitHub pull requests, but
# emailed patches are also accepted.
#
# Copyright 2014 Jason Antman <jason@jasonantman.com> all rights reserved.
#  See the above git repository's LICENSE file for license terms (GPLv3).
#

require 'mcollective'

include MCollective::RPC

options = rpcoptions do |parser, options|
  parser.define_head "MCollective puppet agent status check"
  parser.banner = "Usage: check_puppet_agent_mco.rb -H hostname [--daemon] [options]"

  parser.on('--daemon', 'Daemon should be running. Default is daemon should be stopped.') do |v|
    options[:daemon] = v
  end

  parser.on('-H', '--hostname HOST', 'hostname (identity/certname) to check') do |v|
    options[:hostname] = v
  end
end

unless options.include?(:hostname)
  puts("UNKNOWN: -H|--hostname not specified")
  exit! 3
end

r = nil
begin
  mc = rpcclient("puppet", :options => options)
  mc.progress = false
  mc.identity_filter options[:hostname]

  mc.status.each do |resp|
    r = resp
    break
  end
rescue Exception => e
  printf("CRITICAL: mco received error '%s' trying to contact %s\n", e, options[:hostname])
  exit 2
end

if r.nil?
  printf("UNKNOWN: mcollective timed out querying status for puppet on %s\n", options[:hostname])
  exit 3
end

# ok, we got a valid result back, check it
if r[:statuscode] == 1
  printf("CRITICAL: could not determine puppet agent status on %s\n", options[:sender])
  exit 2
end

if r[:statuscode] != 0
  printf("UNKNOWN: could not execute mcollective puppet status command on %s\n", options[:hostname])
  exit 3
end

if not r[:data][:enabled]
  foo = ""
  if r[:data][:disable_message] != ""
    foo = sprintf("('%s') ", r[:data][:disable_message])
  end
  printf("CRITICAL: puppet agent disabled %son %s (%s)\n", foo, r[:sender], r[:data][:message])
  exit 2
end

if options[:daemon] and not r[:data][:daemon_present]
  printf("CRITICAL: puppet daemon not running on %s (%s)\n", r[:sender], r[:data][:message])
  exit 2
elsif not options[:daemon] and r[:data][:daemon_present]
  printf("CRITICAL: puppet daemon running on %s (%s)\n", r[:sender], r[:data][:message])
  exit 2
end

printf("OK: puppet %s (%s)\n", r[:data][:message], r[:sender])
exit 0
