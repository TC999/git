# Create a commit or tag and set the variable with the object ID.
test_commit_setvar () {
	amend=
	append=
	notick=
	signoff=
	indir=
	merge=
	tag=
	var=

	while test $# != 0
	do
		case "$1" in
		--merge)
			merge=t
			;;
		--tag)
			tag=t
			;;
		--amend)
			amend="--amend"
			;;
		--append)
			append=t
			;;
		--notick)
			notick=t
			;;
		--signoff)
			signoff="$1"
			;;
		-C)
			shift
			indir="$1"
			;;
		-*)
			echo >&2 "error: unknown option $1"
			return 1
			;;
		*)
			break
			;;
		esac
		shift
	done
	if test $# -lt 2
	then
		echo >&2 "error: test_commit_setvar must have at least 2 arguments"
		return 1
	fi
	var=$1
	shift
	indir=${indir:+"$indir"/}
	if test -z "$notick"
	then
		test_tick
	fi &&
	if test -n "$merge"
	then
		git ${indir:+ -C "$indir"} merge --no-edit --no-ff \
			${2:+-m "$2"} "$1" &&
		oid=$(git ${indir:+ -C "$indir"} rev-parse HEAD)
	elif test -n "$tag"
	then
		git ${indir:+ -C "$indir"} tag -m "$1" "$1" "${2:-HEAD}" &&
		oid=$(git ${indir:+ -C "$indir"} rev-parse "$1")
	else
		file=${2:-"$1.t"} &&
		if test -n "$append"
		then
			echo "${3-$1}" >>"$indir$file"
		else
			echo "${3-$1}" >"$indir$file"
		fi &&
		git ${indir:+ -C "$indir"} add "$file" &&
		git ${indir:+ -C "$indir"} commit $amend $signoff -m "$1" &&
		oid=$(git ${indir:+ -C "$indir"} rev-parse HEAD)
	fi &&
	eval $var=$oid
}

get_abbrev_oid () {
	oid=$1 &&
	suffix=${oid#???????} &&
	oid=${oid%$suffix} &&
	if test -n "$oid"
	then
		echo "$oid"
	else
		echo "undefined-oid"
	fi
}

# Format the output of git-push, git-show-ref and other commands to make a
# user-friendly and stable text.  We can easily prepare the expect text
# without having to worry about future changes of the commit ID and spaces
# of the output.  Single quotes are replaced with double quotes, because
# it is boring to prepare unquoted single quotes in expect text.  We also
# remove some locale error messages, which break test if we turn on
# `GIT_TEST_GETTEXT_POISON=true` in order to test unintentional translations
# on plumbing commands.
make_user_friendly_and_stable_output () {
	_x40="$_x35$_x05"

	sed \
		-e "s/$(get_abbrev_oid $A)[0-9a-f]*/<COMMIT-A>/g" \
		-e "s/$(get_abbrev_oid $B)[0-9a-f]*/<COMMIT-B>/g" \
		-e "s/$(get_abbrev_oid $C)[0-9a-f]*/<COMMIT-C>/g" \
		-e "s/$(get_abbrev_oid $D)[0-9a-f]*/<COMMIT-D>/g" \
		-e "s/$(get_abbrev_oid $E)[0-9a-f]*/<COMMIT-E>/g" \
		-e "s/$(get_abbrev_oid $F)[0-9a-f]*/<COMMIT-F>/g" \
		-e "s/$(get_abbrev_oid $G)[0-9a-f]*/<COMMIT-G>/g" \
		-e "s/$(get_abbrev_oid $H)[0-9a-f]*/<COMMIT-H>/g" \
		-e "s/$(get_abbrev_oid $I)[0-9a-f]*/<COMMIT-I>/g" \
		-e "s/$(get_abbrev_oid $J)[0-9a-f]*/<COMMIT-J>/g" \
		-e "s/$(get_abbrev_oid $K)[0-9a-f]*/<COMMIT-K>/g" \
		-e "s/$(get_abbrev_oid $TAG1)[0-9a-f]*/<TAG-1>/g" \
		-e "s/$(get_abbrev_oid $TAG2)[0-9a-f]*/<TAG-2>/g" \
		-e "s/$(get_abbrev_oid $TAG3)[0-9a-f]*/<TAG-3>/g" \
		-e "s/$(get_abbrev_oid $TAG4)[0-9a-f]*/<TAG-4>/g" \
		-e "s/  *\$//" \
		-e "s/   */ /g" \
		-e "s/'/\"/g" \
		-e "s/	/    /g" \
		-e "s/$_x40[0-9a-f]*/<OID>/g" \
		-e "s/^index $_x05[0-9a-f]*\.\.$_x05[0-9a-f]*/index <OID1>..<OID2>/" \
		-e "s/$ZERO_OID/<ZERO-OID>/g"
}
