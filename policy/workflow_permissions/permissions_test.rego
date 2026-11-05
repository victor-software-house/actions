package workflow_permissions_test

import data.workflow_fixtures as f
import data.workflow_permissions
import rego.v1

denied(input_lines) := result if {
	result := workflow_permissions.deny_permissions with input as input_lines with data.conftest.file as f.file
}

test_valid_workflow_passes if count(denied(f.lines(f.workflow))) == 0

test_missing_permissions_fail if {
	denied(f.edited("permissions:\n  contents: read\n", "")) == {"top-level permissions must map each scope to one of: read, none"}
}

test_top_level_write_fails if {
	denied(f.edited("permissions:\n  contents: read", "permissions:\n  contents: write")) == {"top-level permission contents is write; grant it on the job that needs it"}
}

test_top_level_shorthand_fails if {
	denied(f.edited("permissions:\n  contents: read", "permissions: read-all")) == {"top-level permissions must map each scope to one of: read, none"}
}

test_job_shorthand_fails if {
	denied(f.edited("    permissions:\n      contents: write", "    permissions: write-all")) == {"job build must map each permission scope, not write-all"}
}
