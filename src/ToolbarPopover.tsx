import { ReactNode, useEffect, useId, useRef, useState } from "react";
import { ChevronDown } from "lucide-react";

/** Non-modal toolbar controls. Menus additionally support arrow-key navigation. */
export default function ToolbarPopover({
  label,
  count,
  menu = false,
  children,
}: {
  label: string;
  count?: number;
  menu?: boolean;
  children: (close: () => void) => ReactNode;
}) {
  const [open, setOpen] = useState(false);
  const id = useId();
  const root = useRef<HTMLDivElement>(null);
  const trigger = useRef<HTMLButtonElement>(null);
  const panel = useRef<HTMLDivElement>(null);
  useEffect(() => {
    if (!open) return;
    panel.current
      ?.querySelector<HTMLElement>("button:not(:disabled), select, input")
      ?.focus();
    const outside = (event: PointerEvent | FocusEvent) => {
      if (!root.current?.contains(event.target as Node)) setOpen(false);
    };
    document.addEventListener("pointerdown", outside);
    document.addEventListener("focusin", outside);
    return () => {
      document.removeEventListener("pointerdown", outside);
      document.removeEventListener("focusin", outside);
    };
  }, [open]);
  return (
    <div
      className="toolbar-popover"
      ref={root}
      onKeyDown={(event) => {
        if (event.key === "Escape" && open) {
          event.preventDefault();
          event.stopPropagation();
          setOpen(false);
          trigger.current?.focus();
        } else if (menu && !open && event.key === "ArrowDown") {
          event.preventDefault();
          setOpen(true);
        } else if (
          menu &&
          open &&
          ["ArrowDown", "ArrowUp", "Home", "End"].includes(event.key)
        ) {
          event.preventDefault();
          const items = [
            ...(panel.current?.querySelectorAll<HTMLButtonElement>(
              "button:not(:disabled)",
            ) || []),
          ];
          const index = items.indexOf(
            document.activeElement as HTMLButtonElement,
          );
          const next =
            event.key === "Home"
              ? 0
              : event.key === "End"
                ? items.length - 1
                : (index +
                    (event.key === "ArrowDown" ? 1 : -1) +
                    items.length) %
                  items.length;
          items[next]?.focus();
        }
      }}
    >
      <button
        className="button secondary"
        type="button"
        ref={trigger}
        aria-expanded={open}
        aria-controls={open ? id : undefined}
        aria-haspopup={menu ? "menu" : "dialog"}
        onClick={() => setOpen(!open)}
      >
        {label}
        {!!count && <span className="toolbar-filter-count">{count}</span>}
        <ChevronDown size={16} />
      </button>
      {open && (
        <div
          id={id}
          ref={panel}
          className={`toolbar-popover-panel ${menu ? "toolbar-menu" : ""}`}
          role={menu ? "menu" : "dialog"}
          aria-label={label}
        >
          {children(() => {
            setOpen(false);
            trigger.current?.focus();
          })}
        </div>
      )}
    </div>
  );
}
