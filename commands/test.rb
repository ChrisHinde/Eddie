def script_main arguments, cmd_name
  p arguments
  Eddie.messenger.respond arguments['_topic'], "SUCCESS: Testing script command '" + cmd_name + "' (" + arguments.to_json + ")"
end
