require 'agi'
require 'eventmachine'

class FastAGIProtocol < EventMachine::Protocols::LineAndTextProtocol
  include AGIMixin

  def initialize
    super
    @agi_mode = :environment
    @agi_queue = []
    @agi_last_defer = nil
  end

  def receive_line(line)
    begin
      if @agi_mode == :environment
        if not parse_env line
          @agi_mode = :commands
          agi_post_init if respond_to? :agi_post_init
        end
      else # @agi_mode == :commands
        @log.debug "<< "+line if not @log.nil?
        return if @agi_last_defer.nil?
        @agi_last_defer.succeed Response.new(line)
        @agi_last_defer = nil
        flush_queue
      end
    rescue Exception => e
      if not @log.nil?
        @log.error "#{e.class.name}: #{e.message}"
        e.backtrace.each { |line| @log.error "\t#{line}" }
      end
    end
  end

  # Send a command, and return a Deferrable for the Response object.
  def send(cmd, *args)
    msg = build_msg(cmd, *args)
    d = EM::DefaultDeferrable.new
    @agi_queue << [msg, d]
    flush_queue
    d
  end

  # Try to send the next command from the queue.
  def flush_queue
    return if not @agi_last_defer.nil?
    msg, d = @agi_queue.shift
    return if msg.nil?
    @agi_last_defer = d
    @log.debug ">> "+msg if not @log.nil?
    send_data msg+"\n"
  end
  private :flush_queue
end
