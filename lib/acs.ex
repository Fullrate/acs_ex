defmodule ACS do
  @moduledoc """
  Request router for CPE->ACS

  """
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      Plug.Adapters.Cowboy.child_spec(:http, ACS.ACSHandler, [], [port: Application.fetch_env!(:acs_ex, :acs_port)])
    ]

    opts = [strategy: :one_for_one, name: ACS.Supervisor]
    Supervisor.start_link(children, opts)
    ACS.Session.Supervisor.start_link
  end

  @doc """

  From you actual ACS module, you do...

  Presuming your module is named `MyACS` you can add it to your
  supervision tree like so using this function:

      defmodule MyApp do
        use Application
        def start(_type, _args) do
          import Supervisor.Spec
          children = [
            ACS.child_spec(MyACS.SomeModule.some_function, [], [port: 4001])
          ]
          opts = [strategy: :one_for_one, name: MyApp.Supervisor]
          Supervisor.start_link(children, opts)
        end
      end
  """
  def child_spec(function, acsoptions \\ [], cowboyoptions \\ []) do
    import Supervisor.Spec, warn: false

    children = [
      Plug.Adapters.Cowboy.child_spec(:http, ACS.ACSHandler, [], cowboyoptions)
    ]

    opts = [strategy: :one_for_one, name: ACS.Supervisor]
    Supervisor.start_link(children, opts)
    ACS.Session.Supervisor.start_link(function)
  end
end
