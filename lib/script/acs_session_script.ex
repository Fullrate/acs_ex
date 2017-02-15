defmodule ACS.SessionScript do
  @type filter_response :: atom | tuple
  @callback session_start(pid, map, String.t) :: any
  @callback session_filter(map, String.t) :: filter_response

  defmacro __using__(_) do
    quote location: :keep do
      @behaviour ACS.SessionScript

      def session_start(_session, _device_id, _inform) do
      end

      def session_filter(_device_id, _inform) do
        :ok
      end

      defoverridable [session_start: 3, session_filter: 2]
    end
  end
end
