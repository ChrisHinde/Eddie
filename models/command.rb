class Command < ActiveRecord::Base
  has_many :macros, through: :macro_commands
  has_many :tasks, through: :task_commands

  serialize :arguments, JSON

  Types = { 'internal' => 1, 'script' => 2 }

  def self.type_to_int t
    if Types.key? t
      return Types[t]
    else
      raise 'Unrecognized type: ' + t
    end
  end
  def self.type_to_str t
    type = Types.key(t)

    raise 'Unrecognized type: ' + t.to_s if type.nil?

    return type
  end


  def run args, cmd_handler
    puts "Running #{self.title}"

    unless self.arguments.nil?
      unless self.arguments['in'].nil?

        self.arguments['in'].each do |a,v|
          args[a] = v if args[a].nil?
        end

        unless self.arguments['out'].nil?
          arguments = {}

          self.arguments['out'].each do |a,v|
            arguments[a] = replace_arguments v, args
          end

          arguments.merge! args.select { |a,v| a[0] == '_' }
        else
          arguments = args
        end
      else
        arguments = args
        self.arguments.each do |a,v|
          arguments[a] = v if arguments[a].nil?
        end
      end
    end

    case command_type
    when Types['internal']
      cmd_handler.run_internal self.command, arguments, self
    when Types['script']
      cmd_handler.run_script self.command, arguments, self
    else
      raise "Unexpected command type type: " + command_type
    end
  end

  def replace_arguments arg, arguments
    arguments.each do |a,v|
      arg.gsub! '%' + a + '%', v
    end

    return arg
  end
end
