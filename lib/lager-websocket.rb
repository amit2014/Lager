require 'json'

require_relative 'log_helper'
require_relative 'parser'

EM::WebSocket.start(:host => "0.0.0.0", :port => 4001) do |ws|
  puts ">> Websocket server started"

  ws.onopen do |handshake|
    puts "WebSocket connection open"
    # Access properties on the EM::WebSocket::Handshake object, e.g.
    # path, query_string, origin, headers
    # Publish message to the client
  end

  ws.onclose { puts "Connection closed" }

  ws.onmessage do |msg|
    puts "Recieved message: #{msg}"
    data = JSON.parse(msg)
    case data["type"]
    when "service"
      service = Service.includes(:servers).find(data["id"])
      service.servers.each do |server|
        Thread.new do
          stream_log(server[:host], service[:log_path]) do |ch, success|
            raise "could not stream logs" unless success

            # "on_data" is called when the process writes something to stdout
            ch.on_data do |c, data|
              data.each_line do |line|
                puts "#{line}"
                parsed_data = parse_time(line)
                ws.send({ host: server[:host], msg: parsed_data }.to_json)
              end
            end
            ch.on_close { puts "done!" }
          end
        end
      end
    when "server"
      raise 'unsupported operation' # to implement
    else
      raise 'unsupported operation'
    end
  end
end
