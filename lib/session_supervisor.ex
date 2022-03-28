defmodule ACS.Session.Supervisor do
  use DynamicSupervisor
  require Logger

  def start_link(session_handler: session_module) do
    Logger.debug("SessionSupervisor start")
    # Have to register the supervisor process, so we can reference it
    # in the start_session/1 function
    # The session_module parameter is a module containing a session_start/3 method
    DynamicSupervisor.start_link(__MODULE__, session_module, name: :session_supervisor)
  end

  def start_session(session_id, device_id, message, fun) do
    Logger.debug("SessionSupervisor start_session(#{session_id},...) with function")

    spec =
      {ACS.Session, [session_id: session_id, device_id: device_id, message: message, fun: fun]}

    DynamicSupervisor.start_child(:session_supervisor, spec)
  end

  def start_session(session_id, device_id, message) do
    Logger.debug("SessionSupervisor start_session(#{session_id},...) without function")
    spec = {ACS.Session, [session_id: session_id, device_id: device_id, message: message]}
    DynamicSupervisor.start_child(:session_supervisor, spec)
  end

  def end_session(session_id) do
    Logger.debug("SessionSupervisor end_session(#{session_id})")

    DynamicSupervisor.terminate_child(
      :session_supervisor,
      :gproc.where({:n, :l, {:session_id, session_id}})
    )
  end

  def init(session_module) do
    DynamicSupervisor.init(
      strategy: :one_for_one,
      extra_arguments: [session_module]
    )
  end
end
