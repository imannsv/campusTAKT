import {
  createContext,
  useContext,
  useEffect,
  useId,
  useRef,
  useState,
  ReactNode,
} from "react";
import { Check, Monitor, Moon, Sun } from "lucide-react";

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
  const [open, setOpen] = useState(false);
  const root = useRef<HTMLDivElement>(null);
  const trigger = useRef<HTMLButtonElement>(null);
  const menuId = useId();
  const current = options.find((option) => option.value === theme.preference)!;
  useEffect(() => {
    if (!open) return;
    root.current
      ?.querySelector<HTMLButtonElement>('[aria-checked="true"]')
      ?.focus();
    const close = (event: PointerEvent) => {
      if (!root.current?.contains(event.target as Node)) setOpen(false);
    };
    document.addEventListener("pointerdown", close);
    return () => document.removeEventListener("pointerdown", close);
  }, [open]);
  const Icon = current.icon;
  return (
    <div
      className="theme-picker"
      ref={root}
      onBlur={(event) => {
        if (!root.current?.contains(event.relatedTarget as Node))
          setOpen(false);
      }}
    >
      <button
        ref={trigger}
        type="button"
        className="theme-trigger"
        aria-label={`Darstellung: ${current.label}`}
        title={`Darstellung: ${current.label}`}
        aria-haspopup="menu"
        aria-expanded={open}
        aria-controls={open ? menuId : undefined}
        onClick={() => setOpen(!open)}
        onKeyDown={(event) => {
          if (event.key === "ArrowDown" || event.key === "ArrowUp") {
            event.preventDefault();
            setOpen(true);
          }
        }}
      >
        <Icon size={19} aria-hidden="true" />
      </button>
      {open && (
        <div
          id={menuId}
          role="menu"
          aria-label="Darstellung wählen"
          className="theme-menu"
          onKeyDown={(event) => {
            if (event.key === "Escape") {
              event.preventDefault();
              setOpen(false);
              trigger.current?.focus();
            }
            const items = Array.from(
              event.currentTarget.querySelectorAll<HTMLButtonElement>("button"),
            );
            const index = items.indexOf(
              document.activeElement as HTMLButtonElement,
            );
            const next =
              event.key === "ArrowDown"
                ? (index + 1) % items.length
                : event.key === "ArrowUp"
                  ? (index + items.length - 1) % items.length
                  : event.key === "Home"
                    ? 0
                    : event.key === "End"
                      ? items.length - 1
                      : -1;
            if (next >= 0) {
              event.preventDefault();
              items[next].focus();
            }
          }}
        >
          {options.map(({ value, label, icon: OptionIcon }) => (
            <button
              key={value}
              type="button"
              role="menuitemradio"
              aria-checked={theme.preference === value}
              tabIndex={-1}
              onClick={() => {
                theme.choose(value);
                setOpen(false);
                trigger.current?.focus();
              }}
            >
              <OptionIcon size={17} aria-hidden="true" />
              <span>{label}</span>
              {theme.preference === value && (
                <Check size={16} aria-hidden="true" />
              )}
            </button>
          ))}
        </div>
      )}
    </div>
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
