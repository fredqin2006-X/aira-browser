import { AppRuntimeContext } from '../../app/runtime/AppRuntimeContext';

/**
 * Resolves an app string resource into a localized plain string.
 *
 * Prefer `$r('app.string.*')` and a `ResourceStr` receiving type whenever the
 * consumer can render a Resource directly. This helper only exists for sinks
 * that cannot carry a ResourceStr: persisted values, generated HTML documents,
 * accessibility text, and the plain-string ports of browser chrome that have
 * not migrated to ResourceStr yet.
 *
 * Positional placeholders in the resource value use the `%1$s` / `%2$d` form,
 * matching `$r('app.string.name', ...)`. A plain string is returned unchanged.
 */
export function hasAppResourceText(value: ResourceStr): boolean {
  return typeof value !== 'string' || value.length > 0;
}

/** True when value is the same app string resource, ignoring format arguments. */
export function isAppString(value: ResourceStr, resource: Resource): boolean {
  if (typeof value === 'string') {
    return false;
  }
  return value.id === resource.id;
}

export function resolveAppResourceText(value: ResourceStr, ...args: (string | number)[]): string {
  if (typeof value === 'string') {
    return value;
  }
  const formatArguments = args.length > 0 ? args : resourceFormatArguments(value);
  try {
    const context = AppRuntimeContext.hasUIAbilityContext()
      ? AppRuntimeContext.getUIAbilityContext()
      : AppRuntimeContext.getApplicationContext();
    return context.resourceManager.getStringSync(value.id, ...formatArguments);
  } catch (_error) {
    return '';
  }
}

/**
 * A compiled `$r('app.string.name', ...)` carries its format values on
 * `Resource.params`. An entry-module build stores only the format values,
 * while HAR, HSP, and preview builds keep the resource name as the first
 * element. Drop that leading resource name when it is present so callers can
 * pass a formatted resource straight through without repeating the arguments.
 */
function resourceFormatArguments(value: Resource): (string | number)[] {
  const values: (string | number)[] = [];
  const raw: (string | number)[] | undefined = value.params as (string | number)[] | undefined;
  if (raw === undefined || raw.length === 0) {
    return values;
  }
  for (let index = 0; index < raw.length; index++) {
    const item: string | number = raw[index];
    if (typeof item === 'string' || typeof item === 'number') {
      values.push(item);
    }
  }
  const first: string | number | undefined = values.length > 0 ? values[0] : undefined;
  if (typeof first === 'string' && RESOURCE_NAME_PATTERN.test(first)) {
    return values.slice(1);
  }
  return values;
}

const RESOURCE_NAME_PATTERN: RegExp =
  /^(?:app|sys|\[[^\]]+\])\.(?:boolean|color|float|intarray|integer|pattern|plural|strarray|string|media|rawfile|symbol)\.[A-Za-z_][A-Za-z0-9_]*$/;
