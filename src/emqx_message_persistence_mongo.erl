%% Copyright (c) 2013-2019 EMQ Technologies Co., Ltd. All Rights Reserved.
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

-module(emqx_message_persistence_mongo).

-include("emqx_message_persistence_mongo.hrl").

-include_lib("emqx/include/emqx.hrl").
-include_lib("emqx/include/logger.hrl").
-include_lib("mongoc.hrl").

-export([load/1, unload/0]).

%% Hooks functions
-export([on_client_connected/4, on_client_disconnected/3]).
-export([on_client_subscribe/3, on_client_unsubscribe/3]).
-export([on_session_created/3, on_session_resumed/3, on_session_terminated/3]).
-export([on_session_subscribed/4, on_session_unsubscribed/4]).
-export([on_message_publish/2, on_message_delivered/3, on_message_acked/3, on_message_dropped/3]).
-export([description/0]).

%% Called when the plugin application start
load(Env) ->
  emqx:hook('client.connected', fun ?MODULE:on_client_connected/4, [Env]),
  emqx:hook('client.disconnected', fun ?MODULE:on_client_disconnected/3, [Env]),
  emqx:hook('client.subscribe', fun ?MODULE:on_client_subscribe/3, [Env]),
  emqx:hook('client.unsubscribe', fun ?MODULE:on_client_unsubscribe/3, [Env]),
  emqx:hook('session.created', fun ?MODULE:on_session_created/3, [Env]),
  emqx:hook('session.resumed', fun ?MODULE:on_session_resumed/3, [Env]),
  emqx:hook('session.subscribed', fun ?MODULE:on_session_subscribed/4, [Env]),
  emqx:hook('session.unsubscribed', fun ?MODULE:on_session_unsubscribed/4, [Env]),
  emqx:hook('session.terminated', fun ?MODULE:on_session_terminated/3, [Env]),
  emqx:hook('message.publish', fun ?MODULE:on_message_publish/2, [Env]),
  emqx:hook('message.delivered', fun ?MODULE:on_message_delivered/3, [Env]),
  emqx:hook('message.acked', fun ?MODULE:on_message_acked/3, [Env]),
  emqx:hook('message.dropped', fun ?MODULE:on_message_dropped/3, [Env]).

