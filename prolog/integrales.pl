:- ensure_loaded(utilidades).

s(Var, Exp, Integral) :-
    (var(Var) -> true; atom(Var)),
    integral_valida(Exp),
    ( Exp == Var -> Integral = 1/2*Var^2
    ; libre_de(Exp, Var) -> Integral = Exp*Var
    ; nonvar(Exp), once(integrar(Exp, Var, Integral))
    ).

integral_valida(Exp) :-
    ( var(Exp) -> true
    ; atomic(Exp) -> true
    ; Exp = A/B ->
        \+ (numero_integral(B, N), N =:= 0),
        integral_valida(A), integral_valida(B)
    ; Exp =.. [_|Args], maplist(integral_valida, Args)
    ).

numero_integral(Exp, N) :-
    ground(Exp), catch(N is Exp, _, fail), number(N).

integrar(Base^Exp, Var, Integral) :-
    Base == Var, numero_integral(Exp, N),
    ( N =:= -1 -> Integral = log(abs(Var))
    ; M is N+1, Integral = 1/M*Var^M
    ).
integrar(K/Base, Var, K*log(abs(Var))) :-
    Base == Var, libre_de(K, Var).
integrar(K/(Base^Exp), Var, Integral) :-
    Base == Var, libre_de(K, Var), numero_integral(Exp, N),
    ( N =:= 1 -> Integral = K*log(abs(Var))
    ; M is 1-N, Integral = K/M*Var^M
    ).
integrar(sen(F), Var, -cos(Var)) :- F == Var.
integrar(sin(F), Var, -cos(Var)) :- F == Var.
integrar(cos(F), Var, sen(Var)) :- F == Var.
integrar(sec(F)^2, Var, tan(Var)) :- F == Var.
integrar(exp(F), Var, exp(Var)) :- F == Var.
integrar(sqrt(F), Var, 2/3*Var^(3/2)) :- F == Var.
integrar(log(F), Var, Var*log(Var)-Var) :- F == Var.
integrar(ln(F), Var, Var*log(Var)-Var) :- F == Var.
integrar(K*F, Var, K*SF) :-
    libre_de(K, Var), s(Var, F, SF).
integrar(F*K, Var, SF*K) :-
    libre_de(K, Var), s(Var, F, SF).
integrar(F/K, Var, SF/K) :-
    libre_de(K, Var), s(Var, F, SF).
integrar(-F, Var, -SF) :- s(Var, F, SF).
integrar(F+G, Var, SF+SG) :- s(Var, F, SF), s(Var, G, SG).
integrar(F-G, Var, SF-SG) :- s(Var, F, SF), s(Var, G, SG).
