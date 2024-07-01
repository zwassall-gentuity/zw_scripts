#!/bin/bash

if [ $# -lt 2 ]; then
    echo "Lists commits not in a target branch, grouped by the most upstream base branch in the git flow that contains them."
    echo "Formatted as markdown for use in a pull request description."
    echo
    echo "Usage: \"$0\" <target> <base>..."
    echo
    echo "  <target>   The target branch."
    echo "  <base>...  The list of contributing base branches in reverse flow order (most upstream first)."
    echo "             If evaluating a PR, the PR base branch should be specified as the first base branch."
    echo
    echo "Example usages for git flow: main <- v5.0 <- v4.2 <- v4.1"
    echo
    echo "  1. v4.2 <- merge-v4.2-v4.1: \"$0\" origin/v4.2 origin/merge-v4.2-v4.1 origin/v4.1"
    echo "  2. v5.0 <- merge-v5.0-v4.2: \"$0\" origin/v5.0 origin/merge-v5.0-v4.2 origin/v4.2 origin/v4.1"
    echo "  3. main <- merge-main-v5.0: \"$0\" origin/main origin/merge-main-v5.0 origin/v5.0 origin/v4.2 origin/v4.1"
    exit 1
fi

target="$1"
base0="$2"
bases=("${@:2}")
indent="   "

echo "Changes not in \`$target\` @ $(git rev-parse --short $target):"

bases_exclude=
# Iterate over reversed base list in reverse order (i.e. forward flow order).
for ((i=${#bases[@]}-1; i>=0; i--)); do
    base=${bases[$i]}
    merge_base=$(git merge-base --octopus $base0 $base)
    echo -n "$indent""- \`$base\` @ $(git rev-parse --short $merge_base):"
    changes="$(git log --exit-code --first-parent --format="$indent  - [%ci] %h:"$'\n'"$indent    %s" --reverse $merge_base $bases_exclude ^$target)"
    if [ -z "$changes" ]; then
        echo " No changes"
    else
        echo
        echo "$changes"
    fi
    bases_exclude+=" ^$base"
done
