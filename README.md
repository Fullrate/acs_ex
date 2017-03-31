# acs_ex
[![Build Status](https://travis-ci.org/Fullrate/acs_ex.svg?branch=master)](https://travis-ci.org/Fullrate/acs_ex)
[![Hex.pm Version](http://img.shields.io/hexpm/v/acs_ex.svg?style=flat)](https://hex.pm/packages/acs_ex)

An implementation of the Auto Configuration Server mentioned in the TR-069 spec.

CWMP has the unfortunate effect of flipping the logic towards the CPE's. acs_ex aims to flip it
back.

It sets up a GenServer to handle sessions from CPE's. When a session starts an external handler that
can be configured is called. This handler has one method, `start_session` (Meaning an Inform was seen).

Seen from that handler, the logic is now shifted and you can just ask the GenServer for the stuff you need,
like "getParameterValues", "setParameterValues" aso, and the functions will return as were the
synchroneous.

So you write you own module that uses acs_ex as an application, and from that module you can
write whatever it is you actually want to do with the CPE's based on type, firmware version and
whatever else you can think up.

## Configuration

Our config.exs would have an entry similar to this:

```elixir
config :acs_ex, :acs_port, 7547
# crypt stuff is needed beacuse the CPE<>ACS cookie is an encrypted one.
config :acs_ex,
  crypt_keybase: "31de9f7d766287c7565801f30babbd4f",
  crypt_cookie_salt: "SomeSalt",
  crypt_signed_cookie_salt: "SomeSignedSalt"

```

acs_ex uses `Logger` for logging, so setup a backend that suits you if you want to see what it
is doing.

## Examples

TODO: Add some examples of how to setup an external actual ACS module to interact with acs_ex


