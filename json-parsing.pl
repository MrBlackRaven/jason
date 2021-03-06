%%%% Battiston Ilaria 816339
%%%% Di Gennaro Luca 820612

%%%% -*- Mode: Prolog -*-
%%%% json-parsing.pl

%%% json_parse(JSONString, Object).
%%% vero se una JSONString (una stringa SWI Prolog o un atomo Prolog)
%%% può venire scorporata come stringa, numero, json_obj o json_array

%%% object

json_parse({}, json_obj([])) :- !.

json_parse(JSONString, json_obj(ParsedObject)) :-
	string(JSONString),
    string_chars(JSONString, Chars),
    fix_string(Chars, FixedChars),
    string_chars(RealJSONString, FixedChars),
    catch(term_string(JSON, RealJSONString), _, false),
    JSON =.. [{}, Object],
    json_obj([Object], ParsedObject),
    !.

json_parse(JSONAtom, ParsedJSON) :-
    atom(JSONAtom),
    atom_string(JSONAtom, JSONString),
    json_parse(JSONString, ParsedJSON),
    !.

json_parse(JSON, json_obj(ParsedObject)) :-
    JSON =.. [{}, Object],
    json_obj([Object], ParsedObject),
    !.


%%% array

json_parse(ArrayString, json_array(ParsedArray)) :-
	string(ArrayString),
    catch(term_string(Array, ArrayString), _, false),
    json_array(Array, ParsedArray),
    !.

json_parse(ArrayAtom, ParsedJSON) :-
    atom(ArrayAtom),
    atom_string(ArrayAtom, ArrayString),
    json_parse(ArrayString, ParsedJSON),
    !.
	
json_parse(Array, json_array(ParsedArray)) :-
    json_array(Array, ParsedArray),
    !.


%%% json_obj(Object).

json_obj([], []) :- !.

json_obj([Member], [ParsedMember]) :-
    json_member(Member, ParsedMember),
    !.

json_obj([Object], [ParsedMember | ParsedMembers]) :-
    Object =.. [',', Member | MoreMembers],
    json_member(Member, ParsedMember),
    json_obj(MoreMembers, ParsedMembers),
    !.


%%% json_array(Elements)

json_array([], []) :- !.

json_array([Value | MoreElements], [ParsedValue | ParsedElements]) :-
    is_value(Value, ParsedValue),
    json_array(MoreElements, ParsedElements),
    !.


%%% json_member(Members)

json_member(Member, (ParsedAttribute, ParsedValue)) :-
    Member =.. [':', Attribute, Value],
    json_pair(Attribute, Value, ParsedAttribute, ParsedValue),
    !.

%%% json_pair(Pair)

json_pair(Attribute, Value, Attribute, ParsedValue) :-
    string(Attribute),
    is_value(Value, ParsedValue),
    !.


%%% json_value(Value)

is_value([], []) :- !.

is_value(Value, Value) :-
    string(Value), !.

is_value(Value, Value) :-
    number(Value), !.

is_value(Value, ParsedValue) :-
    json_parse(Value, ParsedValue), !.


%%% json_get(JSON_obj, Fields, Result).
%%% che risulta vero quando Result è recuperabile seguendo la catena
%%% di campi presenti in Fields (una lista) a partire da JSON_obj

%%% caso in cui Fields è una lista

json_get(PartialResult, [], PartialResult) :- !.

json_get(json_obj(ParsedObject), [Field | Fields], Result) :-
    json_get(json_obj(ParsedObject), Field, PartialResult),
    json_get(PartialResult, Fields, Result),
    !.

json_get(json_array(ParsedArray), [Field | Fields], Result) :-
    json_get(json_array(ParsedArray), Field, PartialResult),
    json_get(PartialResult, Fields, Result),
    !.

%%% caso in cui Fields è una stringa SWI Prolog

json_get(json_obj(ParsedObject), String, Result) :-
    string(String),
    get_string(ParsedObject, String, Result),
    !.

