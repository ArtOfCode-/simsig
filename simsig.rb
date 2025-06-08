require 'json'
require 'logger'
require 'stomp'
require 'yaml'
require 'active_support/all'
require 'optparse'
require 'ostruct'

class SimSig
  def initialize
    @logger = Logger.new STDOUT
    @logger.level = Logger::INFO
    @logger.formatter = proc do |sev, dt, prog, msg|
      "[#{dt.strftime('%Y-%m-%d %H:%M:%S')}] #{sprintf('%5s', sev)} : #{msg}\n"
    end
    @options = OpenStruct.new(verbose: false)

    parse_options
    @area_config = parse_area_config

    @crossing_config = @area_config['crossings']
    @crossing_triggers = @crossing_config.values.flatten

    conn = parse_connection_info
    @stomp = Stomp::Client.new(conn)
    @logger.info "Connected to Interface Gateway on #{conn[:hosts][0][:host]}:#{conn[:hosts][0][:port]}"
  end

  def parse_options
    OptionParser.new do |opts|
      opts.banner = 'Usage: ruby simsig.rb [options] <area>'

      opts.on '-v', '--verbose', 'Add debug logging. Use with caution - creates lots of output.' do |v|
        @options.verbose = v
        @logger.level = Logger::DEBUG
      end
    end.parse!

    @area = ARGV.shift

    if @area.nil? || @area.empty?
      @logger.fatal 'No area specified. You must specify the name of the SimSig area you are running.'
      @logger.fatal 'Example: ruby simsig.rb [options] sheffield'
      exit 1
    end
  end

  def parse_connection_info
    begin
      creds = YAML.load_file(File.join(Dir.pwd, 'config/credentials.yml')).deep_symbolize_keys
      {
        hosts: [creds],
        connect_headers: {
          'accept-version': '1.1',
          'host': creds[:host]
        },
        logger: @logger
      }
    rescue Errno::ENOENT
      @logger.fatal 'No credentials file. Copy config/credentials.example.yml to config/credentials.yml and fill in ' \
                    'your details.'
      exit 2
    end
  end

  def parse_area_config
    begin
      YAML.load_file(File.join(Dir.pwd, "config/#{@area}.yml"))
    rescue Errno::ENOENT
      @logger.fatal "No area configuration. Create config/#{@area}.yml providing data for the area you're running."
      exit 3
    end
  end

  def start!
    topics = ['/topic/TD_ALL_SIG_AREA', '/topic/TRAIN_MVT_ALL_TOC']

    begin
      topics.each do |topic|
        @stomp.subscribe topic, { ack: 'auto' } do |msg|
          process_message msg
        end
      end

      @logger.debug "Subscribed to topics #{topics.join(', ')}"

      while true do
        sleep 0.1
      end
    rescue Stomp::Error::BrokerException => ex
      @logger.error "Broker exception: message, receipt ID, headers, broker backtrace"
      @logger.error ex.message
      @logger.error ex.receipt_id
      @logger.error ex.headers
      @logger.error ex.broker_backtrace
    rescue => ex
      @logger.error "Other unhandled exception:"
      @logger.error ex.message
      @logger.error ex.backtrace
    end
  end

  def parse_time(secs)
    secs = secs.to_i
    hours = secs / 3600
    mins = (secs % 3600) / 60
    secs = (secs % 3600) % 60
    "#{sprintf '%02d', hours}:#{sprintf '%02d', mins}:#{sprintf '%02d', secs}"
  end

  def lower_crossing(id)
    @stomp.publish('/topic/TD_ALL_SIG_AREA', JSON.dump({ crossingrequest: { crossing: id, operation: 'lower' } }))
  end

  def process_message(msg)
    raw = JSON.parse(msg.body)
    key = raw.keys[0]
    data = raw[key]
    @logger.debug "#{parse_time data['time']}: #{key} #{data}"

    if key == 'train_location' && @crossing_triggers.include?(data['location'])
      @crossing_config.each do |crossing_id, triggers|
        if triggers.include?(data['location'])
          @logger.info "#{parse_time(data['time'])}: Crossing #{crossing_id} triggered at #{data['location']}"
          if @area_config['mode'] == 'control'
            lower_crossing crossing_id
          end
        end
      end
    end

    if key == 'SG_MSG' && data['obj_type'] == 'route' && data['is_set'] == 'True' && @crossing_triggers.include?(data['obj_id'])
      @crossing_config.each do |crossing_id, triggers|
        if triggers.include?(data['obj_id'])
          @logger.info "#{parse_time(data['time'])}: Crossing #{crossing_id} triggered by route #{data['obj_id']}"
          if @area_config['mode'] == 'control'
            lower_crossing crossing_id
          end
        end
      end
    end
  end
end

SimSig.new.start!
