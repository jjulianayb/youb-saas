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
