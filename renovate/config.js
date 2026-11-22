// Global self-hosted configuration for the renovate workflow. Every
// repository in scope inherits it, and a repository may add its own Renovate
// file to override it.
//
// A public run's token reaches only the repository it updates, so lookups of
// private sources fail there. Copier templates are private, so a public run
// leaves them to each repository's daily Template check.
const publicRun = process.env.RENOVATE_VISIBILITY === 'public';

module.exports = {
  platform: 'github',
  username: 'vsh-renovate[bot]',
  gitAuthor: 'vsh-renovate[bot] <359714882+vsh-renovate[bot]@users.noreply.github.com>',
  onboarding: false,
  // Tools come from mise on the runner (mise.toml beside this file).
  binarySource: 'global',
  repositoryCache: 'enabled',
  requireConfig: 'optional',
  extends: [
    'config:recommended',
    ':timezone(America/Sao_Paulo)',
    'customManagers:githubActionsVersions',
  ],
  // New update branches open on Monday mornings. Existing branches are still
  // rebased on other days when they conflict with the base branch. A dry run
  // ignores the schedule, so it shows every update a scheduled run would make.
  schedule: process.env.RENOVATE_DRY_RUN ? [] : ['before 9am on monday'],
  rebaseWhen: 'conflicted',
  draftPR: true,
  automerge: false,
  platformAutomerge: false,
  dependencyDashboard: false,
  packageRules: [
    { matchManagers: ['github-actions'], groupName: 'GitHub Actions' },
    { matchManagers: ['mise'], groupName: 'mise tools' },
    { matchManagers: ['cargo'], groupName: 'Cargo dependencies' },
    { matchManagers: ['bun', 'npm'], groupName: 'npm dependencies' },
    // Refreshing flake.lock needs nix, which the ubuntu-slim runner lacks.
    // nix-config's own update policy covers its flake inputs.
    { matchManagers: ['nix'], enabled: false },
    ...(publicRun ? [{ matchManagers: ['copier'], enabled: false }] : []),
  ],
};
