%%==============================================================================
%% @author Gavin M. Roy <gavinr@aweber.com>
%% @copyright 2014 AWeber Communications
%% @end
%%==============================================================================

%% @doc Abstract away the validation and event submission functionality from
%%      the exchange module
%% @end

-module(gearman_http_lib).

-include_lib("rabbit_common/include/rabbit.hrl").
-include_lib("rabbit_common/include/rabbit_framing.hrl").

-export([post/2,
         validate/1,
         validate_host/1,
         validate_port/1]).

-define(SCHEME,        <<"http">>).
-define(DEFAULT_HOST,  <<"localhost">>).
-define(DEFAULT_PORT,  8080).

post(X, #delivery{message=#basic_message{routing_keys=Keys, content=Content}}) ->
  Key = lists:append([binary_to_list(K) || K <- Keys]),
  case ibrowse:send_req(get_url(X, Key),
                        get_headers(Content#content.properties),
                        post,
                        get_payload(Content),
                        [{max_sessions, 10}, {max_pipeline_size, 1}]) of
    {ok, "200", _, _}   -> ok;
    {ok, _, _, Content} -> {error, list_to_binary(Content)};
    {error, Error}      -> {error, Error}
  end.

%% @spec validate(X) -> Result
%% @where
%%       Value  = rabbit_type:exchange()
%%       Result = ok|{error, Error}
%% @doc Validate the user specified dbname is a binary value or none
%% @end
%%
validate(X) ->
  case  ibrowse:send_req(get_url(X, test), [], get) of
      {ok, "404", _, _  } -> ok;
      {ok, _, _, Content} -> {error, list_to_binary(Content)};
      {error, {Error, _}} -> {error, Error}
  end.

%% @spec validate_host(Value) -> Result
%% @where
%%       Value  = binary()|none
%%       Result = ok|{error, Error}
%% @doc Validate the user specified hostname is a binary or none
%% @end
%%
validate_host(none) ->
  ok;
validate_host(Value) ->
  validate_binary_or_none("influxdb-host", Value).

%% @spec validate_port(Value) -> Result
%% @where
%%       Value  = integer()|none
%%       Result = ok|{error, Error}
%% @doc Validate the user specified port is an integer value or none
%% @end
%%
validate_port(none) ->
  ok;
validate_port(Value) when is_number(Value) ->
  ok;
validate_port(Value) ->
  {error, "gearman-port should be a number, actually was ~p", [Value]}.

%% ---------------
%% Private Methods
%% ---------------

%% @private
%% @spec content_type(#'P_basic') -> list()
%% @doc Return HTTP headers with the content-type if applicable
%% @end
%%
content_type(Properties) ->
  case Properties#'P_basic'.content_type of
    <<"">> -> [];
    Value  -> [{"Content-Type", binary_to_list(Value)}]
  end.

%% @private
%% @spec get_env(EnvVar, DefaultValue) -> Value
%% @where
%%       Name         = list()
%%       DefaultValue = mixed
%%       Value        = mixed
%% @doc Return the environment variable defined for listen returning the
%%      value if the variable is found, otherwise return the passed in default
%% @end
%%
get_env(EnvVar, DefaultValue) ->
  case application:get_env(listen, EnvVar) of
    undefined ->
      DefaultValue;
    {ok, V} ->
      V
  end.

%% @private
%% @spec headers(#'P_basic') -> proplist()
%% @doc Return HTTP headers for the given properties
%% @end
%%
get_headers(Properties) ->
  Headers = content_type(Properties),
  message_id(Properties, Headers).

%% @private
%% @spec get_parm(X, Name, DefaultValue) -> Value
%% @where
%%       X            = rabbit_types:exchange()
%%       Name         = list()|atom()
%%       DefaultValue = mixed
%%       Value        = mixed
%% @doc Returns the configuration value for an exchange, first by checking to
%% see if a policy value is set for the exchange, then by checking arguments in
%% the exchange, then checking environment defined overrides (config), and
%% finally by returning the passed in default value
%% @end
%%
get_param(X, Name, DefaultValue) when is_atom(Name) ->
  get_param(X, atom_to_list(Name), DefaultValue);
get_param(X=#exchange{arguments=Args}, Name, DefaultValue) when is_list(Name) ->
  case rabbit_policy:get(list_to_binary("gearman-" ++ Name), X) of
    undefined -> get_param_value(Args, Name, DefaultValue);
    Value     ->
      case is_binary(Value) of
        true  -> binary_to_list(Value);
        false -> Value
      end
  end.

%% @private
%% @spec get_param_env_value(Name, DefaultValue) -> Value
%% @where
%%       Name         = list()
%%       DefaultValue = mixed
%%       Value        = mixed
%% @doc Return the value specified in the config/environment for the passed in
%% key Name, returning DefaultValue if it's not specified
%% @end
%%
get_param_env_value(Name, DefaultValue ) ->
  get_env(list_to_atom(Name), DefaultValue).

%% @private
%% @spec get_param_list_value(Value) -> list()
%% @where
%%       DefaultValue = binary()|integer()|list()
%% @doc Cast Value to a list if it is binary or an integer
%% @end
%%
get_param_list_value(Value) when is_binary(Value) ->
  binary_to_list(Value);
get_param_list_value(Value) when is_integer(Value) ->
  integer_to_list(Value);
get_param_list_value(Value) when is_list(Value) ->
  Value.

%% @private
%% @spec get_param_value(Args, Name, DefaultValue) -> Value
%% @where
%%       Args         = rabbit_framing:amqp_table()
%%       Name         = list()
%%       DefaultValue = binary()|integer()|list()
%% @doc Return the value of Name from the Args table, falling back to returning
%% the configuration specified env value, or the DefaultValue if it not present
%% in either Args or the config environment.
%% @end
%%
get_param_value(Args, Name, DefaultValue) ->
  case lists:keyfind(list_to_binary("x-" ++ Name), 1, Args) of
    {_, _, V} -> get_param_list_value(V);
            _ -> get_param_list_value(get_param_env_value(Name, DefaultValue))
  end.

%% @private
%% @spec get_payload(Value) -> list()
%% @where
%%       Value = tuple()#content
%% @doc Extract the reverse list of binary payload segments and order it
%%      correctly, converting the binary to list to return the full message
%%      body as a list.
%% @end
%%
get_payload(#content{payload_fragments_rev=Payload}) ->
  lists:append(lists:reverse([binary_to_list(V) || V <- Payload])).

%% @private
%% @spec get_port(Value) -> integer()
%% @where
%%       Value = list()|integer()|none
%% @doc Return the value passed in as an integer if it is a list anf the value
%% if it is an integer
%% @end
%%
get_port(Value) when is_list(Value) ->
  list_to_integer(Value);
get_port(Value) when is_number(Value) ->
  Value.

%% @private
%% @spec get_url(X, Func) -> list()
%% @where
%%       X    = rabbit_types:exchange()
%%       Func = list()
%% @doc Return a properly formatted influxdb URL for the specified type
%%      (authenticate, series, etc)
%% @end
%%
get_url(X, Func) ->
  Host     = get_param(X, "host", ?DEFAULT_HOST),
  Port     = get_port(get_param(X, "port", ?DEFAULT_PORT)),
  ?SCHEME ++ "://" ++ Host ++ ":" ++ integer_to_list(Port) ++ "/" ++ Func.

%% @private
%% @spec message_id(#'P_basic', list) -> proplist()
%% @doc Return HTTP headers with the X-Gearman-Unique header if applicable
%% @end
%%
message_id(Properties, Headers) ->
  case Properties#'P_basic'.message_id of
    <<"">> -> Headers;
    Value  -> lists:append(Headers, [{"X-Gearman-Unique", Value}])
  end.

%% @private
%% @spec validate_binary_or_none(Name, Value) -> Result
%% @doc Validate the user specified value is a binary() or none
%% @where
%%       Name   = list()
%%       Value  = binary()|none
%%       Result = ok|{error, Error}
%% @end
%%
validate_binary_or_none(_, none) ->
  ok;
validate_binary_or_none(_, Value) when is_binary(Value) ->
  ok;
validate_binary_or_none(Name, Value) ->
  {error, "~s should be binary, actually was ~p", [Name, Value]}.
