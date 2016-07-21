class Task < ActiveRecord::Base
  has_many :task_macros, :dependent => :delete_all
  has_many :task_commands, :dependent => :delete_all

  has_many :macros, through: :task_macros
  has_many :commands, through: :task_commands

  serialize :arguments, JSON

  def run arguments, handler = nil
    puts "Running Task:: #{self.title}"

    handler = CommandHandler.handler if handler.nil?

    self.task_commands.each do |t_c|
      args = arguments

      print "T_C.Args:    "
      p t_c.arguments
      print "Arguments:   "
      p arguments

      args = t_c.arguments.merge args

      print "Merged args: "
      p args
      print "T_C:         "
      p t_c
      puts ">>>>>>>>>>>>"

      t_c.command.run args, handler

      puts ". . . . . . . . . . . . . . . \n"
    end

    self.task_macros.each do |t_m|
      args = arguments

      print "T_M.Args:    "
      p t_m.arguments

      args = t_m.arguments.merge args

      print "Merged args: "
      p args
      puts ">+>+>+>+>+>+>+>+>+>+>+>"

      t_m.macro.run args, handler

      puts ", , , , , , , , , , , , , , \n"
    end


  end
end
