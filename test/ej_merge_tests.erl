% License: Apache License, Version 2.0
%
% Licensed under the Apache License, Version 2.0 (the "License");
% you may not use this file except in compliance with the License.
% You may obtain a copy of the License at
%
%     http://www.apache.org/licenses/LICENSE-2.0
%
% Unless required by applicable law or agreed to in writing, software
% distributed under the License is distributed on an "AS IS" BASIS,
% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
% See the License for the specific language governing permissions and
% limitations under the License.
%
%% @author Lyle Bertz <lyleb551144@gmail.com>
%% @copyright Copyright 2015 Lyle Bertz
%%
%% @doc Extensions to provide support for JSON Merge Patch (RFC 7396) 
%% and JSON Patch (RFC 6902). It uses ej (https://github.com/seth/ej).
%%
%% @end
-module(ej_merge_tests).
-author('Lyle Bertz <lyleb551144@gmail.com>').

-include_lib("eunit/include/eunit.hrl").   
     
test_patch_test_() ->
	 [{"patch: Test Test", fun() -> patch_testN_test(1) end},
	 {"patch: Remove Test", fun() -> patch_testN_test(2) end},
	 {"patch: Add Test", fun() -> patch_testN_test(3) end},
	 {"patch: Replace Test", fun() -> patch_testN_test(4) end},
	 {"patch: Move Test", fun() -> patch_testN_test(5) end},
	 {"patch: Copy Test", fun() -> patch_testN_test(6) end}].
	 		
patch_testN_test(N) ->
   %% Result of mochijson2:decode("{\"a\":{\"b\":{\"c\":\"foo\"}}}")
   Target={struct,[{<<"a">>,{struct,[{<<"b">>,{struct,[{<<"c">>,<<"foo">>}]}}]}}]},
   
   % CommandList is the result of successive mochijson2:decode on the following structures
   %["{ \"op\": \"test\", \"path\": \"/a/b/c\", \"value\": \"foo\" }",
   % "{ \"op\": \"remove\", \"path\": \"/a/b/c\" }",
   % "{ \"op\": \"add\", \"path\": \"/a/b/c\", \"value\": [\"foo\", \"bar\"] }",
   % "{ \"op\": \"replace\", \"path\": \"/a/b/c\", \"value\": 42 }",
   % "{ \"op\": \"move\", \"from\": \"/a/b/c\", \"path\": \"/a/b/d\" }",
   % "{ \"op\": \"copy\", \"from\": \"/a/b/d\", \"path\": \"/a/b/e\" }"],
     
   CommandList = [ {struct,[{<<"op">>,<<"test">>},{<<"path">>,<<"/a/b/c">>},{<<"value">>,<<"foo">>}]}, 
    {struct,[{<<"op">>,<<"remove">>},{<<"path">>,<<"/a/b/c">>}]},
    {struct,[{<<"op">>,<<"add">>},{<<"path">>,<<"/a/b/c">>},{<<"value">>,[<<"foo">>,<<"bar">>]}]},
    {struct,[{<<"op">>,<<"replace">>},{<<"path">>,<<"/a/b/c">>},{<<"value">>,42}]},
    {struct,[{<<"op">>,<<"move">>},{<<"from">>,<<"/a/b/c">>},{<<"path">>,<<"/a/b/d">>}]},
    {struct,[{<<"op">>,<<"copy">>},{<<"from">>,<<"/a/b/d">>},{<<"path">>,<<"/a/b/e">>}]} ],
	
	StructList= [ {struct,[{<<"a">>,{struct,[{<<"b">>,{struct,[{<<"c">>,<<"foo">>}]}}]}}]},
	{struct,[{<<"a">>,{struct,[{<<"b">>,{struct,[]}}]}}]},
	{struct,[{<<"a">>,{struct,[{<<"b">>,{struct,[{<<"c">>,[<<"foo">>,<<"bar">>]}]}}]}}]},
	{struct,[{<<"a">>,{struct,[{<<"b">>,{struct,[{<<"c">>,42}]}}]}}]},
	{struct,[{<<"a">>,{struct,[{<<"b">>,{struct,[{<<"d">>,42}]}}]}}]},
	{struct,[{<<"a">>,{struct,[{<<"b">>,{struct,[{<<"d">>,42},{<<"e">>,42}]}}]}}]} ],

	%%Concatenate the CommandList from 1 to N.
	_RCList = lists:reverse(CommandList),
	_List = lists:nthtail( length(_RCList)-N, _RCList),
	%Commands = "[" ++ string:join( lists:reverse(_List), ",") ++ "]",
    Commands = lists:reverse(_List),
    
    Result = ej_merge:patch(Target, Commands), 
    ?assertEqual(lists:nth(N,StructList), Result).
   
mergepatch_test() ->
	% result of mochijson2:decode("{ \"a\": \"b\", \"c\": { \"d\": \"e\", \"f\": \"g\" } }"),
	A = {struct,[{<<"a">>,<<"b">>},{<<"c">>,{struct,[{<<"d">>,<<"e">>},{<<"f">>,<<"g">>}]}}]},
	% result of mochijson2:decode("{ \"a\": \"z\", \"c\": { \"f\": null } }"),
	B = {struct,[{<<"a">>,<<"z">>},{<<"c">>,{struct,[{<<"f">>,null}]}}]},
	?assertEqual(ej_merge:mergepatch(A,B), {struct,[{<<"a">>,<<"z">>},{<<"c">>,{struct,[{<<"d">>,<<"e">>}]}}]}).
