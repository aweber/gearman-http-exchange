%%==============================================================================
%% @author Gavin M. Roy <gavinr@aweber.com>
%% @copyright 2014 AWeber Communications
%% @end
%%==============================================================================

%% @doc define the runtime parameters and validators to setup policies
%% @end

-module(gearman_http_parameters).

-behaviour(rabbit_policy_validator).

-export([register/0,
         unregister/0,
         validate_policy/1]).

-define(RUNTIME_PARAMETERS,
        [{policy_validator,  <<"gearman-host">>},
         {policy_validator,  <<"gearman-port">>}]).

-rabbit_boot_step({?MODULE,
                   [{description, "gearman_http_exchange parameters"},
                    {mfa, {?MODULE, register, []}},
                    {requires, rabbit_registry},
                    {cleanup, {?MODULE, unregister, []}},
                    {enables, recovery}]}).

register() ->
  [rabbit_registry:register(Class, Name, ?MODULE) ||
      {Class, Name} <- ?RUNTIME_PARAMETERS],
  ok.

unregister() ->
    [rabbit_registry:unregister(Class, Name) ||
        {Class, Name} <- ?RUNTIME_PARAMETERS],
    ok.

validate_policy(KeyList) ->
  Host     = proplists:get_value(<<"gearman-host">>, KeyList, none),
  Port     = proplists:get_value(<<"gearman-port">>, KeyList, none),
  Validation = [gearman_http_lib:validate_host(Host),
                gearman_http_lib:validate_port(Port)],
  case Validation of
    [ok, ok]                   -> ok;
    [{error, Error, Args}, _]  -> {error, Error, Args};
    [ok, {error, Error, Args}] -> {error, Error, Args}
  end.
