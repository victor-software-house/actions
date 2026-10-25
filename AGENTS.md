# actions

`README.md` is the inventory: what each workflow and task catalog does, its
inputs, and how a repository calls it.

## Rules

1. **Build shared behaviour once.**
   Behaviour that two or more jobs, workflows or repositories need is written
   once, as a reusable workflow, a catalog task, or a job output, and every
   consumer reads that one place.
   A copy drifts: when the light-runner rule changed, each inline copy had to
   be found and changed by hand.
   In `rust-ci.yml` the `Runner` job computes every other job's runner, and the
   jobs read its outputs.
   A job that cannot wait for that job, such as `Changes` and `Runner` itself,
   or `Verify`'s fallback when `Runner` failed, repeats the rule inline with a
   comment that says why; `runs-on` reads no workflow-level `env`, so a
   reusable workflow without such a job keeps one inline copy per job.
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
