export type SiteConfig = {
  siteUrl: string;
  contactEmail: string;
  publicRelease: boolean;
  legalReady: boolean;
  demoUrl: string;
};
export type PageKind = "home" | "imprint" | "privacy" | "notfound";
export function pageForPath(path: string): PageKind {
  const normalized = path.replace(/\/+$/, "") || "/";
  if (normalized === "/") return "home";
  if (normalized === "/impressum") return "imprint";
  if (normalized === "/datenschutz") return "privacy";
  return "notfound";
}
export const pageTitles: Record<PageKind, string> = {
  home: "CampusTakt – Die Planungszentrale für Hochschulen",
  imprint: "Impressum – CampusTakt",
  privacy: "Datenschutz – CampusTakt",
  notfound: "Seite nicht gefunden – CampusTakt",
};
