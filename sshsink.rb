#!/usr/bin/env ruby

require 'socket'
require 'thread'
require 'json'
require 'logger'

STATE_FILE = './sshsink.state.json'
MSGS_FILE = './sshsink.msgs.json'

class SSHSink

    def initialize
        @leave = nil
        @mutex = Mutex.new
        @addrs = File.exist?(STATE_FILE) ? JSON.parse(IO.read(STATE_FILE)) : {}
        @last_time_saved = Time.now.to_i
    end

    def save_state
        @mutex.synchronize { IO.write(STATE_FILE, JSON.pretty_generate(@addrs.sort { |e1, e2| e2[1] <=> e1[1] }.to_h)) }
        @last_time_saved = Time.now.to_i
    end

    def leave
        @leave = true
    end

    def run
        port = 2222
        launch_cs = ARGV[0] ? !ARGV[0].match?(/no.*/i) : true
        log = Logger.new('./sshsink.log', 80, 100*1024*1024)
        log.info("SSHsink started listening on port #{port} - Counter strike flag is #{launch_cs}")
        msgs = JSON.parse(IO.read(MSGS_FILE))
        tcp_server = TCPServer.new('0.0.0.0', port)
        begin
            while !@leave do
                Thread.start(tcp_server.accept) do |sock|
                    begin
                        retries = 0
                        raddr = sock.peeraddr.last
                        attempt = @addrs[raddr] || 0
                        is_local = raddr.match?(/^127|^192\.168/)
                        log.info(is_local ? "--> Message from #{raddr}" : "--> #{sock.peeraddr} : Attempt #{attempt+1}")
                        begin
                            msg = sock.recv_nonblock(32000).gsub(/[^ -~]/, '_')
                        rescue IO::WaitReadable
                            IO.select([sock], nil, nil, 10)
                            (retries += 1) < 6 ? retry : log.info("Too much retries, leaving wait readable loop for ip #{raddr}")
                        end
                        log.info(msg) if msg && !msg.empty?
                        if is_local
                            self.send(msgs[msg]) if msgs[msg] && self.respond_to?(msgs[msg])
                        else
                            sock.puts(msgs['Welcome'])
                            @mutex.synchronize do
                                if @addrs[raddr]
                                    @addrs[raddr] += 1
                                    log.info("--- Skipping counter strike against #{raddr} (attempt #{@addrs[raddr]})") if launch_cs
                                else
                                    @addrs[raddr] = 1
                                    if launch_cs
                                        log.info("+++ Launching counter strike against #{raddr}")
                                        Process.detach(Process.fork { Process.exec("./sshcounterstrike.rb #{raddr}") })
                                    end
                                end
                            end
                            save_state if Time.now.to_i-@last_time_saved > 3600
                        end
                        sock.close
                        log.info("Closed connection from #{raddr}")
                    rescue SystemCallError => x7
                        log.info(raddr + ': ' + x7.inspect)
                    end
                end
            end
        rescue Interrupt
        end
        save_state
        log.info('Server shutdown')
    end
end

SSHSink.new.run
