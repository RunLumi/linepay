// A failed dependency must not leave a permanent, misleading storage-loading screen.
try {
  await import("./app.mjs");
} catch {
  const status = document.querySelector("#status");
  status.textContent =
    "Part of the app code could not load. Reload to try again. Stored records were not reset or replaced.";
  status.setAttribute("role", "alert");
  status.className = "error";
  document.querySelectorAll("nav button").forEach((button) => {
    button.disabled = true;
  });
  const main = document.querySelector("main");
  main.innerHTML =
    '<h1>App code could not load</h1><p>Check your connection, then reload the app. Your local records stay separate from the app files.</p><button class="primary" id="reload-app">Reload app</button>';
  main
    .querySelector("button")
    .addEventListener("click", () => location.reload());
  main.focus();
}
