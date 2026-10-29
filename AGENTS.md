# actions

`README.md` is the inventory: what each workflow and task catalog does, its
inputs, and how a repository calls it.

## Rules

1. **Build shared behaviour once.**
   Behaviour that two or more jobs, workflows or repositories need is written
   once, as a reusable workflow, a catalog task, or a job output, and every
   consumer reads that one place.
   A copy drifts: compute infrastructure choices once in the template's shared
   render fragment and pass only final labels and configuration to workflows.
   Repository visibility, runner provider and machine sizes are resolved when
   applying the template, never by an executing job.
   Public callers contain no private infrastructure alternatives or labels.
   Shared workflows consume concrete inputs without visibility detection or
   abstract runner-mode resolution. Event-dependent execution and cache-write
   safety remain runtime behavior.
   A step that several jobs of one workflow run, such as the toolchain
   install, is written once as a YAML anchor and repeated by alias.
   GitHub Actions resolves anchors but not merge keys (`<<`), so an aliased
   step is identical everywhere; a job adjusts it only through the
   environment it sets.
2. **Callers pin by commit.**
   A repository references a workflow or catalog by commit SHA with a
   `# main, <date>` comment, never by branch, so a change here reaches it only
   through a reviewed pin bump.
3. **This repository is public.**
   Keep local paths, machine names, private repository names and internal URLs
   out of every tracked file, commit message and pull request.
4. **CI verifies.**
   `mise run verify` runs every check CI runs; push the branch and read the
   result on the pull request.
