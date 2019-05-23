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
        @addrs = File.exists?(STATE_FILE) ? JSON.parse(IO.read(STATE_FILE)) : {}
    end

    def save_state
        @mutex.synchronize { IO.write(STATE_FILE, JSON.pretty_generate(@addrs.sort { |e1, e2| e2[1] <=> e1[1] }.to_h)) }
    end

    def leave
        @leave = true
    end

    def run
        log = Logger.new('./sshsink.log', 20, 20*1024*1024)
        log.info('SSHsink started listening on port 22')
        msgs = JSON.parse(IO.read(MSGS_FILE))
        tcp_server = TCPServer.new('0.0.0.0', 22)
        begin
            while !@leave do
                Thread.start(tcp_server.accept) do |sock|
                    begin
                        retries = 0
                        begin
                            log.info("--> #{sock.peeraddr}")
                            msg = sock.recv_nonblock(32000).chomp.scrub
                            log.info(msg)
                        rescue IO::WaitReadable
                            IO.select([sock], nil, nil, 10)
                            (retries += 1) < 6 ? retry : log.info("Too much retries, leaving wait readable loop for ip #{sock.peeraddr.last}")
                        end
                        if sock.peeraddr.last.match(/^127|^192\.168/)
                            self.send(msgs[msg]) if msgs[msg] && self.respond_to?(msgs[msg])
                        else
                            sock.puts(msgs['Welcome'])
                            @mutex.synchronize do
                                if @addrs[sock.peeraddr.last]
                                    log.info("--- Skipping counter strike against #{sock.peeraddr.last}")
                                    @addrs[sock.peeraddr.last] += 1
                                else
                                    @addrs[sock.peeraddr.last] = 1
                                    log.info("+++ Launching counter strike against #{sock.peeraddr.last}")
                                    Process.detach(Process.fork { Process.exec("./sshcounterstrike.rb #{sock.peeraddr.last}") })
                                end
                            end
                        end
                        sock.close
                    rescue Errno::ECONNRESET, Errno::ENOTCONN, Errno::EPIPE
                        log.info("*** Connection lost")
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
