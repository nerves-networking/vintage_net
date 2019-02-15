defmodule Nerves.NetworkNG.Twilio do
  alias Nerves.NetworkNG

  def config_file_path() do
    Path.join(NetworkNG.tmp_dir(), "twilio")
  end

  def config_contents() do
    """
    # See http://consumer.huawei.com/solutions/m2m-solutions/en/products/support/application-guides/detail/mu509-65-en.htm?id=82047

    # Exit execution if module receives any of the following strings:
    ABORT 'BUSY'
    ABORT 'NO CARRIER'
    ABORT 'NO DIALTONE'
    ABORT 'NO DIAL TONE'
    ABORT 'NO ANSWER'
    ABORT 'DELAYED'
    TIMEOUT 10
    REPORT CONNECT

    # Module will send the string AT regardless of the string it receives
    "" AT

    # Instructs the modem to disconnect from the line, terminating any call in progress. All of the functions of the command shall be completed before the modem returns a result code.
    OK ATH

    # Instructs the modem to set all parameters to the factory defaults.
    OK ATZ

    # Result codes are sent to the Data Terminal Equipment (DTE).
    OK ATQ0

    # Define PDP context
    OK AT+CGDCONT=1,"IP","wireless.twilio.com"

    # ATDT = Attention Dial Tone
    OK ATDT*99***1#

    # Don't send any more strings when it receives the string CONNECT. Module considers the data links as having been set up.
    CONNECT ''
    """
  end

  def write_config() do
    :ok = NetworkNG.ensure_tmp_dir()

    config_file_path()
    |> File.write(config_contents())
  end
end
