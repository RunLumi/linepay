(() => {
  const choice = document.querySelector('#appearance');
  if (choice) {
    choice.closest('label').hidden = false;
    choice.value = document.documentElement.dataset.theme || 'auto';
    choice.addEventListener('change', () => {
      const value = choice.value;
      if (value === 'light' || value === 'dark') document.documentElement.dataset.theme = value;
      else delete document.documentElement.dataset.theme;
      try { localStorage.setItem('linepaycheck-guide-appearance', value); } catch { /* Optional preference only. */ }
    });
  }
  const navigation = document.querySelector('#guide-navigation');
  if (navigation) {
    const desktop = matchMedia('(min-width: 64rem)');
    navigation.open = desktop.matches;
    desktop.addEventListener('change', event => { navigation.open = event.matches; });
  }
})();
