# verify-jobs action

Passes or fails a reusable workflow's one required check from the results of the jobs behind it.
A ruleset requires that one check, so it reports on every pull request and merge queue run, whatever jobs the workflow adds later.

```yaml
verify:
  name: Verify
  needs: [static, build]
  if: ${{ always() && !github.event.pull_request.draft }}
  runs-on: ${{ inputs.light-runner }}
  timeout-minutes: 2
  permissions:
    actions: read
  steps:
    - uses: victor-software-house/actions/verify-jobs@<commit> # main, <date>
      with:
        results: ${{ needs.static.result }} ${{ needs.build.result }}
```

## Results

- A `failure` among the results fails the check.
- A `skipped` job counts as passing, such as the build of a documentation-only pull request.
- A `cancelled` job passes only when a newer run of the same workflow, for the same event, branch and head commit, was created no later than the moment the first cancelled job ended.
  That newer run cancelled this one through the caller's concurrency group, and it reports instead.
  Any other cancellation fails the check.

The job reads its run and the runs for the same commit, so it grants `actions: read`.
