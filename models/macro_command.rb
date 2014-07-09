class MacroCommand < ActiveRecord::Base
  belongs_to :command
  belongs_to :macro
end
