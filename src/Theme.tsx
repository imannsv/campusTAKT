import {
  createContext,
  useContext,
  useEffect,
  useState,
  ReactNode,
} from "react";
import { Monitor, Moon, Sun } from "lucide-react";

export type ThemePreference = "light" | "dark" | "system";
const storageKey = "campuszeit-theme";
const options = [
  { value: "light", label: "Hell", icon: Sun },
  { value: "dark", label: "Dunkel", icon: Moon },
  { value: "system", label: "System", icon: Monitor },
] as const;
const valid = (value: string | null): ThemePreference =>
  value === "light" || value === "dark" ? value : "system";

function readPreference(): ThemePreference {
  try {
    return valid(localStorage.getItem(storageKey));
  } catch {
    return "system";
  }
}

function applyTheme(preference: ThemePreference) {
  const dark =
    preference === "dark" ||
    (preference === "system" &&
      matchMedia("(prefers-color-scheme: dark)").matches);
  document.documentElement.dataset.theme = dark ? "dark" : "light";
  document.documentElement.style.colorScheme = dark ? "dark" : "light";
  document
    .querySelector('meta[name="theme-color"]')
    ?.setAttribute("content", dark ? "#121a24" : "#214b76");
}

const ThemeContext = createContext<{
  preference: ThemePreference;
  choose: (preference: ThemePreference) => void;
} | null>(null);

export function ThemeProvider({ children }: { children: ReactNode }) {
  const [preference, setPreference] = useState(readPreference);
  useEffect(() => {
    applyTheme(preference);
    const media = matchMedia("(prefers-color-scheme: dark)");
    const update = () => applyTheme(preference);
    media.addEventListener("change", update);
    return () => media.removeEventListener("change", update);
  }, [preference]);
  useEffect(() => {
    const update = (event: StorageEvent) => {
      if (event.key === storageKey || event.key === null)
        setPreference(readPreference());
    };
    window.addEventListener("storage", update);
    return () => window.removeEventListener("storage", update);
  }, []);
  function choose(value: ThemePreference) {
    applyTheme(value);
    setPreference(value);
    try {
      localStorage.setItem(storageKey, value);
    } catch {
      // The selected appearance still works for this tab without storage.
    }
  }
  return (
    <ThemeContext.Provider value={{ preference, choose }}>
      {children}
    </ThemeContext.Provider>
  );
}

export function ThemePicker() {
  const theme = useContext(ThemeContext)!;
  const Icon = options.find(
    (option) => option.value === theme.preference,
  )!.icon;
  return (
    <label className="theme-picker" title="Darstellung wählen">
      <Icon size={18} aria-hidden="true" />
      <select
        aria-label="Darstellung"
        value={theme.preference}
        onChange={(event) => theme.choose(valid(event.target.value))}
      >
        {options.map((option) => (
          <option key={option.value} value={option.value}>
            {option.label}
          </option>
        ))}
      </select>
    </label>
  );
}

export function ThemeSettings() {
  const theme = useContext(ThemeContext)!;
  return (
    <section
      className="settings-panel theme-settings"
      aria-labelledby="theme-heading"
    >
      <h2 id="theme-heading">Darstellung</h2>
      <p>
        Wähle das Erscheinungsbild auf diesem Gerät. „System“ folgt der
        Einstellung deines Betriebssystems.
      </p>
      <div
        className="theme-options"
        role="group"
        aria-label="Darstellung wählen"
      >
        {options.map(({ value, label, icon: Icon }) => (
          <button
            key={value}
            type="button"
            aria-pressed={theme.preference === value}
            onClick={() => theme.choose(value)}
          >
            <Icon size={20} aria-hidden="true" />
            {label}
          </button>
        ))}
      </div>
      <small>
        Die Auswahl wird sofort übernommen und auf diesem Gerät gespeichert.
      </small>
    </section>
  );
}
