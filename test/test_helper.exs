Application.put_env(:pex, :env, :test)
ExUnit.start()
Logger.configure(level: :error)
Application.ensure_all_started(:phoenix_live_view)
