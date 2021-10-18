#!/usr/bin/env bash

# A hook to try and catch the most common of stuff-ups before you accidentally
# commit the egregious sins.
#
# Usage: symlink this file into ~/.git/hooks/pre-commit (that is, *without*
# the `.sh` extension this file has) and your commits should be pristine from
# then on.
#

set -euo pipefail

if [[ -n "${DEBUG_PRE_COMMIT_HOOK:-}" ]]; then
	set -x
fi

IFS="
"

failed="n"

for file in $(git diff --cached --name-only); do
	# Deleted files get listed above too, annoyingly
	if [ -e "$file" ]; then
		if [[ "$file" =~ \.sh$ ]]; then
			echo "==> shellcheck $file"
			shellcheck "$file" || failed="y"
		elif [[ "$file" =~ \.tf$ ]]; then
			echo "==> fmt $file..."
			terraform fmt -check "$file" || failed="y"
		fi
	fi
done

tfsec --exclude-downloaded-modules --concise-output "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" || failed="y"

if git rev-parse --verify HEAD >/dev/null 2>&1; then
	against="HEAD"
else
	# Initial commit: diff against an empty tree object
	against="$(git hash-object -t tree /dev/null)"
fi

git diff-index --check --cached "$against" -- || failed="y"

if [ "$failed" = "y" ]; then
	echo -e "\e[31;1mEGREGIOUS FORMATTING CRIMES DETECTED.\e[0m"
	echo -e "\e[31;1mYOUR COMMIT HAS NOT BEEN MADE.\e[0m"
	echo
	echo "Please examine the above failure reports and correct."
	echo
	exit 1
fi
