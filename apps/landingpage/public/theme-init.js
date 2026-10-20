// Apply the saved website preference before the first paint, including legal pages.
try {
  const appearance = JSON.parse(
    localStorage.getItem("campuszeit-appearance") || "null",
  );
  document.documentElement.dataset.theme =
    appearance?.site === "dark" ? "dark" : "light";
} catch {
  document.documentElement.dataset.theme = "light";
}
