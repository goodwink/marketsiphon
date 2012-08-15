if ENV['RACK_ENV'] == 'development' || ENV['RACK_ENV'] == 'test'
  worker_processes 1
else
  worker_processes 8
end
