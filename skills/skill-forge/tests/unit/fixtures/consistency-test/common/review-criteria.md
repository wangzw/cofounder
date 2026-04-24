# Review Criteria

## CR-X01

```yaml
- id: CR-X01
  name: "test-criterion-a"
  version: 1.0.0
  checker_type: script
  script_path: scripts/dummy.sh
  severity: error
  conflicts_with: [CR-X02]
  priority: 2
  incremental_skip: per_file
```

## CR-X02

```yaml
- id: CR-X02
  name: "test-criterion-b"
  version: 1.0.0
  checker_type: script
  script_path: scripts/dummy.sh
  severity: warning
  conflicts_with: [CR-X01]
  priority: 3
  incremental_skip: per_file
```
