// Tests for public/parser.js:  node test/parser.test.js
const assert = require('node:assert/strict');
const { parse, toLatex, toProlog, evaluate } = require('../public/parser.js');

const cases = [
  // [input, expected Prolog, expected LaTeX]
  ['4*x^4 + sin(x)', '4 * x ^ 4 + sen(x)', '4\\,x^{4} + \\operatorname{sen}(x)'],
  ['2x^2', '2 * x ^ 2', '2\\,x^{2}'],
  ['-x^2', '-(x ^ 2)', '-x^{2}'],
  ['x^-1', 'x ^ (-1)', 'x^{-1}'],
  ['e^x', 'exp(x)', 'e^{x}'],
  ['ln(x)', 'log(x)', '\\ln(x)'],
  ['sinx', 'sen(x)', '\\operatorname{sen}(x)'],
  ['(x+1)(x-1)', '(x + 1) * (x - 1)', '\\left(x + 1\\right)\\,\\left(x - 1\\right)'],
  ['a-(b-c)', 'a - (b - c)', 'a - \\left(b - c\\right)'],
  ['2^3^2', '2 ^ 3 ^ 2', '2^{3^{2}}'],
  ['(2^3)^2', '(2 ^ 3) ^ 2', '\\left(2^{3}\\right)^{2}'],
  ['√x + π', 'sqrt(x) + pi', '\\sqrt{x} + \\pi'],
  ['der(x^2, x)', 'der(x ^ 2, x)', '\\frac{d}{dx}\\left[x^{2}\\right]'],
  ['der(x^2)', 'der(x ^ 2, x)', '\\frac{d}{dx}\\left[x^{2}\\right]'],
  ['int(x+1, t)', 'int(x + 1, t)', '\\int \\left(x + 1\\right)\\,dt'],
  ['int(sen x, x, 0, pi)', 'int(sen(x), x, 0, pi)', '\\int_{0}^{\\pi} \\operatorname{sen}(x)\\,dx'],
  ['2der(int(x,x),x)', '2 * der(int(x, x), x)', '2 \\cdot \\frac{d}{dx}\\left[\\int x\\,dx\\right]'],
];
for (const [src, pl, tx] of cases) {
  const ast = parse(src);
  assert.equal(toProlog(ast), pl, `toProlog(${src})`);
  assert.equal(toLatex(ast), tx, `toLatex(${src})`);
}

// Prolog output -> LaTeX
const fromProlog = [
  ['16*x^3+cos(x)', '16\\,x^{3} + \\cos(x)'],
  ['4*x^5/5-cos(x)', '\\frac{4\\,x^{5}}{5} - \\cos(x)'],
  ['1/(2*x^(1/2))', '\\frac{1}{2\\,\\sqrt{x}}'],
  ['log(x)+3/ -1*x^ -1', '\\ln(x) + \\frac{3}{-1}\\,x^{-1}'],
  ['sec(x)^2', '\\sec^{2}(x)'],
  ['1/2*x^2', '\\frac{1}{2}\\,x^{2}'],
  ['x- -sen(x)', 'x - \\left(-\\operatorname{sen}(x)\\right)'],
  ['2*(1/2*x^2)', '2 \\cdot \\frac{1}{2}\\,x^{2}'],
];
for (const [src, tx] of fromProlog) assert.equal(toLatex(parse(src)), tx, `latex(${src})`);

assert.equal(evaluate(parse('pi/2')), Math.PI / 2);
assert.equal(evaluate(parse('3x^2'), { x: 2 }), 12);
assert.throws(() => parse('3 +'));
assert.throws(() => parse('x $ 2'));
assert.throws(() => parse('int(x, x, 0)'));     // aridad inválida
assert.throws(() => parse('der(x, 2)'));        // la variable debe ser un símbolo
assert.throws(() => parse('der x'));            // der necesita paréntesis

console.log(`parser: ${cases.length + fromProlog.length + 7} checks passed`);
