# Builds the job matrix from owner/name lines: one entry per repository,
# with its name for the job title and a one-item JSON list for Renovate.
split("\n")
| map(select(length > 0) | {
    name: split("/")[1],
    repositories: ([.] | tojson)
  })
| {include: .}
