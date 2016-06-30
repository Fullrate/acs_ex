defmodule ACS.Session.Supervisor do
  use Supervisor

  def start_link do
    # Have to register the supervisor process, so we can reference it
    # in the start_session/1 function
    Supervisor.start_link(__MODULE__, [], name: :session_supervisor)
  end

  def start_session(device_id, message, fun) do
    # if a session for a serial allready exist, reuse it, otherwise
    # create a new child.
    Supervisor.start_child(:session_supervisor, [device_id,message,fun])
  end

  def start_session(device_id, message) do
    # if a session for a serial allready exist, reuse it, otherwise
    # create a new child.
    Supervisor.start_child(:session_supervisor, [device_id,message])
  end

  def end_session(device_id) do
    Supervisor.terminate_child(:session_supervisor, :gproc.where({:n, :l, {:device_id, device_id}}))
  end

  def init(_) do
    children = [
      worker(ACS.Session, [], restart: :temporary)
    ]

    supervise(children, strategy: :simple_one_for_one)
  end
end
