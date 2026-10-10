// Apply the saved appearance before styles and React load, including in Wiki tabs.
(() => {
  let preference = "system";
  try {
    preference = localStorage.getItem("campuszeit-theme") || "system";
  } catch {}
  const dark =
    preference === "dark" ||
    (preference !== "light" &&
      preference !== "dark" &&
      window.matchMedia("(prefers-color-scheme: dark)").matches);
  document.documentElement.dataset.theme = dark ? "dark" : "light";
  document.documentElement.style.colorScheme = dark ? "dark" : "light";
  document
    .querySelector('meta[name="theme-color"]')
    ?.setAttribute("content", dark ? "#121a24" : "#214b76");
})();
