
ActiveRecord::Schema.define do

  unless ActiveRecord::Base.connection.tables.include? 'commands'
    create_table :commands do |table|
      table.column :title,       :string
      table.column :description, :text
      table.column :command,     :string
      table.column :arguments,   :string
      table.column :type,        :integer
    end
  end

  unless ActiveRecord::Base.connection.tables.include? 'macros'
    create_table :macros do |table|
      table.column :title,        :string
      table.column :description,  :text
    end
  end

  unless ActiveRecord::Base.connection.tables.include? 'events'
    create_table :events do |table|
      table.column :name,        :string
      table.column :arguments,   :string
      table.column :description, :text
      table.column :type,        :integer
    end
  end

  unless ActiveRecord::Base.connection.tables.include? 'tasks'
    create_table :tasks do |table|
      table.column :title,        :string
      table.column :description,  :text
      table.column :time,         :datetime
    end
  end


  unless ActiveRecord::Base.connection.tables.include? 'users'
    create_table :users do |table|
      table.column :name,     :string
      table.column :password, :string
      table.column :rights,   :integer
    end
  end


  unless ActiveRecord::Base.connection.tables.include? 'macro_commands'
    create_table :macro_commands do |table|
      table.column :macro_id,    :integer
      table.column :command_id,  :integer
    end
  end

  unless ActiveRecord::Base.connection.tables.include? 'event_macros'
    create_table :event_macros do |table|
      table.column :event_id,  :integer
      table.column :macro_id,  :integer
    end
  end

  unless ActiveRecord::Base.connection.tables.include? 'event_tasks'
    create_table :event_tasks do |table|
      table.column :event_id, :integer
      table.column :task_id,  :integer
    end
  end

  unless ActiveRecord::Base.connection.tables.include? 'task_macros'
    create_table :task_macros do |table|
      table.column :task_id,   :integer
      table.column :macro_id,  :integer
    end
  end

  unless ActiveRecord::Base.connection.tables.include? 'task_commands'
    create_table :task_commands do |table|
      table.column :task_id,     :integer
      table.column :command_id,  :integer
    end
  end



end
