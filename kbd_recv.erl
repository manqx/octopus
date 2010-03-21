%% ---
%%
%% NPORT 5150 driver 
%% Host = "192.168.0.232"
%% Port = 4001
%% 
%% ---

-module(kbd_recv).
-compile(export_all).
-import(lists, [reverse/1]).


start_receiver(Host,Port) ->
    spawn(fun() -> receiver(Host,Port) end).

receiver(Host,Port) ->
    {ok, Socket} = 
	gen_tcp:connect(Host, Port,
			[binary, {packet, 0}]),
    %%    ok = gen_tcp:send(Socket, term_to_binary(Str)),
    recv_loop(Socket,[]).

recv_loop(Socket,Sofar) ->
    receive
	{tcp,Socket,Bin} ->
	    %%	    io:format("Client received binary = ~p~n",[Bin]),
	    Val = binary_to_list(Bin),
	    io:format("Client result = ~p~n",[Val]),
	    recv_loop(Socket,[Val | Sofar]);
	{send,Str} ->
	    ok = gen_tcp:send(Socket, term_to_binary(Str)),
	    recv_loop(Socket,Sofar);
	{From,{get}} ->
	    From ! Sofar,
	    recv_loop(Socket,[]);
	{tcp_closed, Socket} ->
	    io:format("Server socket closed~n"),
	    gen_tcp:close(Socket)
    end.


test() ->
    start_receiver("192.168.0.232",4001).

get_test(Pid) ->
    Pid ! {self(),{get}},
    receive
	Response ->
	    lists:flatten(reverse(Response))
    end.


-record(key_board,{
	  state=ready,
	  id,
	  word,
	  arg1=[],
	  arg2=[]
	 }).

parse(L) ->
    X=#key_board{},
    parse(L,X,0).

parse([H|T],X,Num) ->
    #key_board{state = State} = X,
    case State of
	ready  ->
	    case H of
		$*  ->
		    State1 = start;
		_   ->
		    State1 = ready
	    end,
	    parse(T,X#key_board{state = State1},0);
	start ->
	    case is_numeric(H)  of
		true  ->
		    F = H - $0,
		    NumX = Num * 10 + F,
		    State1 = id;
		false ->
		    State1 = ready,
		    NumX = 0
	    end,
	    parse(T,X#key_board{state = State1},NumX);
	id ->
	    case is_numeric(H)  of
		true  ->
		    F = H - $0,
		    NumX = Num * 10 + F,
		    parse(T,X,NumX);
		false ->
		    case H of
			$K ->
			    parse(T,X#key_board{state = action,id = Num},0);
			$D ->
			    parse(T,X#key_board{state = show,id = Num},0);
			$Z ->
			    parse(T,X#key_board{state = reset,id = Num},0);
			$*  ->
			    parse(T,#key_board{state = start},0);
			_  ->
			    parse(T,#key_board{state = ready},0)
		    end
	    end;

	action ->
	    case is_numeric(H)  of
		true  ->
		    F = H - $0,
		    NumX = Num * 10 + F,
		    parse(T,X,NumX);
		false ->
		    case H of
			$, ->
			    State1 = code;
			$*  ->
			    State1 = start;
			_  ->
			    State1 = ready
		    end,
		    parse(T,X#key_board{state = State1},0)
	    end;
	code ->
	    case is_numeric(H)  of
		true  ->
		    F = H - $0,
		    NumX = Num * 10 + F,
		    parse(T,X,NumX);
		false ->
		    case H of
			$, ->
			    parse(T,X#key_board{state = act_val,arg1 = Num},0);
			$*  ->
			    parse(T,#key_board{state = start},0);
			_  ->
			    parse(T,#key_board{state = ready},0)
		    end
	    end;
	act_val ->
	    case is_numeric(H)  of
		true  ->
		    F = H - $0,
		    NumX = Num * 10 + F,
		    parse(T,X,NumX);
		false ->
		    case H of
			$\r ->
			    {ok,X#key_board{word = action,arg2 = Num,state = finish},T};
			$*  ->
			    parse(T,#key_board{state = start},0);
			_  ->
			    parse(T,#key_board{state = ready},0)
		    end
	    end;

 	show   ->
	    case is_numeric(H)  of
		true  ->
		    F = H - $0,
		    NumX = Num * 10 + F,
		    parse(T,X,NumX);
		false ->
		    case H of
			$, ->
			    parse(T,X#key_board{state = show_str1},0);
			$*  ->
			    parse(T,#key_board{state = start},0);
			_  ->
			    parse(T,#key_board{state = ready},0)
		    end
	    end;

	show_str1 ->
	    case H of
		$, ->
		    parse(T,X#key_board{state = show_str2,arg1 = reverse(X#key_board.arg1)},0);
		$*  ->
		    parse(T,#key_board{state = start},0);
		_  ->
		    parse(T,X#key_board{arg1 = [H | X#key_board.arg1]},0)
	    end;
	show_str2 ->
	    case H of
		$\r ->
		    {ok,X#key_board{word = show,arg2 = reverse(X#key_board.arg2),state = finish},T};
		$*  ->
		    parse(T,#key_board{state = start},0);
		_  ->
		    parse(T,X#key_board{arg2 = [H | X#key_board.arg2]},0)
	    end;
 	reset  ->
	    case H of
		$\r ->
		    {ok,X#key_board{word = reset,state = finish},T};
		$*  ->
		    parse(T,#key_board{state = start},0);
		_  ->
		    parse(T,X,0)
	    end;
	_   ->
	    parse(T,X,Num)
	end;

parse([],X,_) ->
    {error,X,[]}.

is_numeric(N) ->
    if 
	is_integer(N), N >= $0 , N =< $9 ->
	    true;
	true ->
	    false
    end.


