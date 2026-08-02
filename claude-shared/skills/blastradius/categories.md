# Blast-radius categories

One section per category. Run the searches with the identifiers collected in
step 1 substituted for the `<...>` placeholders. Commands are generic: adapt
the file globs to the repo's languages.

## 1. Callers and reverse dependencies

Every site that constructs, calls, overrides, or imports a symbol whose
signature, arity, or type moved.

```
git grep -n '<symbol>'
git grep -n 'extends <type>\|new <type>\|<type>('
```

## 2. Configs and defaults

Config keys, environment variables, feature flags, and default values that the
change reads, renames, or re-defaults. Includes deploy manifests and charts.

```
git grep -n '<config key>' -- '*.yaml' '*.yml' '*.conf' '*.toml' '*.env*'
git grep -rn '<env var>' -- '*.tf' 'deploy/' 'charts/'
```

## 3. Metrics, dashboards, alerts

Anything keyed on a metric name, tag key, or tag value the change touches:
dashboard panels, monitor queries, SLO definitions, recording rules.

```
grep -rn '<metric name>' --include='*.tf' --include='*.json' --include='*.yaml'
gh search code '<metric name>' --owner <org>
```

Dashboards and monitors often live outside the service repo. If no in-repo hit,
that is a speculative row pointing at the infra repo, not a clear category.

## 4. Logs and log-derived widgets

Log message text, structured log field names, and the saved searches, facets,
parsers, and log-based metrics built on them. Renaming a log field silently
empties a widget.

```
git grep -n '<log field>\|<log message fragment>'
grep -rn '<log field>' --include='*.tf' --include='*.json'
```

## 5. Wire and storage format compatibility

Serialized shapes crossing a version boundary: API request and response
fields, event payloads, enum values, DB columns, cache keys, golden or
snapshot fixtures. Ask whether old readers can read new writes and the
reverse.

```
git grep -n '<field name>' -- '*.proto' '*.avsc' '*.json' '*.sql' '*.graphql'
git grep -rln '<field name>' -- '**/testdata/' '**/fixtures/' '**/snapshots/'
```

## 6. Docs and runbooks

READMEs, guides, API docs, architecture docs, changelogs, and runbooks that
name the changed symbol, config, metric, or behavior. Compile-gated doc
snippets count as callers too.

```
git grep -n '<identifier>' -- '*.md' '*.rst' '*.adoc' 'docs/'
```

## 7. Downstream consumers (other repos and services)

Repos that depend on the published artifact, call the API, or read the emitted
events. Check the version pin as well as the usage: a consumer pinned to an
old version moves only when the pin moves.

```
gh search code '<artifact name>' --owner <org>
git grep -rn '<artifact coordinate>\|<version pin>' -- '*.json' '*.toml' '*.sbt' '*.mill' '*.gradle'
```

## 8. Operational expectations

What a human has to do differently: deploy ordering between coupled services,
migration or backfill steps, oncall runbook changes, dashboards to rebaseline
after a metric's meaning shifts, alert thresholds tuned to the old numbers.

```
git grep -n '<service name>' -- '.github/workflows/' 'ci/' 'Makefile'
git grep -n 'runbook\|oncall\|rollback' -- 'docs/' '*.md'
```
