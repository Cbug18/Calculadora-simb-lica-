// Tests of the JSON protocol of prolog/main.pl:  node test/api.test.js
// All requests go to a single swipl process, one JSON object per line,
// the same way the server talks to it.
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const path = require('node:path');

const MAIN = path.join(__dirname, '..', 'prolog', 'main.pl');

function run(requests) {
  const input = requests.map((r) => (typeof r === 'string' ? r : JSON.stringify(r))).join('\n') + '\n';
  const out = spawnSync('swipl', [MAIN], { input, encoding: 'utf8', timeout: 60000 });
  if (out.error) throw new Error(`could not start swipl (is SWI-Prolog installed?): ${out.error.message}`);
  const lines = out.stdout.trim().split('\n');
  assert.equal(lines.length, requests.length, `one response per request\nstderr: ${out.stderr}`);
  return lines.map((l) => JSON.parse(l));
}

const OK_KEYS = ['constant', 'decimal', 'evaluation', 'ok', 'result', 'steps'];

// [request, check(response)]
const cases = [
  // Contract: field names and types
  [{ expr: 'der(x ^ 3, x)' }, (r) => {
    assert.deepEqual(Object.keys(r).sort(), OK_KEYS);
    assert.equal(r.ok, true);
    assert.equal(r.result, '3*x^2');
    assert.equal(r.constant, false);
    assert.equal(r.decimal, null);
    assert.equal(r.evaluation, null);
    assert.equal(r.steps.length, 1);
    assert.equal(r.steps[0].op, 'der');
    assert.equal(r.steps[0].query, 'd(x, x^3, R)');
    assert.equal(r.steps[0].retry, null);
  }],
  // Exactly what parser.js emits
  [{ expr: 'der(4 * x ^ 4 + sen(x), x)' }, (r) => assert.equal(r.result, '16*x^3+cos(x)')],
  [{ expr: 'der(3 * x ^ 2 - 5 * x + 1, x)' }, (r) => assert.equal(r.result, '6*x-5')],
  [{ expr: 'der(x / 2 + 1 / x, x)' }, (r) => assert.equal(r.result, '1/2-1/x^2')],
  [{ expr: 'der(e ^ x + sqrt(x), x)' }, (r) => assert.equal(r.result, 'exp(x)+1/(2*sqrt(x))')],
  // Product rule: x*x no longer needs the retry as x^2
  [{ expr: 'der(x * x, x)' }, (r) => {
    assert.equal(r.result, '2*x');
    assert.equal(r.steps[0].retry, null);
  }],
  [{ expr: 'der(x ^ (-1), x)' }, (r) => assert.equal(r.result, '- (1/x^2)')],
  [{ expr: '2 * der(int(x, x), x)' }, (r) => assert.equal(r.result, '2*x')],
  // README example
  [{ expr: 'der(x^3, x) + int(sen(x), x, 0, pi)' }, (r) => {
    assert.equal(r.result, '3*x^2+2');
    assert.equal(r.steps.length, 2);
  }],
  // Indefinite integral: + C
  [{ expr: 'int(sen(x), x)' }, (r) => {
    assert.equal(r.result, '-cos(x)');
    assert.equal(r.constant, true);
  }],
  [{ expr: 'der(int(x ^ 2, x), x)' }, (r) => {
    assert.equal(r.result, 'x^2');
    assert.equal(r.constant, false);
  }],
  // Retry with the simplified / expanded input
  [{ expr: 'int(x * x, x)' }, (r) => {
    assert.equal(r.result, 'x^3/3');
    assert.equal(r.steps[0].retry, 'simplificada');
    assert.equal(r.steps[0].query, 's(x, x^2, R)');
  }],
  [{ expr: 'int((x + 1) ^ 2, x)' }, (r) => {
    assert.equal(r.result, 'x^3/3+x^2+x');
    assert.equal(r.steps[0].retry, 'expandida');
  }],
  // Definite integrals
  [{ expr: 'int(cos(x), x, 0, pi / 2)' }, (r) => {
    assert.equal(r.result, '1');
    assert.equal(r.decimal, 1);
    assert.equal(r.constant, false);
    assert.equal(r.steps[0].antiderivative, 'sen(x)');
    assert.equal(r.steps[0].from, '0');
    assert.equal(r.steps[0].to, 'pi/2');
  }],
  [{ expr: 'int(1 / x, x, 1, 2)' }, (r) => {
    assert.equal(r.result, 'log(2)');
    assert.ok(Math.abs(r.decimal - Math.LN2) < 1e-12);
  }],
  [{ expr: 'int(x, x, 0, a)' }, (r) => assert.equal(r.result, 'a^2/2')],
  // Simplification only
  [{ expr: 'sen(x) ^ 2 + cos(x) ^ 2' }, (r) => {
    assert.equal(r.result, '1');
    assert.equal(r.steps[0].op, 'simplificar');
  }],
  [{ expr: 'sqrt(8)' }, (r) => {
    assert.equal(r.result, '2*sqrt(2)');
    assert.ok(Math.abs(r.decimal - Math.sqrt(8)) < 1e-12);
  }],
  // evalVar / evalAt
  [{ expr: 'der(x ^ 2, x)', evalVar: 'x', evalAt: '3' }, (r) => {
    assert.deepEqual(r.evaluation, { var: 'x', at: '3', result: '6', decimal: 6 });
  }],
  [{ expr: 'sen(t)', evalVar: 't', evalAt: 'pi / 6' }, (r) => {
    assert.equal(r.evaluation.result, '1/2');
    assert.equal(r.evaluation.decimal, 0.5);
  }],
  [{ expr: 'x ^ 2', evalAt: '' }, (r) => assert.equal(r.evaluation, null)],
  // Errors: {ok: false, error}
  ...[
    'der(x^2, x',            // syntax
    'foo(x)',                // unknown function
    'X + 1',                 // Prolog variable
    'der(x^2, 2)',           // the variable must be a symbol
    'int(x, x, 0)',          // wrong arity
    'x / 0',                 // division by zero
    'log(0)',
    'tan(pi / 2)',
    'int(sen(2 * x), x)',    // no rule
    'int(1 / x, x, -1, 1)',  // improper integral
  ].map((expr) => [{ expr }, (r) => {
    assert.deepEqual(Object.keys(r).sort(), ['error', 'ok'], expr);
    assert.equal(r.ok, false);
    assert.ok(typeof r.error === 'string' && r.error.length > 0, expr);
  }]),
  [{ expr: 'x', evalVar: 'pi', evalAt: '1' }, (r) => assert.equal(r.ok, false)],
  [{}, (r) => assert.match(r.error, /expr/)],
  [{ expr: 42 }, (r) => assert.equal(r.ok, false)],
  ['not json', (r) => assert.equal(r.ok, false)],
  // The process keeps answering after errors
  [{ expr: '1 + 1' }, (r) => assert.equal(r.result, '2')],
];

const responses = run(cases.map(([req]) => req));
cases.forEach(([req, check], i) => {
  try {
    check(responses[i]);
  } catch (e) {
    e.message = `${JSON.stringify(req)} -> ${JSON.stringify(responses[i])}\n${e.message}`;
    throw e;
  }
});

console.log(`api: ${cases.length} checks passed`);
