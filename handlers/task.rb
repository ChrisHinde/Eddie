class TaskHandler < BaseHandler
  include EddieMQTT_Listener

  def initialize
    Eddie.messenger.subscribe 'tasks/#', self
  end

  def self.add( params, thread )
    thread.tell 'Add Task!'
  end

  def methods_str
    return "[list,add,info,run]"
  end

  def send_info topic, payload, rest = nil
    tsk_n = rest.nil? ? payload : rest

    tsk = Task.find_by title: tsk_n

    unless tsk.nil?
      task = {
        id:    tsk.id,
        title: tsk.title,
        desc:  tsk.description,
        time:  tsk.time,
        macros: [],
        commands: []
      }

      tsk.task_macros.each do |mcr|
        task[:macros].push mcr
      end

      tsk.task_commands.each do |cmd|
        task[:commands].push cmd
      end

      Eddie.messenger.respond topic, task.to_json
    else
      Eddie.messenger.respond topic, "ERROR: No such task > #{payload}"
    end
  end


  def add topic, data_raw, rest = nil
    begin
      data = JSON.parse data_raw
    rescue
      Eddie.messenger.respond topic, 'ERROR: Payload is not valid JSON'
      return
    end

    if data['title'].empty?
      Eddie.messenger.respond topic, 'ERROR: No title given'
      return
    end

    if Task.exists?( title: data['title'] )
      Eddie.messenger.respond topic, 'ERROR: A task called ' + data['title'] +' already exists'
      return
    end

    task = Task.new

    task.title = data['title']
    task.description = data['desc']
    task.time = data['time'] unless data['time'].nil?

    if task.save
      data['commands'].each do |cmd_t,args|
        cmd = Command.find_by title: cmd_t

        t_c = TaskCommand.new
        t_c.arguments = args
        t_c.command = cmd
#        t_c.task = task

        task.task_commands << t_c if t_c.save
      end

      data['macros'].each do |mcr_t,args|
        mcr = Macro.find_by title: mcr_t

        m_c = TaskMacro.new
        m_c.arguments = args
        m_c.macro = mcr

        task.task_macros << m_c if m_c.save
      end

      Eddie.messenger.respond topic, 'SUCCESS: Added ' + data['title']
    else
      Eddie.messenger.respond topic, 'ERROR: Adding ' + data['title'] + " > Couldn't save!"
    end
  end

  def delete_task topic, payload, rest = nil
    tsk = rest.nil? ? payload : rest

    puts "Delete Task: #{tsk}"

    task = Task.find_by title: tsk

    if task.nil?
      Eddie.messenger.respond topic, "ERROR: No such task > #{tsk}"
    else
      task.destroy

      Eddie.messenger.respond topic, "SUCCESS: Deleted task #{tsk}"
    end

  end


  def run_task topic, payload, rest = nil
    tsk = rest.nil? ? payload : rest

    puts "Running task: #{tsk}"

    task = Task.find_by title: tsk

    if task.nil?
      Eddie.messenger.respond topic, "ERROR: No such task > #{tsk}"
    else
      arguments = { '_topic' => topic, '_payload' => payload }

      begin
        args = JSON.parse payload

        args.each do |k,v|
          arguments[k] = v unless k.first == '_'
        end
      rescue
        arguments['_argument'] = payload
      end unless rest.nil?

      task.run arguments, CommandHandler.handler
    end
  end


  def list
    tasks = Task.all

    tsks = []

    tasks.each do |task|
      tsks.push task.title
    end

    return tsks.to_json
  end

  def call( topic, payload )
    top = topic.split('/tasks/').last
    meth, rest = top.split('/',2)

    case meth
    when 'list'
      Eddie.messenger.respond topic, list
    when 'add'
      add topic, payload, rest
    when 'delete'
      delete_task topic, payload, rest
    when 'info'
      send_info topic, payload, rest
    when 'run'
      run_task topic, payload, rest
    else
      Eddie.messenger.respond topic, "Unknown method: #{meth}"
    end
  end

end

puts "Task Handler Loading"
Eddie.register "tasks", TaskHandler.new

=begin
{
 "title":"task_test",
 "desc":"Task test!",
 "time": null,
 "commands":{
   "test": {},
   "s_test": { "yuip": "Task" }
 },
 "macros": {
   "m_test": { "id": "Taks" }
 }
}
=end
