#!/usr/bin/ruby

require 'pi_piper'

class PWM
  def run
    pin = PiPiper::Pin.new( pin: 18, direction: :out )

    p pin

    loop do
#      puts "on"
#      pin.on
      sleep 0.0005
#      puts "off"
      pin.off
#      sleep 0.01
    end
  end
end

pwm = PWM.new
pwm.run
