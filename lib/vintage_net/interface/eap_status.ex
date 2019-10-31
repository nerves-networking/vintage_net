defmodule VintageNet.Interface.EAPStatus do
  @moduledoc """
  Status of an EAP connection.

  ## Keys
  * `status` Status of the connection.
    * `:started` - the AP was assosiated and EAP is started.
    * `:success` - the EAP connection was successful
    * `:failure` - the EAP connection failed.
  * `method` - EAP method used to authenticate. See the typespec for available values.
  * `timestamp` - DateTime of the most recent EAP event.
  * `remote_certificate_verified?` - if the cert was verified by the EAP server.
  """
  defstruct [
    :status,
    :method,
    :timestamp,
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
          timestamp: nil | DateTime.t(),
          remote_certificate_verified?: boolean()
        }
end
