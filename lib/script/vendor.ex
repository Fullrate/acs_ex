defmodule ACS.Session.Script.Vendor do
  require Logger
  use ACS.SessionScript


  @moduledoc """

  This is the main vendor specific logic module, and the one
  you want to write if you have stuff that needs to happen in
  your specific environment.

  In the real world you would write a new module that starts acs_ex
  using the child_spec, giving it the name of your handler module.

  That would make acs_ex use your module when initiating the script
  session.

  An example of this is available right next to this module.

  """

  def session_start(_session,did,_inform) do
    Logger.debug("Default Vendor start called...#{inspect did}")
  end

end
