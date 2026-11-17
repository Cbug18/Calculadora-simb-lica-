libre_de(Exp, Var) :-
    Exp == Var, !, fail.
libre_de(Exp, _) :-
    var(Exp), !.
libre_de(Exp, _) :-
    atomic(Exp), !.
libre_de(Exp, Var) :-
    compound(Exp),
    Exp =.. [_|Args],
    forall(member(A, Args), libre_de(A, Var)).

valor_numerico(Exp, V) :-
    ground(Exp), catch(V is Exp, _, fail), number(V).

divide_entre_cero(Exp) :-
    compound(Exp), Exp = _/B, valor_numerico(B, V), V =:= 0, !.
divide_entre_cero(Exp) :-
    compound(Exp), Exp =.. [_|Args], member(A, Args), divide_entre_cero(A), !.