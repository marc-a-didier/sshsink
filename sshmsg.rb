#!/usr/bin/env ruby

require 'socket'

TCPSocket.new('127.0.0.1', 22).sendmsg(ARGV[0])
