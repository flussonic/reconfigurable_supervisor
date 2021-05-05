-module(reconfigurable_supervisor_SUITE).
-compile(nowarn_export_all).
-compile(export_all).


% This test is checking modified supervisor code that can do hot reconfiguration of whole tree.
%
% Idea is following: our processes configuration should be dependent from start args.
% If we want to reconfigure process on fly, we should change his start args (just like we do in React.js)
%
% Supervisor should go through children and reconfigure them if arguments change.
%
% This test simulate adding, changing and removing children from childspec and checks that pids of
% other children have not changed.
%
% If some child crashes during reconfiguration, this should be handled in normal supervisor behaviour:
% restart, retry, then kill anybody who knows anything about it.




all() ->
  [
  update_init_spec,
  add_extra_children,
  remove_old_children,
  nested_supervisors
  ].





init([TestcaseName]) ->
  ConfigOption = list_to_atom("test_sup_config_"++atom_to_list(TestcaseName)),
  {ok, Children} = application:get_env(kernel, ConfigOption),
  {ok, {{one_for_one, 5, 10}, Children}}.



process_start_link(#{} = Options) ->
  proc_lib:start_link(?MODULE, process_init, [Options]).


process_init(#{} = Options) ->
  proc_lib:init_ack({ok, self()}),
  process_loop(Options).

process_loop(Options) ->
  Msg = receive
    M -> M
  end,
  case Msg of
    {'$gen_call', From, {update_start_args, [NewOptions]}} ->
      gen:reply(From, ok),
      process_loop(NewOptions);
    {'$gen_call', From, options} ->
      gen:reply(From, Options),
      process_loop(Options)
  end.






update_init_spec(_) ->
  Children1 = [
    #{id => first, start => {?MODULE, process_start_link, [#{key1 => value1}]}}
  ],
  application:set_env(kernel, test_sup_config_update_init_spec, Children1),

  {ok, SupPid} = reconfigurable_supervisor:start_link(?MODULE, [update_init_spec]),
  [{first,Pid,_,_}] = reconfigurable_supervisor:which_children(SupPid),
  #{key1 := value1} = gen_server:call(Pid, options),


  Children2 = [
    #{id => first, start => {?MODULE, process_start_link, [#{key1 => value2}]}}
  ],
  application:set_env(kernel, test_sup_config_update_init_spec, Children2),
  ok = reconfigurable_supervisor:reload_specs(SupPid),
  #{key1 := value2} = gen_server:call(Pid, options),


  gen_server:stop(SupPid),
  ok.





add_extra_children(_) ->
  Children1 = [
    #{id => first, start => {?MODULE, process_start_link, [#{name => first}]}}
  ],
  application:set_env(kernel, test_sup_config_add_extra_children, Children1),

  {ok, SupPid} = reconfigurable_supervisor:start_link(?MODULE, [add_extra_children]),
  [{first,Pid1,_,_}] = reconfigurable_supervisor:which_children(SupPid),
  #{name := first} = gen_server:call(Pid1, options),


  Children2 = [
    #{id => first, start => {?MODULE, process_start_link, [#{name => first}]}},
    #{id => second, start => {?MODULE, process_start_link, [#{name => second}]}}
  ],
  application:set_env(kernel, test_sup_config_add_extra_children, Children2),
  ok = reconfigurable_supervisor:reload_specs(SupPid),

  [{first,Pid1,_,_},{second,Pid2,_,_}] = reconfigurable_supervisor:which_children(SupPid),

  #{name := second} = gen_server:call(Pid2, options),


  gen_server:stop(SupPid),
  ok.





remove_old_children(_) ->
  Children1 = [
    #{id => first, start => {?MODULE, process_start_link, [#{name => first}]}},
    #{id => second, start => {?MODULE, process_start_link, [#{name => second}]}}
  ],
  application:set_env(kernel, test_sup_config_remove_old_children, Children1),

  {ok, SupPid} = reconfigurable_supervisor:start_link(?MODULE, [remove_old_children]),
  [{first,Pid1,_,_},{second,Pid2,_,_}] = lists:sort(reconfigurable_supervisor:which_children(SupPid)),
  #{name := first} = gen_server:call(Pid1, options),
  #{name := second} = gen_server:call(Pid2, options),


  Children2 = [
    #{id => first, start => {?MODULE, process_start_link, [#{name => first}]}}
  ],
  application:set_env(kernel, test_sup_config_remove_old_children, Children2),
  ok = reconfigurable_supervisor:reload_specs(SupPid),

  [{first,Pid1,_,_}] = reconfigurable_supervisor:which_children(SupPid),

  undefined = process_info(Pid2),

  gen_server:stop(SupPid),
  ok.





nested_supervisors(_) ->
  application:set_env(kernel, test_sup_config_nested_supervisors, [
    #{id => first, start => {?MODULE, process_start_link, [#{name => first}]}},
    #{id => second, start => {reconfigurable_supervisor, start_link, [?MODULE, [inner_supervisor]]}}
  ]),

  application:set_env(kernel, test_sup_config_inner_supervisor, [
    #{id => third, start => {?MODULE, process_start_link, [#{name => third}]}}
  ]),

  {ok, SupPid} = reconfigurable_supervisor:start_link(?MODULE, [nested_supervisors]),
  [{first,Pid1,_,_},{second,Pid2,_,_}] = lists:sort(reconfigurable_supervisor:which_children(SupPid)),
  #{name := first} = gen_server:call(Pid1, options),
  [{third,Pid3,_,_}] = reconfigurable_supervisor:which_children(Pid2),
  #{name := third} = gen_server:call(Pid3, options),


  application:set_env(kernel, test_sup_config_nested_supervisors, [
    #{id => first, start => {?MODULE, process_start_link, [#{name => first1}]}},
    #{id => second, start => {reconfigurable_supervisor, start_link, [?MODULE, [inner_supervisor]]}}
  ]),

  application:set_env(kernel, test_sup_config_inner_supervisor, [
    #{id => third, start => {?MODULE, process_start_link, [#{name => third1}]}}
  ]),

  ok = reconfigurable_supervisor:reload_specs(SupPid),

  [{first,Pid1,_,_},{second,Pid2,_,_}] = lists:sort(reconfigurable_supervisor:which_children(SupPid)),
  #{name := first1} = gen_server:call(Pid1, options),
  [{third,Pid3,_,_}] = reconfigurable_supervisor:which_children(Pid2),
  #{name := third1} = gen_server:call(Pid3, options),

  gen_server:stop(SupPid),
  ok.
