workers Integer(ENV['WEB_CONCURRENCY'] || 2)
threads_count = Integer(ENV['MAX_THREADS'] || 5)
threads threads_count, threads_count

preload_app!

rackup      -> { File.join(Dir.pwd, 'config.ru') }
port        ENV['PORT']     || 9292
environment ENV['RACK_ENV'] || 'development'

on_worker_boot do
end