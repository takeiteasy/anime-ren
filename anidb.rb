#!/usr/bin/env ruby
require 'socket'
require 'thread'

AMASK      = "B0E0F040"
FMASK      = "7178EAC0"
SERV_ADDR  = "api.anidb.net"
SERV_PORT  = 9000

API_RESP = Struct.new :status, :msg
FILE_T   = Struct.new :file, :hash

class API
  attr_accessor :sock, :session_key

  def initialize user, pass
    @sock = UDPSocket.new
    @sock.bind 0, SERV_PORT
    @sock.connect SERV_ADDR, SERV_PORT
    a = exec "AUTH user=#{user}&pass=#{pass}&protover=3&client=aniren&clientver=2&enc=UTF8"
    if a.status == 200
      @session_key = a.msg.split(" ")[0]
    else
      exit
    end
  end

  def exec cmd
    puts "< #{cmd}"
    @sock.send(cmd, 0)
    msg    = @sock.recvfrom(1024)[0].split
    status = msg[0].to_i
    msg    = msg[1..-1].join " "
    puts "> #{status}: #{msg}"
    return API_RESP.new status, msg
  end

  def exit
    exec("LOGOUT s=#{@session_key}")
    @sock.close
    @sock = nil
  end
end

mtx = Mutex.new
secret = File.open("secret", "rb").read.split "\n"
#api    = API.new secret[0], secret[1]

at_exit do
  api.exit
end

file_arr, still_open = [], true
t = Thread.new {
  while file_arr.length > 0 or still_open
    if file_arr.length > 0
      f = file_arr.shift
      mtx.synchronize {
        puts "~ Processing \"#{f.file}\""
      }
    end
  end
}

while STDIN.gets
  if $_ =~ /^(\/.+)+\.(.+){3,4}\|[A-G0-9]{32}$/i
    file, ed2k = $_.split "|"
    if File.exists? file
      mtx.synchronize {
        puts "* Adding \"#{file}\""
      }
      file_arr.push(FILE_T.new file, ed2k)
    else
      puts "ERROR! \"#{file}\" doesn't exist!"
    end
  end
end
still_open = false
t.join
