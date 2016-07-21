class Macro < ActiveRecord::Base
  has_many :macro_commands, :dependent => :delete_all
  has_many :task_macros, :dependent => :delete_all
  has_many :event_macros, :dependent => :delete_all

  has_many :commands, through: :macro_commands
  has_many :tasks, through: :task_macros
  has_many :events, through: :event_macros

  serialize :arguments, JSON

  def run arguments, handler = nil
    puts "Running Macro:: #{self.title}"

    handler = CommandHandler.handler if handler.nil?

    self.macro_commands.each do |m_c|
      args = arguments

#p m_c
#p m_c.command
      print "M_C.Args:    "
      p m_c.arguments

      args = m_c.arguments.merge args

      print "Arguments:   "
      p args
      puts ">>>>>>>>>>>>>>:"

      m_c.command.run args, handler
    end
  end
end
