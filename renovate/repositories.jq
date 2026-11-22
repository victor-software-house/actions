# Ranks the repositories on every page of repositories.graphql by their real
# commits, and prints the owner/name of each one Renovate should check.
#
# A real commit is not a merge, has a GitHub account as its author, is not
# from a bot, and is not automated work. A repository with more commits than
# the query returns gets an estimate: its commit count times the share of
# real commits among those returned.
#
# $min: the fewest real commits a repository needs.
# $limit: the most repositories to print, most active first; 0 prints all.
# $exclude: repositories to leave out, one name per line.

# Headlines of automated work: state mirrors, template updates, releases,
# organization-wide CI changes and dependency bumps.
def automated: [
  "^chore: sync .* state",
  "(update|take|move to|update to) (the )?template", "chore/templa",
  "^chore\\(release\\)", "version packages", "move (to )?verctl", "verctl/relea", "chore/verctl",
  "skip (ci on )?draft", "ci/skip-draf",
  "merge queue", "merge_group", "ci/merge-gro",
  "pin the rewritten actions",
  "remove CLAUDE\\.md", "chore/remove",
  "materialized repo",
  "\\bbump", "^build: take ", "^chore\\(deps\\)"
];

def real:
  (.parents.totalCount < 2)
  and (.author.user != null)
  and (.author.user.login | endswith("[bot]") | not)
  and (.messageHeadline as $h | any(automated[]; . as $re | $h | test($re; "i")) | not);

def score:
  .defaultBranchRef.target.history as $history
  | ($history.nodes | length) as $seen
  | ([$history.nodes[] | select(real)] | length) as $real
  | if $history.totalCount > $seen
    then ($history.totalCount * $real / $seen | round)
    else $real
    end;

($exclude | split("\n") | map(select(length > 0))) as $skip
| [ .[].data.organization.repositories.nodes[]
    | select(.isMirror | not)
    | select(.defaultBranchRef != null)
    # A forkctl downstream follows its upstream's dependencies.
    | select((.mise.text // "") | contains("FORKCTL_MANIFEST") | not)
    | select((.nameWithOwner | split("/")[1]) | IN($skip[]) | not)
    | {name: .nameWithOwner, score: score}
    | select(.score >= $min) ]
| sort_by(-.score, .name)
| if $limit > 0 then .[:$limit] else . end
| .[].name
