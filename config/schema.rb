ActiveRecord::Schema.define do

  unless ActiveRecord::Base.connection.data_sources.include? 'commands'
    create_table :commands do |table|
      table.column :title,        :string
      table.column :description,  :text
      table.column :command,      :string
      table.column :arguments,    :string
      table.column :command_type, :integer
    end
  end

  unless ActiveRecord::Base.connection.data_sources.include? 'macros'
    create_table :macros do |table|
      table.column :title,        :string
      table.column :description,  :text
    end
  end

#  rename_column :events, :name, :title

  unless ActiveRecord::Base.connection.data_sources.include? 'events'
    create_table :events do |table|
      table.column :title,       :string
      table.column :arguments,   :string
      table.column :description, :text
      table.column :event_type,  :integer
      table.column :conditions,  :text
    end
  end

  unless ActiveRecord::Base.connection.data_sources.include? 'tasks'
    create_table :tasks do |table|
      table.column :title,        :string
      table.column :description,  :text
      table.column :time,         :datetime
    end
  end


  unless ActiveRecord::Base.connection.data_sources.include? 'states'
    create_table :states do |table|
      table.column :title,        :string
      table.column :state_type,   :integer
      table.column :description,  :text
      table.column :label,        :string
      table.column :value_type,   :integer
      table.column :value,        :binary
      table.column :value_map,    :text
      table.column :zone_id,      :integer
      table.column :group_id,     :integer
      table.column :do_log,       :bool
      table.column :locked,       :bool
    end
  end

  unless ActiveRecord::Base.connection.data_sources.include? 'zones'
    create_table :zones do |table|
      table.column :title,       :string
      table.column :description, :text
      table.column :icon,        :string
    end
  end

  unless ActiveRecord::Base.connection.data_sources.include? 'groups'
    create_table :groups do |table|
      table.column :title,       :string
      table.column :description, :text
      table.column :icon,        :string
    end
  end

  unless ActiveRecord::Base.connection.data_sources.include? 'logs'
    create_table :logs do |table|
      table.column :state_title, :string
      table.column :state_id,    :integer
      table.column :value,       :binary
      table.column :extra,       :string
    end
  end

  unless ActiveRecord::Base.connection.data_sources.include? 'users'
    create_table :users do |table|
      table.column :name,     :string
      table.column :password, :string
      table.column :rights,   :integer
    end
  end

  unless ActiveRecord::Base.connection.data_sources.include? 'macro_commands'
    create_table :macro_commands do |table|
      table.column :macro_id,    :integer
      table.column :command_id,  :integer
      table.column :arguments,   :text
    end
  end


  unless ActiveRecord::Base.connection.data_sources.include? 'event_macros'
    create_table :event_macros do |table|
      table.column :event_id,  :integer
      table.column :macro_id,  :integer
      table.column :arguments,   :text
    end
  end

  unless ActiveRecord::Base.connection.data_sources.include? 'event_tasks'
    create_table :event_tasks do |table|
      table.column :event_id, :integer
      table.column :task_id,  :integer
      table.column :arguments,   :text
    end
  end

  unless ActiveRecord::Base.connection.data_sources.include? 'task_macros'
    create_table :task_macros do |table|
      table.column :task_id,   :integer
      table.column :macro_id,  :integer
      table.column :arguments,   :text
    end
  end

  unless ActiveRecord::Base.connection.data_sources.include? 'task_commands'
    create_table :task_commands do |table|
      table.column :task_id,     :integer
      table.column :command_id,  :integer
      table.column :arguments,   :text
    end
  end



end
