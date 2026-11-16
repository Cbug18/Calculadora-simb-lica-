# Prolog Calculator

A web calculator for symbolic **derivatives**, **integrals** and **simplification**. The math is done by a Prolog knowledge base, and the results are shown in LaTeX (KaTeX).

## Run

```bash
brew install swi-prolog   # once
npm install               # once
npm start                 # http://localhost:3000
npm test                  # parser + Prolog tests
```

## How it works

```
browser (public/)                    server.js                 prolog/
 text ──parser.js──► Prolog term ──► POST /api/calc ──► swipl main.pl ──► d/3, s/3, simplificar/2
 LaTeX ◄──parser.js── result text ◄──────── JSON ◄──────────────┘
```

| File | Role |
|---|---|
| `prolog/derivadas_2026_02_sec01.pl` | derivative rules `d(Var, Exp, D)` |
| `prolog/integrales.pl` | integral rules `s(Var, Exp, I)` |
| `prolog/simplificador.pl` | `simplificar/2` (collects like terms, folds constants, expands small powers) and `evaluar/4` |
| `prolog/utilidades.pl` | `libre_de/2`: tells whether an expression is constant w.r.t. the variable |
| `prolog/main.pl` | reads a JSON request on stdin, queries the KB, writes JSON |
| `public/parser.js` | text ⇄ AST ⇄ LaTeX / Prolog |

The server first queries the KB with the expression exactly as it was typed. If no rule matches (for example `x*x`), it simplifies the input (`x^2`) and queries again. The UI tells you when this happens.

Manual test without the UI:

```bash
echo '{"expr":"der(x^3, x) + int(sen(x), x, 0, pi)"}' | swipl prolog/main.pl
```

## Input syntax

Like a scientific calculator, one expression can mix everything, and the **=** key computes it:

| Keypad | Text | Meaning |
|---|---|---|
| d/dx | `der(f, x)` | derivative (uses `d/3`) |
| ∫dx | `int(f, x)` | indefinite integral (uses `s/3`, adds `+ C`) |
| ∫ₐᵇdx | `int(f, x, a, b)` | definite integral, exact `F(b) - F(a)` |

Operators can be nested and combined: `der(int(x^2, x), x)`, `2*der(x^3, x) + int(cos(x), x, 0, pi/2)`.
If the result is a number, a decimal approximation is shown too. **Ans** inserts the previous result.

`4x^4 + sin x`, `3/x^2`, `sqrt(x)`, `e^x`, `ln(x)`, `pi`. Implicit multiplication works. `sin` is sent as `sen`, `ln` as `log`, and `e^x` as `exp(x)`.
