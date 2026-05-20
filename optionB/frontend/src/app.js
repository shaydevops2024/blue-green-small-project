let firstOperand = '';
let secondOperand = '';
let currentOperation = null;
let justCalculated = false;

const display = document.getElementById('display');
const historyList = document.getElementById('history-list');

function updateDisplay(val) {
  display.textContent = val;
}

function pressDigit(d) {
  if (justCalculated) {
    firstOperand = '';
    secondOperand = '';
    currentOperation = null;
    justCalculated = false;
  }
  if (currentOperation === null) {
    if (d === '.' && firstOperand.includes('.')) return;
    firstOperand += d;
    updateDisplay(firstOperand);
  } else {
    if (d === '.' && secondOperand.includes('.')) return;
    secondOperand += d;
    updateDisplay(secondOperand);
  }
}

function pressOperation(op) {
  if (firstOperand === '') return;
  currentOperation = op;
  justCalculated = false;
}

async function calculate() {
  if (firstOperand === '' || secondOperand === '' || currentOperation === null) return;

  try {
    const res = await fetch('/api/calc/calculate', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        a: parseFloat(firstOperand),
        b: parseFloat(secondOperand),
        operation: currentOperation,
      }),
    });
    const data = await res.json();
    if (!res.ok) {
      updateDisplay(data.error || 'Error');
      return;
    }
    updateDisplay(data.result);
    await saveHistory(data.expression, data.result);
    firstOperand = String(data.result);
    secondOperand = '';
    currentOperation = null;
    justCalculated = true;
    loadHistory();
  } catch {
    updateDisplay('Error');
  }
}

async function saveHistory(expression, result) {
  try {
    await fetch('/api/history/history', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ expression, result }),
    });
  } catch {
    // non-fatal: history unavailable
  }
}

async function loadHistory() {
  try {
    const res = await fetch('/api/history/history');
    const data = await res.json();
    if (data.length === 0) {
      historyList.innerHTML = '<li class="empty">No history yet</li>';
      return;
    }
    historyList.innerHTML = data
      .map((h) => `<li>${h.expression} = <strong>${h.result}</strong></li>`)
      .join('');
  } catch {
    historyList.innerHTML = '<li class="empty">History unavailable</li>';
  }
}

function clearCalc() {
  firstOperand = '';
  secondOperand = '';
  currentOperation = null;
  justCalculated = false;
  updateDisplay('0');
}

loadHistory();
