%%%-------------------------------------------------------------------
%%% @author liuxuehao
%%% @copyright (C) 2018, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 08. 十一月 2018 下午12:59
%%%-------------------------------------------------------------------
-module(mongo_connection_singleton).
-author("Lob with liuxuehao").

%% API
-export([get_singleton/0]).

-define(SINGLETON_NAME, mongo_connection_singleton).
-define(DIC_MONGO_CONNECTION, dic_mongo_connection).

%% Interfaccia esterna, ottenere processo singleton
get_singleton() ->
  case whereis(?SINGLETON_NAME) of
    undefined ->
      {ok, Connection} = connect_mongo(),
      put(?DIC_MONGO_CONNECTION, Connection),
      Singleton = spawn(fun singleton_loop/0),
      register(?SINGLETON_NAME, Singleton),
      Singleton;
    Pid -> Pid
  end.

%% Ciclo entità singolo caso
singleton_loop() ->
  receive
    {insert, Document} ->
      insert(Document),
      singleton_loop();
    {update, Selector, Document} ->
      update(Selector, Document),
      singleton_loop();
    disconnect ->
      disconnect()
  end.

insert(Document) ->
  Connection = get_mongo_connection(),
  mc_worker_api:insert(Connection, <<"message">>, Document).

update(Selector, Document) ->
  Connection = get_mongo_connection(),
  mc_worker_api:update(Connection, <<"message">>, Selector, Document).

get_mongo_connection() ->
  case get(?DIC_MONGO_CONNECTION) of
    undefined ->
      {ok, Connection} = connect_mongo(),
      put(?DIC_MONGO_CONNECTION, Connection), connect_mongo(),
      Connection;
    Connection -> Connection
  end.

connect_mongo() ->
  {ok, Connection} = mc_worker_api:connect([ {database, <<"mqtt">>}, {host, "localhost"}, {port, 27017}]),
  {ok, Connection}.

disconnect() ->
  Connection = get_mongo_connection(),
  mc_worker_api:disconnect(Connection).