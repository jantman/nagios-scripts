#!/usr/bin/ruby
#
# Dead-simple MCollective server check plugin for Nagios,
# using the discovery agent's ping feature.
#
# Note the arguments this plugins accepts do NOT conform to the
# Nagios/Monitoring Plugins specification, as MCollective::Client
# handles the option parsing for us, and injects the default set
# of options for all mco programs.
#
# The latest version of this script lives at:
# <https://github.com/jantman/nagios-scripts/blob/master/check_mco_ping.rb>
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

oparser = MCollective::Optionparser.new({}, "filter")

options = oparser.parse{|parser, options|
  parser.define_head "MCollective server ping check"
  parser.banner = "Usage: check_mco_ping.rb -H hostname/identity [--warning float] [--critical float] [options]"

  parser.on('--warning WARN', 'Warning if ping time greater than this number of milliseconds (float)') do |v|
    options[:warn] = v.to_f
  end

  parser.on('--critical WARN', 'Critical if ping time greater than this number of milliseconds (float)') do |v|
    options[:crit] = v.to_f
  end

  parser.on('-H', '--hostname HOST', 'hostname (identity/certname) to ping') do |v|
    options[:hostname] = v
  end
}

unless options.include?(:hostname)
  puts("UNKNOWN: -H|--hostname not specified")
  exit 3
end

warn_s = if options.include?(:warn) then sprintf("%.2f", options[:warn]) else "" end
crit_s = if options.include?(:crit) then sprintf("%.2f", options[:crit]) else "" end

duration = -1

before = Time.now.to_f
begin
  options[:filter]["agent"] = "discovery"
  options[:filter]["identity"] = options[:hostname]

  client = MCollective::Client.new(options[:config])

  start = Time.now.to_f
  stats = client.req("ping", "discovery", options) do |resp|
    next if resp == nil
    duration = (Time.now.to_f - start) * 1000
    break  
  end
rescue Exception => e
  duration = (Time.now.to_f - before) * 1000
  perfdata = sprintf("%.2fms;%s;%s;0", duration, warn_s, crit_s)
  printf("CRIT: mco timed out contacting %s at %.2f ms | %s\n", options[:hostname], duration, perfdata)
  puts("Error: #{e}\n")
  exit 2
end

if options.include?(:crit)
  if duration >= options[:crit]
    perfdata = sprintf("%.2fms;%s;%s;0", duration, warn_s, crit_s)
    printf("CRIT: mco ping %.2f ms to %s (>= %.2f) | %s\n", duration, options[:hostname], options[:crit], perfdata)
    exit 2
  end
end

if options.include?(:warn)
  if duration >= options[:warn]
    perfdata = sprintf("%.2fms;%s;%s;0", duration, warn_s, crit_s)
    printf("WARN: mco ping %.2f ms to %s (>= %.2f) | %s\n", duration, options[:hostname], options[:warn], perfdata)
    exit 1
  end
end

perfdata = sprintf("%.2fms;%s;%s;0", duration, warn_s, crit_s)
printf("OK: mco ping %.2f ms to %s | %s\n", duration, options[:hostname], perfdata)
exit 0
