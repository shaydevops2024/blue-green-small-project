const express = require('express');

const app = express();
app.use(express.json());

app.get('/health', (_req, res) => res.json({ status: 'ok' }));

app.post('/calculate', (req, res) => {
  const { a, b, operation } = req.body;

  if (a === undefined || b === undefined || !operation) {
    return res.status(400).json({ error: 'a, b, and operation are required' });
  }
  if (typeof a !== 'number' || typeof b !== 'number') {
    return res.status(400).json({ error: 'a and b must be numbers' });
  }

  let result;
  switch (operation) {
    case '+': result = a + b; break;
    case '-': result = a - b; break;
    case '*': result = a * b; break;
    case '/':
      if (b === 0) return res.status(400).json({ error: 'Division by zero' });
      result = a / b;
      break;
    default:
      return res.status(400).json({ error: `Unknown operation: ${operation}` });
  }

  res.json({ result, expression: `${a} ${operation} ${b}` });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`calc-api running on port ${PORT}`));
