# Packfile test functions

init_git_crypto_settings () {
	indir=
	enable=1
	while test $# != 0
	do
		case "$1" in
		-C)
			indir="$2"
			shift
			;;
		-d | --disable)
			enable=0
			;;
		*)
			break
			;;
		esac
		shift
	done

	git ${indir:+ -C "$indir"} config agit.crypto.enabled $enable &&
	git ${indir:+ -C "$indir"} config agit.crypto.secret nekot-terces &&
	git ${indir:+ -C "$indir"} config agit.crypto.nonce random_nonce
}

init_git_storage_threshold () {
	indir=
	while test $# != 0
	do
		case "$1" in
		-C)
			indir="$2"
			shift
			;;
		*)
			break
			;;
		esac
		shift
	done

	git ${indir:+ -C "$indir"} config \
		agit.crypto.bigfilenoencryptthreshold 100k &&
	git ${indir:+ -C "$indir"} config \
		core.bigfilethreshold 200k
}

show_base_text_file () {
	cat <<-\EOF
	Dec Hex    Dec Hex    Dec Hex  Dec Hex  Dec Hex  Dec Hex   Dec Hex   Dec Hex
	  0 00 NUL  16 10 DLE  32 20    48 30 0  64 40 @  80 50 P   96 60 `  112 70 p
	  1 01 SOH  17 11 DC1  33 21 !  49 31 1  65 41 A  81 51 Q   97 61 a  113 71 q
	  2 02 STX  18 12 DC2  34 22 "  50 32 2  66 42 B  82 52 R   98 62 b  114 72 r
	  3 03 ETX  19 13 DC3  35 23 #  51 33 3  67 43 C  83 53 S   99 63 c  115 73 s
	  4 04 EOT  20 14 DC4  36 24 $  52 34 4  68 44 D  84 54 T  100 64 d  116 74 t
	  5 05 ENQ  21 15 NAK  37 25 %  53 35 5  69 45 E  85 55 U  101 65 e  117 75 u
	  6 06 ACK  22 16 SYN  38 26 &  54 36 6  70 46 F  86 56 V  102 66 f  118 76 v
	  7 07 BEL  23 17 ETB  39 27 '  55 37 7  71 47 G  87 57 W  103 67 g  119 77 w
	  8 08 BS   24 18 CAN  40 28 (  56 38 8  72 48 H  88 58 X  104 68 h  120 78 x
	  9 09 HT   25 19 EM   41 29 )  57 39 9  73 49 I  89 59 Y  105 69 i  121 79 y
	 10 0A LF   26 1A SUB  42 2A *  58 3A :  74 4A J  90 5A Z  106 6A j  122 7A z
	 11 0B VT   27 1B ESC  43 2B +  59 3B ;  75 4B K  91 5B [  107 6B k  123 7B {
	 12 0C FF   28 1C FS   44 2C ,  60 3C <  76 4C L  92 5C \  108 6C l  124 7C |
	 13 0D CR   29 1D GS   45 2D -  61 3D =  77 4D M  93 5D ]  109 6D m  125 7D }
	 14 0E SO   30 1E RS   46 2E .  62 3E >  78 4E N  94 5E ^  110 6E n  126 7E ~
	 15 0F SI   31 1F US   47 2F /  63 3F ?  79 4F O  95 5F _  111 6F o  127 7F DEL
	--
	EOF
}

create_commits_stage_1 () {
	indir=
	while test $# != 0
	do
		case "$1" in
		-C)
			indir="$2"
			shift
			;;
		*)
			break
			;;
		esac
		shift
	done

	show_base_text_file >stage-1.txt &&
	git ${indir:+ -C "$indir"} \
		add stage-1.txt &&
	test_tick &&
	git ${indir:+ -C "$indir"} \
		commit -m A &&

	printf "Edit B\n" >>stage-1.txt &&
	git ${indir:+ -C "$indir"} \
		add stage-1.txt &&
	test_tick &&
	git ${indir:+ -C "$indir"} \
		commit -m B &&
	git ${indir:+ -C "$indir"} \
		tag -m tag-1 tag-1 &&
	git ${indir:+ -C "$indir"} \
		update-ref refs/heads/stage-1 HEAD &&

	commit_stage1=$(git ${indir:+ -C "$indir"} rev-parse HEAD)
}

create_commits_stage_2 () {
	show_base_text_file >stage-2.txt &&
	printf "Edit C\n" >>stage-2.txt &&
	git ${indir:+ -C "$indir"} \
		add stage-2.txt &&
	test_tick &&
	git ${indir:+ -C "$indir"} \
		commit -m C &&

	printf "Edit D\n" >>stage-2.txt &&
	git ${indir:+ -C "$indir"} \
		add stage-2.txt &&
	test_tick &&
	git ${indir:+ -C "$indir"} \
		commit -m D &&

	cat >blob-small <<-\EOF &&
	blob-small , which is smaller than big-file-no-encrypt-threshold (100KB), will save to
	encrypted loose object.
	EOF
	if type openssl
	then
		openssl enc -aes-256-ctr \
			-pass pass:"$($DD if=/dev/urandom bs=128 count=1 2>/dev/null | base64)" \
			-nosalt < /dev/zero | $DD bs=1024 count=50 >>blob-small
	else
		$DD if=/dev/random bs=1024 count=50 >>blob-small
	fi

	git ${indir:+ -C "$indir"} \
		add blob-small &&
	test_tick &&
	git ${indir:+ -C "$indir"} \
		commit -m E &&

	printf "Edit F\n" >>blob-small &&
	git ${indir:+ -C "$indir"} \
		add blob-small &&
	test_tick &&
	git ${indir:+ -C "$indir"} \
		commit -m F &&

	cat >blob-medium <<-\EOF &&
	blob-medium , which size is between 100k to 200k (big-file-threshold), will save to
	normal loose object.
	EOF
	if type openssl
	then
		openssl enc -aes-256-ctr \
			-pass pass:"$($DD if=/dev/urandom bs=128 count=1 2>/dev/null | base64)" \
			-nosalt < /dev/zero | $DD bs=1024 count=150 >>blob-medium
	else
		$DD if=/dev/random bs=1024 count=150 >>blob-medium
	fi

	git ${indir:+ -C "$indir"} \
		add blob-medium &&
	test_tick &&
	git ${indir:+ -C "$indir"} \
		commit -m G &&

	printf "Edit H\n" >>blob-medium &&
	git ${indir:+ -C "$indir"} \
		add blob-medium &&
	test_tick &&
	git ${indir:+ -C "$indir"} \
		commit -m H &&

	cat >blob-large <<-\EOF &&
	blob-large, which size is larger than 200k (big-file-threshold), will save to
	one object packfile.
	EOF
	if type openssl
	then
		openssl enc -aes-256-ctr \
			-pass pass:"$($DD if=/dev/urandom bs=128 count=1 2>/dev/null | base64)" \
			-nosalt < /dev/zero | $DD bs=1024 count=250 >>blob-large
	else
		$DD if=/dev/random bs=1024 count=250 >>blob-large
	fi

	git ${indir:+ -C "$indir"} \
		add blob-large &&
	test_tick &&
	git ${indir:+ -C "$indir"} \
		commit -m I &&

	printf "Edit J\n" >>blob-large &&
	git ${indir:+ -C "$indir"} \
		add blob-large &&
	test_tick &&
	git ${indir:+ -C "$indir"} \
		commit -m J &&

	git ${indir:+ -C "$indir"} \
		tag -m tag-2 tag-2 &&
	git ${indir:+ -C "$indir"} \
		update-ref refs/heads/stage-2 HEAD &&

	commit_stage2=$(git ${indir:+ -C "$indir"} rev-parse HEAD)
}

create_commits_stage_3 () {
	show_base_text_file >stage-3.txt &&
	printf "Edit K\n" >>stage-3.txt &&
	git ${indir:+ -C "$indir"} \
		add stage-3.txt &&
	test_tick &&
	git ${indir:+ -C "$indir"} \
		commit -m K &&

	printf "Edit L\n" >>stage-3.txt &&
	git ${indir:+ -C "$indir"} \
		add stage-3.txt &&
	test_tick &&
	git ${indir:+ -C "$indir"} \
		commit -m L &&

	printf "Edit M\n" >>blob-small &&
	git ${indir:+ -C "$indir"} \
		add blob-small &&
	test_tick &&
	git ${indir:+ -C "$indir"} \
		commit -m M &&

	printf "Edit N\n" >>blob-medium &&
	git ${indir:+ -C "$indir"} \
		add blob-medium &&
	test_tick &&
	git ${indir:+ -C "$indir"} \
		commit -m N &&

	printf "Edit O\n" >>blob-large &&
	git ${indir:+ -C "$indir"} \
		add blob-large &&
	test_tick &&
	git ${indir:+ -C "$indir"} \
		commit -m O &&

	git ${indir:+ -C "$indir"} \
		tag -m tag-3 tag-3 &&
	git ${indir:+ -C "$indir"} \
		update-ref refs/heads/stage-3 HEAD &&
	commit_stage3=$(git ${indir:+ -C "$indir"} rev-parse HEAD)
}

test_on_create_packs () {
	indir=
	options=
	while test $# != 0
	do
		case "$1" in
		-C)
			indir="$2"
			shift
			;;
		*)
			options="$options $1"
			;;
		esac
		shift
	done

	test_expect_success "create pack1" '
		git ${indir:+ -C "$indir"} pack-objects \
			--revs \
			--stdout \
			$options \
		>1.pack <<-\EOF &&
		stage-1
		EOF
		test -f 1.pack
	'

	test_expect_success "create pack2" '
		git ${indir:+ -C "$indir"} pack-objects \
			--revs \
			--stdout \
			$options \
		>2.pack <<-\EOF &&
		^stage-1
		stage-2
		EOF
		test -f 2.pack
	'

	test_expect_success "create pack3" '
		git ${indir:+ -C "$indir"} pack-objects \
			--revs \
			--stdout \
			$options \
		>3.pack <<-\EOF &&
		^stage-1
		^stage-2
		stage-3
		EOF
		test -f 3.pack
	'
}

test_on_restore_repo_from_packs () {
	indir=
	options=
	while test $# != 0
	do
		case "$1" in
		-C)
			indir="$2"
			shift
			;;
		*)
			options="$options $1"
			;;
		esac
		shift
	done

	test_expect_success "index-pack --stdin from pack1 ${indir:+in $indir}" '
		git ${indir:+ -C "$indir"} index-pack \
			$options \
			--stdin <1.pack
	'

	test_expect_success "index-pack --stdin from pack2 ${indir:+in $indir}" '
		git ${indir:+ -C "$indir"} index-pack \
			$options \
			--stdin <2.pack
	'

	test_expect_success "index-pack --stdin from pack3 ${indir:+in $indir}" '
		git ${indir:+ -C "$indir"} index-pack \
			$options \
			--stdin <3.pack
	'

	test_expect_success "update main branch ${indir:+in $indir}" '
		git ${indir:+ -C "$indir"} update-ref refs/heads/main "$commit_stage3"
	'

	test_expect_success "git fsck ${indir:+in $indir}" '
		git ${indir:+ -C "$indir"} fsck
	'
}