on_client_connected(#{client_id := ClientId}, ConnAck, ConnAttrs, _Env) ->
  io:format("Client(~s) connected, connack: ~w, conn_attrs:~p~n", [ClientId, ConnAck, ConnAttrs]).

on_client_disconnected(#{client_id := ClientId}, ReasonCode, _Env) ->
  io:format("Client(~s) disconnected, reason_code: ~w~n", [ClientId, ReasonCode]).

on_client_subscribe(#{client_id := ClientId}, RawTopicFilters, _Env) ->
  io:format("Client(~s) will subscribe: ~p~n", [ClientId, RawTopicFilters]),
  {ok, RawTopicFilters}.

on_client_unsubscribe(#{client_id := ClientId}, RawTopicFilters, _Env) ->
  io:format("Client(~s) unsubscribe ~p~n", [ClientId, RawTopicFilters]),
  {ok, RawTopicFilters}.

on_session_created(#{client_id := ClientId}, SessAttrs, _Env) ->
  io:format("Session(~s) created: ~p~n", [ClientId, SessAttrs]).

on_session_resumed(#{client_id := ClientId}, SessAttrs, _Env) ->
  io:format("Session(~s) resumed: ~p~n", [ClientId, SessAttrs]).

on_session_subscribed(#{client_id := ClientId}, Topic, SubOpts, _Env) ->
  io:format("Session(~s) subscribe ~s with subopts: ~p~n", [ClientId, Topic, SubOpts]).

on_session_unsubscribed(#{client_id := ClientId}, Topic, Opts, _Env) ->
  io:format("Session(~s) unsubscribe ~s with opts: ~p~n", [ClientId, Topic, Opts]).

on_session_terminated(#{client_id := ClientId}, ReasonCode, _Env) ->
  io:format("Session(~s) terminated: ~p.", [ClientId, ReasonCode]).

%% Transform message and return
on_message_publish(Message = #message{topic = <<"$SYS/", _/binary>>}, _Env) ->
  {ok, Message};

on_message_publish(Message, _Env) ->
  io:format("Publish ~s~n", [emqx_message:format(Message)]),
  Id = case is_binary(Message#message.id) of
         true -> binary:list_to_bin(integer_to_list(binary:decode_unsigned(Message#message.id)));
         false -> <<"">>
       end,
  Topics = string:split(Message#message.topic, "/", all),
  Topicsfree = lists:delete("",Topics),
  Topicsfreeall = lists:delete(<<>>,Topicsfree),
  MessageMap = #{
    <<"id">> => Id,
    <<"qos">> => integer_to_binary(Message#message.qos),
    <<"from">> => Message#message.from,
    <<"flags">> => Message#message.flags,
%%    <<"headers">> => Message#message.headers,
    <<"topic">> => Message#message.topic,
    <<"t1">> => check_if_exist(1,Topicsfreeall),
    <<"t2">> => check_if_exist(2,Topicsfreeall),
    <<"t3">> => check_if_exist(3,Topicsfreeall),
    <<"t4">> => check_if_exist(4,Topicsfreeall),
    <<"t5">> => check_if_exist(5,Topicsfreeall),
    <<"t6">> => check_if_exist(6,Topicsfreeall),
    <<"t7">> => check_if_exist(7,Topicsfreeall),
    <<"t8">> => check_if_exist(8,Topicsfreeall),
    <<"t9">> => check_if_exist(9,Topicsfreeall),
    <<"topic">> => Message#message.topic,
    <<"payload">> => Message#message.payload,
%%    <<"timestamp">> => integer_to_binary(calendar:datetime_to_gregorian_seconds(calendar:now_to_universal_time(Message#message.timestamp))),
    <<"timestamp">> => Message#message.timestamp,             
    <<"status">> => <<"publish">>
  },
  mongo_connection_singleton:get_singleton() ! {insert, [MessageMap]},
  {ok, Message}.

check_if_exist(Ind, Lista) ->
  Length = length(Lista),
  if 
    Length >= Ind -> lists:nth(Ind, Lista);
    Length < Ind  -> ""
  end.

on_message_delivered(#{client_id := ClientId}, Message, _Env) ->
  io:format("Delivered message to client(~s): ~s~n", [ClientId, emqx_message:format(Message)]),
  Id = case is_binary(Message#message.id) of
         true -> binary:list_to_bin(integer_to_list(binary:decode_unsigned(Message#message.id)));
         false -> <<"">>
       end,
  Selector = #{<<"id">> => Id},
  Command = #{<<"$set">> => #{<<"status">> => <<"delivered">>}},
  mongo_connection_singleton:get_singleton() ! {update, Selector, Command},
  {ok, Message}.

on_message_acked(#{client_id := ClientId}, Message, _Env) ->
  io:format("Session(~s) acked message: ~s~n", [ClientId, emqx_message:format(Message)]),
  {ok, Message}.

on_message_dropped(_By, #message{topic = <<"$SYS/", _/binary>>}, _Env) ->
  ok;
on_message_dropped(#{node := Node}, Message, _Env) ->
  io:format("Message dropped by node ~s: ~s~n", [Node, emqx_message:format(Message)]);
on_message_dropped(#{client_id := ClientId}, Message, _Env) ->
  io:format("Message dropped by client ~s: ~s~n", [ClientId, emqx_message:format(Message)]).

%% Called when the plugin application stop
unload() ->
  emqx:unhook('client.connected', fun ?MODULE:on_client_connected/4),
  emqx:unhook('client.disconnected', fun ?MODULE:on_client_disconnected/3),
  emqx:unhook('client.subscribe', fun ?MODULE:on_client_subscribe/3),
  emqx:unhook('client.unsubscribe', fun ?MODULE:on_client_unsubscribe/3),
  emqx:unhook('session.created', fun ?MODULE:on_session_created/3),
  emqx:unhook('session.resumed', fun ?MODULE:on_session_resumed/3),
  emqx:unhook('session.subscribed', fun ?MODULE:on_session_subscribed/4),
  emqx:unhook('session.unsubscribed', fun ?MODULE:on_session_unsubscribed/4),
  emqx:unhook('session.terminated', fun ?MODULE:on_session_terminated/3),
  emqx:unhook('message.publish', fun ?MODULE:on_message_publish/2),
  emqx:unhook('message.delivered', fun ?MODULE:on_message_delivered/3),
  emqx:unhook('message.acked', fun ?MODULE:on_message_acked/3),
  emqx:unhook('message.dropped', fun ?MODULE:on_message_dropped/3).

description() -> "Message Persistence Mongo Module".
