defmodule VintageNet.Connectivity.SSLPing.PublicKey do
  @moduledoc """
  Insecure connect options for SSLPing connectivity checker. This module
  is an example, and should not be used in production devices. It uses
  `:public_key.cacerts` which will likely be valid at the time of firmware
  creation, however they will become invalid and unable to update in the
  future without a firmware upgrade.
  """

  require Logger

  @doc false
  if :erlang.system_info(:otp_release) in [~c"21", ~c"22", ~c"23", ~c"24"] do
    def connect_options() do
      Logger.warning("SSLPing support on OTP 24 is limited due to lack of cacerts")
      []
    end
  else
    def connect_options() do
      Logger.warning("SSLPing using :public_key for :cacerts. This is potentially insecure.")

      [
        cacerts: :public_key.cacerts_get(),
        verify: :verify_peer
      ]
    end
  end
end
