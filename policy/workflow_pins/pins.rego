# Every `uses:` pins a commit and names its release in a comment, so a moved
# tag or branch never changes what runs. YAML parsing drops comments, so this
# rule reads the lines as written.
package workflow_pins

import data.workflow_lib as lib
import rego.v1

# owner/repo[/path]@<commit SHA>, then a comment naming the release
# (# v1.2.3) or the branch and the day it was read (# main, 2026-11-02).
pinned := `^[A-Za-z0-9_.-]+/[A-Za-z0-9_./-]+@[0-9a-f]{40} # (v[0-9]+(\.[0-9]+)*|[A-Za-z0-9_./-]+, [0-9]{4}-[0-9]{2}-[0-9]{2})$`

deny_pins contains msg if {
	some line in lib.lines
	match := regex.find_all_string_submatch_n(`^\s*(?:-\s+)?uses:\s*(.+)$`, line.text, 1)
	count(match) == 1
	ref := trim_space(match[0][1])
	not startswith(ref, "./")
	not regex.match(pinned, ref)
	msg := sprintf("line %d: uses %s must pin a commit SHA and name its release in a comment, such as @<sha> # v1.2.3", [line.number, ref])
}

exception contains ["pins"] if lib.excepted("pins")
