# actions

`README.md` indexes the pieces. Each piece's doc is beside it, or under
`docs/` for a reusable workflow: what it does, its inputs, and how a
repository calls it. A change to a piece updates its doc in the same change.

## Rules

1. **Build shared behaviour once.**
   Behaviour that two or more jobs, workflows or repositories need is written once.
   It is a reusable workflow, a catalog task, or a job output, and every consumer reads that one place.
   A copy drifts.
   - Infrastructure choices are computed once, in the template's shared render fragment.
     Workflows get only final labels and configuration.
   - Repository visibility, runner provider and machine sizes are resolved when the template is applied, never by a running job.
   - Public callers hold no private infrastructure alternatives or labels.
   - Shared workflows take concrete inputs, with no visibility detection or abstract runner modes.
     What depends on the event, and cache-write safety, stay decisions at run time.
   - A step that several jobs of one workflow run, such as the toolchain install, is a YAML anchor repeated by alias.
     GitHub Actions resolves anchors but not merge keys (`<<`), so an aliased step is identical everywhere.
     A job adjusts it only through the environment it sets.
2. **Callers pin by commit.**
   A repository references a workflow or catalog by commit SHA with a `# main, <date>` comment, never by branch.
   A change here reaches it only through a reviewed pin bump.
3. **This repository is public.**
   Keep local paths, machine names, private repository names and internal URLs
   out of every tracked file, commit message and pull request.
4. **CI verifies.**
   `mise run verify` runs every check CI runs; push the branch and read the
   result on the pull request.
