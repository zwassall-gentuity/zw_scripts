function _get-refs {
    _enter "_get-refs $*"

    local -n _get_refs_result=$1
    local pattern=$2

    if [ -n "$_get_refs_result" ]; then
        :
    else
        _time _get_refs_result git for-each-ref --format='%(refname:short)' $pattern
    fi

    _return
}

function _get-remotes {
    _enter "_get-remotes $*"

    local -n _get_remotes_result=$1

    if [ -n "$_get_remotes_result" ]; then
        :
    else
        _time _get_remotes_result git remote
    fi

    _return
}


function _branch-match-refs {
    _enter "_branch-match-refs $*"

    local -n _bmr_refs=$1
    local -n _bmr_result=$2
    local query=$3
    local refsPattern=$4
    
    _bmr_result=

    local index=-1
    if [[ $query =~ (.*)\[(.*)\] ]]; then
        query=${BASH_REMATCH[1]}
        index=${BASH_REMATCH[2]}
    fi

    if ! [[ $index =~ [0-9]+ ]] || [ $index -ge 10 ]; then
        echo "Invalid index: $index" >&2
        (exit 1)

    elif [[ $query =~ (\^?)([^@^~]+)(.*) ]]; then
        local prefix=${BASH_REMATCH[1]}
        local pattern=${BASH_REMATCH[2]}
        local suffix=${BASH_REMATCH[3]}

        _bmr_result=$query

        if [ "$pattern" == HEAD ]; then
            _debug "Query is HEAD"

        elif [[ $pattern =~ ^[0-9A-Fa-f]{7,}$ ]]; then
            _debug "Query appears to be a commit hash"

        elif _get-refs _bmr_refs $refsPattern; then
            local matches=($(echo "$_bmr_refs" | grep -i -- "$pattern"))
            local count=${#matches[@]}

            if [ $count -eq 0 ]; then
                _debug "No matches"
                (exit 255)

            elif [ $index -lt 0 ] && [ $count -eq 1 ]; then
                _bmr_result=$prefix${matches[0]}$suffix
                _debug "Lone match: $_bmr_result"

            elif [ $index -ge 0 ] && [ $index -lt $count ]; then
                _bmr_result=$prefix${matches[index]}$suffix
                _debug "Indexed match: $_bmr_result"

            elif _element-in "$pattern" "${matches[@]}"; then
                _debug "Exact match: $_bmr_result"

            else
                echo "\"$pattern\" matched $count ref$([ $count -ne 1 ] && echo s) in $refsPattern:" >&2

                local i
                for i in "${!matches[@]}"; do
                    if [ $i -ge 10 ]; then
                        break
                    fi
                    echo " [$i] ${matches[i]}" >&2
                done

                echo "Refine your search or append an index selection." >&2
                echo >&2

                (exit $i)
            fi
        fi
    fi

    _return
}

function _branch-match-1 {
    _enter "_branch-match-1 $*"

    local -n _bm1_refsHeads=$1
    local -n _bm1_refsRemotes=$2
    local -n _bm1_result=$3
    local query=$4

    if [ -n "$query" ]; then
        _branch-match-refs _bm1_refsHeads _bm1_result "$query" refs/heads
        local ret=$?

        if [ $ret -ne 255 ]; then
            (exit $ret)
        elif _branch-match-refs _bm1_refsRemotes _bm1_result "$query" refs/remotes && $branchOnly && [[ $_bm1_result =~ [[:alnum:]]+/(.*) ]]; then
            _bm1_result=${BASH_REMATCH[1]}
        fi
    fi

    _return
}

function _branch-match {
    _enter "_branch-match $*"

    local -n _bm_refsHeads=$1
    local -n _bm_refsRemotes=$2
    local -n _bm_remotes=$3
    local -n _bm_result=$4
    local query=$5

    _bm_result="$query"

    if [[ $query == -* ]]; then
        :

    else
        local remoteMatches=()
        if [[ $query =~ ^[0-9A-Za-z_-]+$ ]] && _get-remotes _bm_remotes; then
            remoteMatches=($(echo "$_bm_remotes" | grep -Fx -- "$query"))
        fi

        if [ ${#remoteMatches[@]} -gt 0 ]; then
            :

        elif ! [[ $query =~ (.*)(:|\.\.\.?)(.*) ]]; then
            _branch-match-1 _bm_refsHeads _bm_refsRemotes _bm_result "$query"

        else
            local query1=${BASH_REMATCH[1]}
            local joiner=${BASH_REMATCH[2]}
            local query2=${BASH_REMATCH[3]}

            local result1
            _branch-match-1 _bm_refsHeads _bm_refsRemotes result1 "$query1"
            local ret1=$?

            local result2
            _branch-match-1 _bm_refsHeads _bm_refsRemotes result2 "$query2"
            local ret2=$?

            _bm_result=$result1$joiner$result2
            _max-ret $ret1 $ret2
        fi
    fi

    _debug "$query=$_bm_result"

    _return
}

function _branch-cmd {
    _enter "_branch-cmd $*"

    local -n _bc_refsHeads=$1
    shift
    local -n _bc_refsRemotes=$1
    shift
    local -n _bc_remotes=$1
    shift

    local cmd1="$1"
    shift

    local matchRetMax=128
    local cmd=("$cmd1")
    if [ $# -ge 1 ]; then
        if [ "$cmd1" = git ]; then
            cmd+=("$1")
            shift
        fi

        while [ $# -ge 1 ]; do
            if [ "$1" = -- ]; then
                cmd+=("$@")
                break
            fi

            local match
            _branch-match _bc_refsHeads _bc_refsRemotes _bc_remotes match "$1"
            local matchRet=$?

            if [ $matchRet -ne 0 ]; then
                cmd+=("$1")

            else
                cmd+=("$match")

                if [ "$match" = "$1" ]; then
                    matchRet=255
                fi
            fi

            _max-ret $matchRetMax $matchRet
            matchRetMax=$?

            shift
        done
    fi

    if [ $matchRetMax -eq 0 ] || [ $matchRetMax -ge 128 ]; then
        if [ $matchRetMax -eq 0 ]; then
            echo "$ ${cmd[*]}" >&2
        fi

        _enter "${cmd[*]}"
        "${cmd[@]}"
        _return
    fi

    _return
}

function branch-cmd {
    _indent=""
    local bc_remotes
    local bc_refsHeads
    local bc_refsRemotes
    branchOnly=true
    _branch-cmd bc_refsHeads bc_refsRemotes bc_remotes "$@"
}

function ref-cmd {
    _indent=""
    local rc_remotes
    local rc_refsHeads
    local rc_refsRemotes
    branchOnly=false
    _branch-cmd rc_remotes rc_refsHeads rc_refsRemotes "$@"
}


alias a=add
function add {
    git add "$@"
}
function annotate {
    git annotate "$@"
}
function apply {
    git apply "$@"
}
function blame {
    git blame "$@"
}
alias b=branch
function branch {
    ref-cmd git branch "$@"
}
alias p=cherry-pick
alias pick=cherry-pick
function cherry-pick {
    ref-cmd git cherry-pick "$@"
}
alias ch=checkout
function checkout {
    branch-cmd git checkout "$@"
}
alias c=commit
function commit {
    git commit "$@"
}
alias d=diff_
function diff_ {
    ref-cmd git diff "$@"
}
alias f=fetch
function fetch {
    ref-cmd git fetch "$@"
}
alias gm=get-merge
function get-merge {
    ref-cmd git get-merge "$@"
}
alias l=log
function log {
    ref-cmd git log "$@"
}
alias m=merge
function merge {
    ref-cmd git merge "$@"
}
alias mb=merge-base
function merge-base {
    local arg array=()
    for arg in "$@"; do
        array+=($(ref-grep $arg))
    done
    git merge-base "${array[@]}"
}
function oops {
    git oops "$@"
}
function pull {
    git pull "$@"
}
function push {
    git push "$@"
}
function rebase {
    ref-cmd git rebase "$@"
}
function reflog {
    ref-cmd git reflog "$@"
}
function remote {
    git remote "$@"
}
function reset {
    ref-cmd git reset "$@"
}
function revert {
    git revert "$@"
}
function rev-list {
    ref-cmd git rev-list "$@"
}
function rev-parse {
    ref-cmd git rev-parse "$@"
}
function show {
    ref-cmd git show "$@"
}
function stash {
    git stash "$@"
}
alias s=status
function status {
    git status "$@"
}
alias t=tag
function tag {
    git tag "$@"
}


alias oa=oldest-ancestor
function oldest-ancestor {
    diff --old-line-format='' --new-line-format='' <(rev-list --first-parent "$1") <(rev-list --first-parent "${2:-HEAD}") | head -1
}
alias bg=branch-grep
function branch-grep {
    branch-cmd echo "$@"
}
alias bl=branch-list
function branch-list {
    git for-each-ref --format='%(if)%(HEAD)%(then)*%(else)%(if)%(worktreepath)%(then)+%(else) %(end)%(end) %(color:magenta)%(align:15)%(committerdate:relative)%(end) %(color:yellow)%(objectname:short=7) (%(if)%(HEAD)%(then)%(color:green)%(else)%(if)%(worktreepath)%(then)%(color:cyan)%(else)%(color:brightblue)%(end)%(end)%(refname:short)%(color:yellow)) %(color:dim white)%(contents:subject)' --sort='committerdate' refs/heads
}
alias bn=branch-name
function branch-name {
    git branch --show-current
}
function conflicts {
    git diff --name-only --diff-filter=U --relative
}
alias dc=diff-chars
function diff-chars {
    ref-cmd git diff --word-diff-regex=. "$@"
}
alias dd=diff-diff
function diff-diff {
    a=a.txt
    b=b.txt
    mkdir -p diff-diff
    sed -e 's/^index .*/index */' -e 's/^@@[^@]*/@@ * /g' "$a" > "diff-diff/$a"
    sed -e 's/^index .*/index */' -e 's/^@@[^@]*/@@ * /g' "$b" > "diff-diff/$b"
    pushd diff-diff >/dev/null
    d=d.txt
    diff.exe --color=always -U 1000000000 "$a" "$b" | grep -P '^(\x1b| (diff|index|---|\+\+\+|@@) )' > "$d"
    less -R "$d"
    popd >/dev/null
    rm -rf diff-diff
}
alias dw=diff-words
function diff-words {
    ref-cmd git diff --color-words='\w+|\\.|[^[:space:]]' "$@"
}
alias gf=gentuity-fetch
function gentuity-fetch {
    git fetch --all -fPpt && git fetch origin -u master:master release/v25.5:release/v25.5 spryte:spryte
}
alias lf=lfs-fix
function lfs-fix {
    git rm .gitattributes
    git reset --hard
}
alias lf2=lfs-fix-2
function lfs-fix-2 {
    git lfs uninstall
    git rm --cached -r .
    git reset --hard
    git rm .gitattributes
    git reset .
    git checkout .
    git lfs install
    git lfs pull
}
alias mdr=merge-dry-run
function merge-dry-run {
    b1=$(ref-grep $1)
    b2=$(ref-grep $2)
    git merge-tree $(git merge-base $b1 $b2) $b1 $b2 | less
}
alias mdrc=merge-dry-run-conflicts
function merge-dry-run-conflicts {
    merge-dry-run "$@" | sed -n '/+<<<<<<< .our/,/+>>>>>>> .their/p;/^changed in both/{p;n;N;N;s/^/#/mg;p}'
}
alias pfwl=push-force-with-lease
function push-force-with-lease {
    git push --force-with-lease "$@"
}
alias rg=ref-grep
function ref-grep {
    ref-cmd echo "$@"
}
alias rr=repo-root
function repo-root {
    git rev-parse --show-toplevel
}
function short {
    ref-cmd git rev-parse --short $([ -n "$*" ] && echo "$@" || echo "HEAD")
}
alias sp=swap-parents
function swap-parents {
    git replace -g HEAD HEAD^2 HEAD^1
    git commit --amend
    git replace -d HEAD@{1}
}
alias srd=show-remerge-diff
function show-remerge-diff {
    ref-cmd git show --remerge-diff "$@"
}
alias vco=validate-codeowners
function validate-codeowners {
    REPOSITORY_PATH=. GITHUB_ACCESS_TOKEN=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 EXPERIMENTAL_CHECKS=avoid-shadowing OWNER_CHECKER_REPOSITORY=globusmedical/INR_DEV OWNER_CHECKER_ALLOW_UNOWNED_PATTERNS=false NOT_OWNED_CHECKER_SKIP_PATTERNS=* codeowners-validator.exe
}
