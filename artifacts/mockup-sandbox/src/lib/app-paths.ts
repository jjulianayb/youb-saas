export function getAppBasePath(): string {
  const base = ((import.meta as ImportMeta & { env?: { BASE_URL?: string } }).env?.BASE_URL ?? "/").replace(/\/$/, "");
  return base === "/" ? "" : base;
}

export function appPath(pathname: string, basePath = getAppBasePath()): string {
  const base = basePath.replace(/\/$/, "");
  const path = pathname.startsWith("/") ? pathname : `/${pathname}`;
  return `${base}${path}` || "/";
}

export function localAppPath(pathname: string, basePath = getAppBasePath()): string {
  const base = basePath.replace(/\/$/, "");
  if (!base || !pathname.startsWith(base)) return pathname || "/";
  return pathname.slice(base.length) || "/";
}

export type AppRoute =
  | { kind: "onboarding" }
  | { kind: "commercial" | "employee" | "executive" }
  | { kind: "preview"; componentPath: string };

/** Keeps demos out of the product entry while preserving internal component previews. */
export function resolveAppRoute(pathname: string, basePath = getAppBasePath()): AppRoute {
  const local = localAppPath(pathname, basePath);
  if (local.endsWith("/employee")) return { kind: "employee" };
  if (local.endsWith("/executive")) return { kind: "executive" };
  if (local.endsWith("/commercial")) return { kind: "commercial" };
  const preview = local.match(/^\/preview\/(.+)$/)?.[1];
  if (preview && preview !== "Onboarding" && preview !== "CommercialV1Demo") {
    return { kind: "preview", componentPath: preview };
  }
  return { kind: "onboarding" };
}
