defmodule ACS.Session.Supervisor do
  use Supervisor
  require Logger

  def start_link(session_module \\ nil) do
    # Have to register the supervisor process, so we can reference it
    # in the start_session/1 function
    # The session_module parameter is a module containing a session_start/3 method
    Supervisor.start_link(__MODULE__, [session_module], name: :session_supervisor)
  end

  def start_session(device_id, message, fun) do
    Logger.debug("SessionSupervisor start_session with function")
    Supervisor.start_child(:session_supervisor, [device_id,message,fun])
  end

  def start_session(device_id, message) do
    Logger.debug("SessionSupervisor start_session without function")
    case Application.fetch_env(:acs_ex, :session_script) do
      {:ok,module} -> Supervisor.start_child(:session_supervisor, [device_id,message,module])
      :error -> Supervisor.start_child(:session_supervisor, [device_id,message])
    end
  end

  def end_session(device_id) do
    Logger.debug("SessionSupervisor terminate_child(#{inspect device_id})")
    Supervisor.terminate_child(:session_supervisor, :gproc.where({:n, :l, {:device_id, device_id}}))
  end

  def init(session_module) do
    children = [
      worker(ACS.Session, [session_module], restart: :temporary)
    ]

    supervise(children, strategy: :simple_one_for_one)
  end
end
