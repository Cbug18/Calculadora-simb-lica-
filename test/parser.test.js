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
  // Exponencial con otra base: a^x se queda como potencia (solo e^x pasa a exp)
  ['2^x', '2 ^ x', '2^{x}'],
  ['a^(3x)', 'a ^ (3 * x)', 'a^{3\\,x}'],
  // Hiperbólicas (sinh es sinónimo de senh)
  ['sinh(x)', 'senh(x)', '\\operatorname{senh}(x)'],
  ['cosh(2x)', 'cosh(2 * x)', '\\cosh\\left(2\\,x\\right)'],
  ['tanh(x^2)', 'tanh(x ^ 2)', '\\tanh\\left(x^{2}\\right)'],
  ['sech(x) + csch(x) + coth(x)', 'sech(x) + csch(x) + coth(x)',
    '\\operatorname{sech}(x) + \\operatorname{csch}(x) + \\coth(x)'],
  // Trigonométricas inversas (asin y arcsin son sinónimos de arcsen)
  ['asin(x)', 'arcsen(x)', '\\operatorname{arcsen}(x)'],
  ['arcsin(2x)', 'arcsen(2 * x)', '\\operatorname{arcsen}\\left(2\\,x\\right)'],
  ['acos(x) + atan(x)', 'arccos(x) + arctan(x)', '\\arccos(x) + \\arctan(x)'],
  // Hiperbólicas inversas
  ['asinh(x)', 'arcsenh(x)', '\\operatorname{arcsenh}(x)'],
  ['arccosh(x) - arctanh(x)', 'arccosh(x) - arctanh(x)',
    '\\operatorname{arccosh}(x) - \\operatorname{arctanh}(x)'],
  // Antes "senh" se leía como sen(h) y "asin" como a*sen
  ['xsenh(x)', 'x * senh(x)', 'x\\,\\operatorname{senh}(x)'],
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
  ['sech(x)^2', '\\operatorname{sech}^{2}(x)'],
  ['-csch(x)^2', '-\\operatorname{csch}^{2}(x)'],
  ['arctan(x)^2', '\\left(\\arctan(x)\\right)^{2}'],
  ['1/sqrt(1-x^2)', '\\frac{1}{\\sqrt{1 - x^{2}}}'],
  ['2^x*log(2)', '2^{x}\\,\\ln(2)'],
];
for (const [src, tx] of fromProlog) assert.equal(toLatex(parse(src)), tx, `latex(${src})`);

assert.equal(evaluate(parse('pi/2')), Math.PI / 2);
assert.equal(evaluate(parse('3x^2'), { x: 2 }), 12);
assert.equal(evaluate(parse('senh(1)'), {}), Math.sinh(1));
assert.equal(evaluate(parse('sech(0)'), {}), 1);
assert.equal(evaluate(parse('arctan(1)'), {}), Math.PI / 4);
assert.equal(evaluate(parse('arcsenh(1)'), {}), Math.asinh(1));
assert.equal(evaluate(parse('2^x'), { x: 3 }), 8);
assert.throws(() => parse('3 +'));
assert.throws(() => parse('x $ 2'));
assert.throws(() => parse('int(x, x, 0)'));     // aridad inválida
assert.throws(() => parse('der(x, 2)'));        // la variable debe ser un símbolo
assert.throws(() => parse('der x'));            // der necesita paréntesis

console.log(`parser: ${cases.length + fromProlog.length + 12} checks passed`);