%%% caso in cui Fields è un numero

json_get(json_array(ParsedArray), N, Result) :-
    number(N),
    get_index(ParsedArray, N, Result),
    !.


%%% ricerca di un attributo fra gli oggetti

get_string(_, [], _) :-
    fail,
    !.

get_string([(Item1, Item2) | _], String, Result) :-
    String = Item1,
    Result = Item2,
    !.

get_string([(_) | Items], String, Result) :-
    get_string(Items, String, Result),
    !.


%%% ricerca di un indice in un array

get_index([Item | _], 0, Item) :- !.

get_index([], _, _) :-
    fail,
    !.

get_index([_ | Items], N, Result) :-
    N > 0,
    P is N-1,
    get_index(Items, P, Result),
    !.


%%% json_load(FileName, JSON)
%%% ha successo se riesce a costruire un oggetto JSON

json_load(FileName, JSON) :-
    catch(open(FileName, read, File), _, false),
    read_string(File, _, O),
    atom_string(Atom, O),
    catch(json_parse(Atom, JSON), _, false),
    close(File).


%%% json_write
%%% scrive l'oggetto JSON sul file FileName
%%% JSON è la stringa prolog

json_write(JSON, FileName) :-
    atom(FileName),
    json_revert(JSON, Term),
    json_fix(Term, JSONAtom),
    open(FileName, write, File),
    write(File, JSONAtom),
    close(File),
    !.

%%% se fallisce il fix (non ci sono {} quindi array)

json_write(JSON, FileName) :-
    atom(FileName),
    json_revert(JSON, JSONString),
    open(FileName, write, File),
    write(File, JSONString),
    close(File),
    !.


%%% rimuove gli apici singoli (chiamato nel parse)

fix_string(['\'' | Cs], ['"' | OtherCs]) :-
    fix_string(Cs, OtherCs),
    !.

fix_string([Char | Cs], [Char | OtherCs]) :-
    fix_string(Cs, OtherCs),
    !.

fix_string([], []) :- !.


%%% trasforma in sintassi JSON (chiamato nel write)

json_revert(json_array(O), JSONString) :-
    json_parse(JSONString, json_array(O)),
    !.

json_revert(json_obj([]), {}) :- !.

json_revert(json_obj(O), JSONString) :-
    json_revert(O, Pairs),
    JSONString =.. [{}, Pairs],
    !.

json_revert([], []) :- !.

json_revert([], [ParsedObjects]) :-
    JSONString =.. [{}, ParsedObjects],
    json_revert([], JSONString),
    !.

json_revert(([(O1, json_array(O2)) | Objects]), [Pair | Pairs]) :-
    json_parse(Array, json_array(O2)),
    Pair =.. [':', O1, Array],
    json_revert(Objects, Pairs),
    !.

json_revert(([(O1, O2) | Objects]), [Pair | Pairs]) :-
    Pair =.. [':', O1, O2],
    json_revert(Objects, Pairs),
    !.

json_fix(Term, JSONString) :-
    term_string(Term, String),
    string_chars(String, Chars),
    remove_parens(Chars, ParsedChars),
    string_chars(JSONString, ParsedChars),
    !.


%%% rimuove parentesi in eccesso, aggiunge spazi
%%% dopo le virgole e intorno ai :

remove_parens(['{', '[' | SomeChars], ['{' | OtherChars]) :-
    remove_parens(SomeChars, OtherChars),
    !.

remove_parens([']', '}'], ['}']) :- !.

remove_parens([':' | SomeChars], [' ', ':', ' ' | OtherChars]) :-
    remove_parens(SomeChars, OtherChars),
    !.

remove_parens([',' | SomeChars], [',', ' ' | OtherChars]) :-
    remove_parens(SomeChars, OtherChars),
    !.

remove_parens([Char | SomeChars], [Char | OtherChars]) :-
    remove_parens(SomeChars, OtherChars),
    !.


%%%% end of file -- json-parsing.pl
