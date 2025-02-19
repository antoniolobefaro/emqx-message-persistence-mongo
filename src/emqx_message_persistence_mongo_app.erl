%% Copyright (c) 2018 EMQ Technologies Co., Ltd. All Rights Reserved.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.

-module(emqx_message_persistence_mongo_app).

-behaviour(application).

-emqx_plugin(?MODULE).

-include("emqx_message_persistence_mongo.hrl").

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
  io:format("emqx_persistence_mongo 启动啦！~n"),
  {ok, Sup} = emqx_message_persistence_mongo_sup:start_link(),
  application:ensure_all_started(mongodb),
  emqx_message_persistence_mongo:load(application:get_all_env()),
  {ok, Sup}.

stop(_State) ->
  emqx_message_persistence_mongo:unload(),
  mongo_connection_singleton:get_singleton() ! disconnect.

