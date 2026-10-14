import { useLayoutEffect, useRef, useState } from "react";
import {
  ArrowRight,
  CalendarDays,
  ChevronDown,
  GraduationCap,
  Users,
} from "lucide-react";
import type { Row } from "./api";
import "./planning-selection.css";

export type PlanningScope = { cohort?: number; group?: number };

export function scopeGroups(data: Record<string, Row[]>, scope: PlanningScope) {
  return (data.groups || []).filter((group) =>
    scope.group
      ? group.id === scope.group
      : !scope.cohort || group.cohort === scope.cohort,
  );
}

export function scopePlans(data: Record<string, Row[]>, scope: PlanningScope) {
  if (!scope.cohort && !scope.group) return data.plans || [];
  const ids = new Set(scopeGroups(data, scope).map((group) => group.id));
  const cohort =
    scope.cohort ||
    data.groups?.find((group) => group.id === scope.group)?.cohort;
  const linked = new Set(
    (data.courses || [])
      .filter((course) => course.groups?.some((id: number) => ids.has(id)))
      .map((course) => course.plan),
  );
  return (data.plans || []).filter(
    (plan) => (cohort && plan.cohort === cohort) || linked.has(plan.id),
  );
}

export default function PlanningSelection({
  data,
  page,
  query,
  onSelect,
}: {
  data: Record<string, Row[]>;
  page: "schedule" | "exams";
  query: string;
  onSelect: (scope: PlanningScope) => void;
}) {
  const [collapsed, setCollapsed] = useState<Set<string>>(new Set());
  const title = page === "schedule" ? "Stundenplanung" : "Prüfungen";
  const Icon = page === "schedule" ? CalendarDays : GraduationCap;
  const search = query.trim().toLocaleLowerCase("de");
  const selectionRef = useRef<HTMLElement>(null);
  useLayoutEffect(() => {
    const root = selectionRef.current;
    if (!root) return;
    const pack = () => {
      for (const container of root.querySelectorAll<HTMLElement>(
        ".selection-programs",
      )) {
        if (!container.clientWidth) continue;
        const style = getComputedStyle(container);
        const count = Number(style.getPropertyValue("--selection-columns"));
        const gap = parseFloat(style.columnGap);
        const width = (container.clientWidth - (count - 1) * gap) / count;
        const bottoms = Array<number>(count).fill(0);
        for (const card of container.querySelectorAll<HTMLElement>(
          ".selection-program",
        )) {
          const column = bottoms.indexOf(Math.min(...bottoms));
          Object.assign(card.style, {
            position: "absolute",
            width: `${width}px`,
            left: `${column * (width + gap)}px`,
            top: `${bottoms[column]}px`,
          });
          bottoms[column] += card.offsetHeight + gap;
        }
        container.style.height = `${Math.max(0, ...bottoms) - gap}px`;
      }
    };
    const observer = new ResizeObserver(pack);
    observer.observe(root);
    root
      .querySelectorAll(".selection-program")
      .forEach((card) => observer.observe(card));
    pack();
    return () => observer.disconnect();
  }, [data, search, collapsed]);
  const cohorts = data.cohorts || [];
  const groups = data.groups || [];
  const entries = [
    ...cohorts.map((cohort) => ({
      cohort,
      groups: groups
        .filter((group) => group.cohort === cohort.id)
        .sort((a, b) => a.name.localeCompare(b.name, "de", { numeric: true })),
      program: data.programs?.find((program) => program.id === cohort.program),
    })),
    ...(groups.some(
      (group) => !cohorts.some((cohort) => cohort.id === group.cohort),
    )
      ? [
          {
            cohort: { id: 0, name: "Ohne Jahrgang", entry_year: null } as Row,
            groups: groups.filter(
              (group) => !cohorts.some((cohort) => cohort.id === group.cohort),
            ),
            program: undefined,
          },
        ]
      : []),
  ].filter(({ cohort, groups, program }) =>
    `${cohort.name} ${cohort.entry_year || ""} ${program?.name || ""} ${groups.map((group) => group.name).join(" ")}`
      .toLocaleLowerCase("de")
      .includes(search),
  );
  const years = [
    ...new Set(
      entries.map(({ cohort }) => String(cohort.entry_year || "other")),
    ),
  ].sort((a, b) =>
    a === "other" ? 1 : b === "other" ? -1 : Number(b) - Number(a),
  );

  return (
    <section
      ref={selectionRef}
      className="planning-selection"
      aria-label={`${title}: Gruppe auswählen`}
    >
      <header className="selection-heading">
        <div>
          <span className="selection-eyebrow">
            <Icon size={15} aria-hidden="true" /> Planung
          </span>
          <h1>{title}</h1>
          <p>Wähle deinen Jahrgang und deine Gruppe.</p>
        </div>
        <button className="button secondary" onClick={() => onSelect({})}>
          Gesamtübersicht öffnen <ArrowRight size={15} aria-hidden="true" />
        </button>
      </header>
      {years.length === 0 && (
        <div className="selection-empty" role="status">
          <Users size={28} aria-hidden="true" />
          <h2>
            {search
              ? "Keine passende Gruppe"
              : "Noch keine Jahrgänge vorhanden"}
          </h2>
          <p>
            {search
              ? "Versuche einen anderen Suchbegriff."
              : "Jahrgänge und Gruppen legst du unter Einrichtung & Studienstruktur an."}
          </p>
        </div>
      )}
      {years.map((year) => {
        const items = entries.filter(
          ({ cohort }) => String(cohort.entry_year || "other") === year,
        );
        const programs = [
          ...new Set(items.map(({ program }) => program?.id || 0)),
        ];
        const closed = !search && collapsed.has(year);
        return (
          <section className="selection-year" key={year}>
            <h2>
              <button
                aria-expanded={!closed}
                aria-controls={`selection-year-${year}`}
                onClick={() =>
                  setCollapsed((previous) => {
                    const next = new Set(previous);
                    if (next.has(year)) next.delete(year);
                    else next.add(year);
                    return next;
                  })
                }
              >
                <span>{year === "other" ? "Ohne Aufnahmejahr" : year}</span>
                <span className="selection-year-count">
                  {items.reduce((count, item) => count + item.groups.length, 0)}{" "}
                  Gruppen
                </span>
                <span className="selection-year-rule" />
                <ChevronDown size={19} aria-hidden="true" />
              </button>
            </h2>
            <div
              id={`selection-year-${year}`}
              className="selection-programs"
              hidden={closed}
            >
              {programs.map((programId) => {
                const programItems = items.filter(
                  ({ program }) => (program?.id || 0) === programId,
                );
                const program = programItems[0].program;
                return (
                  <article className="selection-program" key={programId}>
                    <div className="selection-program-title">
                      <span className="selection-program-icon">
                        <GraduationCap size={20} aria-hidden="true" />
                      </span>
                      <h3>{program?.name || "Weitere Gruppen"}</h3>
                    </div>
                    {programItems.map(({ cohort, groups }) => (
                      <div className="selection-cohort" key={cohort.id}>
                        <div className="selection-cohort-heading">
                          <span>{cohort.name}</span>
                          {cohort.id !== 0 && (
                            <button
                              aria-label={`Jahrgang ${cohort.name} öffnen`}
                              onClick={() => onSelect({ cohort: cohort.id })}
                            >
                              Ganzer Jahrgang{" "}
                              <ArrowRight size={13} aria-hidden="true" />
                            </button>
                          )}
                        </div>
                        <div className="selection-groups">
                          {groups
                            .filter(
                              (group) =>
                                !search ||
                                `${cohort.name} ${cohort.entry_year || ""} ${program?.name || ""} ${group.name}`
                                  .toLocaleLowerCase("de")
                                  .includes(search),
                            )
                            .map((group) => (
                              <button
                                key={group.id}
                                className="selection-group"
                                aria-label={`Gruppe ${group.name} öffnen`}
                                onClick={() =>
                                  onSelect({
                                    group: group.id,
                                    ...(cohort.id ? { cohort: cohort.id } : {}),
                                  })
                                }
                              >
                                <span className="selection-group-name">
                                  {group.name}
                                </span>
                                <span className="selection-group-meta">
                                  <Users size={13} aria-hidden="true" />{" "}
                                  <span
                                    title={
                                      group.size
                                        ? `${group.size} Personen`
                                        : undefined
                                    }
                                  >
                                    {group.size || "Gruppe"}
                                  </span>{" "}
                                  <ArrowRight size={15} aria-hidden="true" />
                                </span>
                              </button>
                            ))}
                          {groups.length === 0 && (
                            <p className="selection-no-groups">
                              Noch keine Gruppen angelegt.
                            </p>
                          )}
                        </div>
                      </div>
                    ))}
                  </article>
                );
              })}
            </div>
          </section>
        );
      })}
    </section>
  );
}
