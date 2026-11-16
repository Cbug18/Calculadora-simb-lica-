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