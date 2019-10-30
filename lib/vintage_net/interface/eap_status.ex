defmodule VintageNet.Interface.EAPStatus do
  defstruct [
    :status,
    :method,
    remote_certificate_verified?: false
  ]

  @typedoc """
  Can be one of: as defined in `eap_defs.h` in the hostapd source.
  NONE
  IDENTITY
  NOTIFICATION
  NAK
  MD5
  OTP
  GTC
  TLS
  LEAP
  SIM
  TTLS
  AKA
  PEAP
  MSCHAPV2
  TLV
  TNC
  FAST
  PAX
  PSK
  SAKE
  IKEV2
  AKA_PRIME
  GPSK
  PWD
  EKE
  TEAP
  EXPANDED
  """
  @type method() :: String.t()

  @type t() :: %VintageNet.Interface.EAPStatus{
          status: nil | :started | :failure | :success,
          method: nil | method(),
          remote_certificate_verified?: boolean()
        }
end
