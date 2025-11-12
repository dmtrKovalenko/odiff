#!/usr/bin/env bash

# builds the last 8 commits and compares the performance of odiff
# against the current git HEAD

function print_help() {
	echo "usage: ./bench.sh [-n <num>] [--unstaged] [--help]"
	echo ""
	echo "-c, --clean : cleans the build directory (default: false)"
	echo "-s, --skip-build : skips building a commit if it already exists (default: true)"
	echo "-f, --from <commit> : compares the changes from the given commit (default: HEAD)"
	echo "-n <num> : number of commits to compare (default: 8)"
	echo "-u, --unstaged : also builds and compares with unstaged changes (default: false)"
	echo "-r, --runs <num> : number of runs (default: 10)"
	echo "-h, --help : prints this help message"
}

# must be in sync with build.zig
exe_name="odiff"
function build_project() {
	local id="$1"
	echo "Building $id"
	zig build -Doptimize=ReleaseFast --prefix-exe-dir "bench/$id"
	if [[ $? -ne 0 ]]; then
		echo "Failed to build $id"
		return 1
	fi
	echo "Successfully built $id"
}

function checkout_and_build() {
	local commit_id="$1"
	local skip_if_exists="$2"
	if [[ $skip_if_exists == true ]]; then
		if [[ -d "zig-out/bench/$commit_id" ]]; then
			echo "Skipping build of $commit_id"
			return
		fi
	fi

	echo "Checking out $commit_id"
	if [[ $commit_id != "unstaged" ]]; then
		if [[ ! -d ".benchtree" ]]; then
			git worktree add ".benchtree" "$commit_id"
		fi
		pushd ".benchtree"
		git checkout "$commit_id"
		build_project "$commit_id"
		if [[ $? -ne 0 ]]; then
			popd
			return 1
		fi
		popd
		mkdir -p "zig-out/bench/$commit_id"
		mv ".benchtree/zig-out/bench/$commit_id/$exe_name" "zig-out/bench/$commit_id/$exe_name"
		echo "Successfully built zig-out/bench/$commit_id/$exe_name"
	else
		build_project "$commit_id"
	fi
}

function get_commit_ids() {
	local from="$1"
	local commit_ids=()

	if $unstaged && [[ -n $(git diff --name-only) ]]; then
		commit_ids+=("unstaged")
	fi

	commit_ids+=($(git rev-parse "$from"))
	if [[ $num_commits -gt 1 ]]; then
		for i in $(seq 1 $(($num_commits-1))); do
			commit_ids+=($(git rev-parse "$from"~"$i"))
		done
	fi
	echo "${commit_ids[@]}"
}

args=$(getopt -o "n:uh" --long "unstaged,help,runs,from" -n "bench.sh" -- "$@")

num_commits=8
unstaged=false
clean=false
skip_if_exists=true
runs=10
from="HEAD"
while true; do
	case "$1" in
		-n)
			num_commits="$2"
			shift 2
			;;
		-c | --clean)
			clean=true
			shift
			;;
		-s | --skip-build)
			skip_if_exists=true
			shift
			;;
		-u | --unstaged)
			unstaged=true
			shift
			;;
		-r | --runs)
			runs="$2"
			shift 2
			;;
		-f | --from)
			from="$2"
			shift 2
			;;
		-h | --help)
			print_help
			exit 0
			;;
		--)
			shift
			break
			;;
		"")
			break
			;;
		*)
			print_help
			exit 1
			;;
	esac
done

if $clean; then
	echo "Cleaning output directory"
	rm -rf "zig-out/bench"
fi

commit_ids=($(get_commit_ids "$from"))
runnable_commit_ids=()
echo "Building $num_commits commits"
for commit_id in "${commit_ids[@]}"; do
	checkout_and_build "$commit_id" "$skip_if_exists"
	if [[ $? -eq 0 ]]; then
		runnable_commit_ids+=("$commit_id")
	fi
done

# ensure that hyperfine is installed
if ! command -v hyperfine &> /dev/null; then
	echo "hyperfine is not installed."
	echo "Please install hyperfine using the following command:"
	echo "cargo install hyperfine"
	exit 1
fi

bench_cmd="hyperfine -i -N --warmup 1 --runs $runs "
options="./images/www.cypress.io.png ./images/www.cypress.io-1.png ./images/www.cypress-diff.png"
for commit_id in "${runnable_commit_ids[@]}"; do
	bench_cmd+="\"$PWD/zig-out/bench/$commit_id/$exe_name $options\" "
done
eval "$bench_cmd"
