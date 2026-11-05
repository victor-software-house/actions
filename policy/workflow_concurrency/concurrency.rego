# One run per pull request or branch: a new push cancels the run it replaces.
package workflow_concurrency

import data.workflow_lib as lib
import rego.v1

key := "github.event.pull_request.number || github.ref_name"

# A draft push and the ready_for_review event that follows are both
# pull_request events for the same number. Sharing a group, the draft run
# (which only skips) can start last and cancel the ready run, leaving the
# head with no completed CI. The suffix keeps draft runs in a group of their
# own; it is empty outside pull requests.
draft_suffix := "${{ github.event.pull_request.draft && '-draft' || '' }}"

endings := {sprintf("${{ %s }}", [key]), sprintf("${{ %s }}%s", [key, draft_suffix])}

group := trim_space(object.get(lib.workflow, ["concurrency", "group"], ""))

deny_concurrency contains msg if {
	lib.on_pull_request
	# object.get, because a missing key would leave the comparison undefined.
	# The key comes last, or just before the draft suffix: anything else after
	# it, such as the commit SHA, gives every push its own group, and no push
	# cancels the run it replaces.
	not ends_in_key
	msg := sprintf("concurrency.group must end in ${{ %s }}, optionally followed by %s", [key, draft_suffix])
}

ends_in_key if {
	some ending in endings
	endswith(group, ending)
}

deny_concurrency contains "concurrency must set cancel-in-progress: true" if {
	lib.on_pull_request
	object.get(lib.workflow, ["concurrency", "cancel-in-progress"], false) != true
}

exception contains ["concurrency"] if lib.excepted("concurrency")
