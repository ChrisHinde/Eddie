class Log < ActiveRecord::Base
  belongs_to :state

  def self.log state, value, extra = nil
    log = Log.new

    log.state       = state
    log.state_title = state.title
    log.value       = value
    log.extra       = extra unless extra.nil?

    log.save
  end
end
