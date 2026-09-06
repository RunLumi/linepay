(() => {
  try {
    const value = localStorage.getItem('linepaycheck-guide-appearance');
    if (value === 'light' || value === 'dark') document.documentElement.dataset.theme = value;
  } catch { /* Reading help must not depend on browser storage. */ }
})();
