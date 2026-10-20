import {
  createContext,
  useContext,
  useEffect,
  useRef,
  useState,
  type ReactNode,
} from "react";
import { Icon } from "./Icon";

type Theme = "light" | "dark";
const storageKey = "campuszeit-appearance";
type Appearance = { site: Theme; preview: Theme | null };
const ThemeContext = createContext<{
  site: Theme;
  preview: Theme;
  ready: boolean;
  toggle: (target: "site" | "preview") => void;
} | null>(null);

export function ThemeProvider({ children }: { children: ReactNode }) {
  const [appearance, setAppearance] = useState<Appearance>({
    site: "light",
    preview: null,
  });
  const [ready, setReady] = useState(false);
  const changed = useRef(false);
  useEffect(() => {
    try {
      const saved = JSON.parse(localStorage.getItem(storageKey) || "null");
      if (saved && (saved.site === "light" || saved.site === "dark")) {
        setAppearance({
          site: saved.site,
          preview:
            saved.preview === "light" || saved.preview === "dark"
              ? saved.preview
              : null,
        });
      }
    } catch {
      /* Appearance controls also work when storage is unavailable. */
    }
    setReady(true);
  }, []);
  useEffect(() => {
    if (!ready) return;
    document.documentElement.dataset.theme = appearance.site;
    if (!changed.current) return;
    try {
      localStorage.setItem(storageKey, JSON.stringify(appearance));
    } catch {
      /* Keep the choice in memory. */
    }
  }, [appearance, ready]);
  const preview = appearance.preview ?? appearance.site;
  const toggle = (target: "site" | "preview") => {
    changed.current = true;
    setAppearance((current) => {
      const active =
        target === "site" ? current.site : (current.preview ?? current.site);
      return { ...current, [target]: active === "dark" ? "light" : "dark" };
    });
  };
  return (
    <ThemeContext.Provider
      value={{ site: appearance.site, preview, ready, toggle }}
    >
      {children}
    </ThemeContext.Provider>
  );
}

export function useTheme() {
  const value = useContext(ThemeContext);
  if (!value) throw new Error("ThemeProvider is required");
  return value;
}

export function ThemeToggle({ target }: { target: "site" | "preview" }) {
  const theme = useTheme();
  const dark = theme[target] === "dark";
  const label = `Dunkler Modus für die ${target === "site" ? "Website" : "Produktvorschau"}`;
  return (
    <button
      type="button"
      className={`theme-toggle enhanced-only theme-toggle-${target}`}
      aria-label={label}
      aria-pressed={dark}
      title={`${target === "site" ? "Website" : "Produktvorschau"}: ${dark ? "hellen" : "dunklen"} Modus aktivieren`}
      disabled={!theme.ready}
      onClick={() => theme.toggle(target)}
    >
      <Icon name={dark ? "sun" : "moon"} />
      {target === "site" ? <span>{dark ? "Hell" : "Dunkel"}</span> : null}
    </button>
  );
}
