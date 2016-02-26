:- use_module(library(process)).

config(keyboard(`3`)).

main :-
    load_mapping,
    listen_events(Stream),
    loop(Stream).
main :- write('main failed'), nl.

listen_events(Stream) :-
    write("Listening to events..."), nl,
    process_create(path(cnee), ['--record', '--keyboard'], [stdout(pipe(Stream))]), !.
listen_events :- write('listen_events failed'), nl.

loop(Stream) :- loop(Stream, up-up-up-up).

loop(Stream, Mods) :-
    read_line_to_codes(Stream, Line),
    ( Line = end_of_file
     ; ( phrase(cnee_line(Parsed), Line), !,
         act(Parsed, Mods, NewMods)
       ; NewMods=Mods),
     !, loop(Stream, NewMods)).

act(X-control, _-A-W-S, X-A-W-S).
act(X-alt, C-_-W-S, C-X-W-S).
act(X-win, C-A-_-S, C-A-X-S).
act(X-shift, C-A-W-_, C-A-W-X).
act(up-_, M, M).
act(down-K, C-A-W-S, C-A-W-S) :-
    format_modifiers([C,A,W], ["Ctrl-", "Alt-", "Win-"], P),
    format_key(S, K, PP),
    write(P), write(PP), nl.

format_modifiers([], [], "").
format_modifiers([M|Ms], [S|Ss], X) :-
    format_modifiers(Ms, Ss, XX),
    (M=down, XXX=S; XXX=""),
    string_concat(XXX, XX, X).

format_key(down, key(_, N), N).
format_key(up, key(N, _), N).

load_mapping :-
    write('Loading key mapping from xmodmap...'), nl,
    process_create(path(xmodmap), ['-pk'], [stdout(pipe(MappingStream))]),
    read_string(MappingStream, _, MappingString), 
    string_codes(MappingString, MappingCodes),
    skip_header(MappingCodes, Body),
    parse_mapping(Body),
    !.
load_mapping :- write('load_mapping failed'), nl.

:- dynamic(keyinfo/3).

skip_header(A, B) :- phrase(header, A, B).

parse_mapping(``).
parse_mapping(MappingString) :-
    phrase(mapping_line(N, Name1, Name2), MappingString, Rest),
    makeinfo(Name1, Name2, Info),
    asserta(keyinfo(N, Info)), !,
    parse_mapping(Rest).

mapping_line(N, Name1, Name2) -->
    whites, num(N),
    (whites, word(_), space, paren(word(Name1)) ; {Name1=`NoSymbol`}),
    (whites, word(_), space, paren(word(Name2)) ; {Name2=`NoSymbol`}),
    line(_).

dbg(M, [], []) :- print(dbg-M-'EOF'), nl.
dbg(M, A, A) :-
    length(A, N), X is min(N, 20), length(K, X), append(K, _, A),
    string_codes(S, K), print(dbg-M-S), nl.

space --> ` `.
white --> ` `; `\t`.
whites --> white, !, (whites, !; []).

digit(C) --> [C], { member(C, `0123456789`) }.
digits([C|Cs]) --> digit(C), (digits(Cs), ! ; [], {Cs=[]}).

num(N) --> digits(Cs), { read_from_codes(Cs, N) }.

word([C|Cs]) --> [C], { not(member(C, ` ()`)) }, (word(Cs), ! ; [], {Cs=[]}).

paren(P) --> `(`, P, `)`.

line([C|Cs]) --> `\n`, !; [C], line(Cs).

header --> line(_), line(_), line(_), line(_), line(_).

makeinfo(N, _, control) :- append(`Control_`, _, N).
makeinfo(N, _, shift) :- append(`Shift_`, _, N).
makeinfo(N, _, alt) :- append(`Alt_`, _, N).
makeinfo(N, _, win) :- append(`Super_`, _, N).
makeinfo(N1, N2, key(A1, A2)) :-
    rename(N1, R1), rename(N2, R2),
    atom_codes(A1, R1), atom_codes(A2, R2).

rename(`NoSymbol`, `unknown`).
rename(A, A).

list([``|Xs]) --> `,`, !, list(Xs).
list([[C|Cs]|Xs]) --> [C], !, list([Cs|Xs]).
list([[]]) --> [].

cnee_line(How-What) -->
    { config(keyboard(K)) },
    list([_,Event,_,_,_,KeyCodeS,_,_,K,_]),
    { parse_event(Event, How),
      number_codes(KeyCode, KeyCodeS),
      keyinfo(KeyCode, What) }.

parse_event(`2`, down).
parse_event(`3`, up).
