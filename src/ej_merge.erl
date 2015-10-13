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
%% @doc Extensions of the ej module (http://github.com/set/ej) to provide
%% support for JSON Merge Patch (RFC 7396) and JSON Patch (RFC 6902).
%%
%% @end
-module(ej_merge).
-author('Lyle Bertz <lyleb551144@gmail.com>').

-export([
	mergepatch/2,
	patch/2
]).

-include_lib("ej/include/ej.hrl").

%% @doc RFC 7396 - JSON Merge Patch Function  
%%
%% This function implements Merge Patch processing as specified in RFC
%% 7396 Section 2.  The processing specified by the Patch document is 
%% applied to the Target Document.  The result is returned.
%%
%% 'Target' is a and JSON document compliant to RFC 7159 that has been
%% decoded by a parser support by mochijson2.
%% 'Patch' is a JSON Merge Patch document as defined in RFC 7396 that
%% has been decoded by a parser support by mochijson2.
%% 
%%  NOTES: The result is NOT a JSON Document (string) but a mochjson2 
%%  data structure. See ej (https://github.com/seth/ej) for the spec 
%%  types.
%% @end
%%
-spec mergepatch(json_term(), json_term()) -> json_term().

mergepatch(Target, Patch) ->
	case is_object(Patch) of
		true ->
			Target0 = case is_object(Target) of 
				true -> Target;
				false -> {struct,[]}
			end,
			processAttributes(get_attribute_names(Patch), Patch, Target0);
		false ->
			Patch
	end.

get_attribute_names({L}) when is_list(L) ->
	proplists:get_keys(L);
get_attribute_names({struct,L}) when is_list(L) ->
	proplists:get_keys(L);
get_attribute_names(_) ->
	[].

is_object({L}) when is_list(L) ->
	true;
is_object({struct,L}) when is_list(L) ->
	true;
is_object(_) ->
	false.
					
processAttributes([], _, Target) ->
	Target;
processAttributes([H|T], Patch, Target) ->
	Value = ej:get({H},Patch), 
	Target0 = case null =:= Value of
		true -> %% delete value
			ej:delete({H},Target);
		false -> %% set value
			ej:set( {H}, Target, mergepatch( ej:get({H},Target), Value ) )
	end,
	processAttributes(T, Patch, Target0).

%% Converts RFC 6901 JSON Pointer to a tuple and string format with special 
%% characters returned their value.
%% NOTE: This will leave the '-' in the list - not every JSONPointer is ej friendly.
to_ej_path(JSONPointer) when is_list(JSONPointer) ->
	to_ej_path( list_to_binary(JSONPointer) );
to_ej_path(JSONPointer) when is_binary(JSONPointer) ->
	_Segments = binary:split(JSONPointer, <<"/">>, [global]),
	_TempList = lists:foldl(fun process_segment/2, [], _Segments),
	_TempList2 = lists:reverse(_TempList),
	case lists:last(_TempList2) of
		"-" ->
			{ unassigned_index, _TempList2 };
		_ -> 
			{ direct_reference, _TempList2 }
	end.	
	
process_segment(E, AccIn) ->
	_a = binary:replace(E,<<"~0">>,<<"~">>,[global]),
	_b = binary:replace(_a,<<"~1">>,<<"/">>,[global]),
	case _b of
		<<>> -> 
			AccIn;
		_ -> 
			[ binary_to_list(_b) ] ++ AccIn
	 end.

%% @doc Executes RFC 6902 JSON Patch function
%%  
%% This function implements the operations and process identified in 
%% IETF RFC 6902 (see NOTE).   It uses JSONPointer (RFC 6901) for path 
%% references.
%% 
%% 'Target' is a and JSON document compliant to RFC 7159 that has been
%% decoded by a parser support by mochijson2.
%% 'Commas' is a JSON Merge Patch document as defined in RFC 7396 that
%% has been decoded by a parser support by mochijson2.
%%
%%  NOTES: The result is NOT a JSON Document (string) but a mochjson2 
%%  data structure. See ej (https://github.com/seth/ej) for the spec 
%%  types.
%%
%%  NOTE WELL: The "test" operation relies on equality which in this 
%%  module relies on erlang lists:sort and erlang sorting mechanisms. 
%% @end
%%
-spec patch(json_term(), json_array()) -> json_term().

patch(Target, []) ->
	Target;
patch(Target, [Command|T]) ->
	_Path = to_ej_path( ej:get({"path"}, Command) ),
	_NewTarget = case ej:get({"op"}, Command) of
		<<"add">> ->
			ej:set( extract_path(_Path), Target, ej:get({"value"}, Command) );
		<<"remove">> ->
			ej:delete( extract_direct_ref(_Path), Target);
		<<"replace">> ->
			ej:set( extract_direct_ref(_Path), Target, ej:get({"value"}, Command) );
		<<"move">> ->
			_From = extract_direct_ref( to_ej_path( ej:get({"from"}, Command) ) ),
			_Value = ej:get(_From, Target),
			_Targ0 = ej:delete(_From, Target),
			ej:set( extract_direct_ref(_Path), _Targ0, _Value);
		<<"copy">> ->
			_From1 = extract_direct_ref (to_ej_path( ej:get({"from"}, Command) ) ),
			_Value1 = ej:get(_From1, Target),
			ej:set( extract_direct_ref(_Path), Target, _Value1 );
		<<"test">> ->
			_PathValue = ej:get( extract_direct_ref(_Path), Target ),
			_CompareValue = ej:get( {"value"}, Command ),
			case equivalent(_PathValue, _CompareValue) of
				true -> Target;
				false -> throw(failed_test)
			end;
		_ ->
			throw(badarg)
	end,
	patch(_NewTarget, T).

extract_path({ direct_reference, L }) ->
	L;
extract_path({ unassigned_index, L }) ->
	lists:droplast(L);
extract_path(_)->
	throw(badarg).

extract_direct_ref({ direct_reference, L }) ->
	L;
extract_direct_ref(_) ->
	throw(badarg).

equivalent(Item1, Item2) when is_tuple(Item1) andalso is_tuple(Item2) ->
	to_list(Item1) =:= to_list(Item2);
equivalent(Item1, Item2) when is_list(Item1) andalso is_list(Item2) ->
	to_list(Item1) =:= to_list(Item2);
equivalent(Item1, Item2) ->
	Item1 =:= Item2.

to_list(Item) when is_tuple(Item) ->
	to_list(tuple_to_list(Item));
to_list(Item) when is_list(Item) ->
	lists:sort(lists:foldl(fun(E, AccIn) -> to_list(E) ++ AccIn end, [], Item));
to_list(Item) -> 
	Item.
