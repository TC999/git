#!/bin/sh

# Packfile misc test cases

test_expect_success 'change core.bigfilethreshold from 512MB (default) to 3MB' '
	git config core.bigfilethreshold 3000000
'

# Create base file, used as base for delta object.
cat >base.txt <<-\EOF
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
EOF

test_expect_success 'create commits' '
	git add base.txt &&
	test_tick &&
	git commit -m base &&
	cp base.txt A.txt &&
	echo A >>A.txt &&
	git add A.txt &&
	test_tick &&
	git commit -m A
'

test_expect_success 'create pack1' '
	git repack &&
	git prune --expire=now &&
	PK1=$(ls .git/objects/pack/*pack) &&
	PK1=${PK1#*pack-} &&
	PK1=${PK1%.pack}
'

test_expect_success 'verify pack1' '
	git verify-pack \
		".git/objects/pack/pack-${PK1}.pack"
'

test_expect_success 'inspect pack1' '
	test-tool agit-inspect \
		--no-show-size --no-show-crc --no-show-offset --show-version \
		pack ".git/objects/pack/pack-${PK1}.pack" >actual &&
	cat >expect <<-\EOF &&
	Header: plain, version: 00000002
	Number of objects: 6

	[obj 1] type: commit
	[obj 2] type: commit
	[obj 3] type: blob
	[obj 4] type: ofs-delta
	[obj 5] type: tree
	[obj 6] type: tree

	Checksum OK.
	EOF
	test_cmp expect actual
'

test_expect_success 'enable crypto settings' '
	git config agit.crypto.enabled 1 &&
	git config agit.crypto.secret c2VjcmV0LXRva2VuMTIzNA== &&
	git config agit.crypto.nonce random_nonce
'

test_expect_success 'create encrypted commits' '
	cp base.txt B.txt &&
	echo B >>B.txt &&
	git add B.txt &&
	test_tick &&
	git commit -m B &&
	cp B.txt C.txt &&
	echo C >>C.txt &&
	git add C.txt &&
	test_tick &&
	git commit -m C
'

test_expect_success 'create pack2, has objects reference to normal pack' '
	git repack &&
	git prune --expire=now &&
	PK2=$(ls .git/objects/pack/*pack | grep -v "$PK1") &&
	PK2=${PK2#*pack-} &&
	PK2=${PK2%.pack}
'

test_expect_success 'verify pack2' '
	git verify-pack \
		".git/objects/pack/pack-${PK2}.pack"
'

cat >expect-1 <<-\EOF
Header: encrypt (1), version: 81000002
Number of objects: 6

[obj 1] type: commit
[obj 2] type: commit
[obj 3] type: blob
[obj 4] type: ofs-delta
[obj 5] type: tree
[obj 6] type: ofs-delta

Checksum OK.
EOF

cat >expect-2 <<-\EOF
Header: encrypt (2), version: 82000002
Number of objects: 6

[obj 1] type: commit
[obj 2] type: commit
[obj 3] type: blob
[obj 4] type: ofs-delta
[obj 5] type: tree
[obj 6] type: ofs-delta

Checksum OK.
EOF

cat >expect-64 <<-\EOF
Header: encrypt (40), version: c0617202
Number of objects: 6

[obj 1] type: commit
[obj 2] type: commit
[obj 3] type: blob
[obj 4] type: ofs-delta
[obj 5] type: tree
[obj 6] type: ofs-delta

Checksum OK.
EOF

cat >expect-65 <<-\EOF
Header: encrypt (41), version: c1617202
Number of objects: 6

[obj 1] type: commit
[obj 2] type: commit
[obj 3] type: blob
[obj 4] type: ofs-delta
[obj 5] type: tree
[obj 6] type: ofs-delta

Checksum OK.
EOF

test_expect_success 'inspect pack2' '
	test-tool agit-inspect \
		--no-show-size --no-show-crc --no-show-offset --show-version \
		pack ".git/objects/pack/pack-${PK2}.pack" >actual &&
	test_cmp expect-${GIT_TEST_CRYPTO_ALGORITHM_TYPE} actual
'

test_expect_success 'create more encrypted commits' '
	cp C.txt D.txt &&
	echo D >>D.txt &&
	git add D.txt &&
	test_tick &&
	git commit -m D &&
	cp D.txt E.txt &&
	echo E >>E.txt &&
	git add E.txt &&
	test_tick &&
	git commit -m E &&
	cp E.txt F.txt &&
	echo F >>F.txt &&
	git add F.txt &&
	test_tick &&
	git commit -m F
'

test_expect_success 'create pack3, has objects reference to encrypt pack?' '
	git repack &&
	git prune --expire=now &&
	PK3=$(ls .git/objects/pack/*pack | grep -v "$PK1" | grep -v "$PK2") &&
	PK3=${PK3#*pack-} &&
	PK3=${PK3%.pack}
'

test_expect_success 'verify pack3' '
	git verify-pack \
		".git/objects/pack/pack-${PK3}.pack"
'

cat >expect-1 <<-\EOF
Header: encrypt (1), version: 81000002
Number of objects: 9

[obj 1] type: commit
[obj 2] type: commit
[obj 3] type: commit
[obj 4] type: blob
[obj 5] type: ofs-delta
[obj 6] type: ofs-delta
[obj 7] type: tree
[obj 8] type: ofs-delta
[obj 9] type: ofs-delta

Checksum OK.
EOF

cat >expect-2 <<-\EOF
Header: encrypt (2), version: 82000002
Number of objects: 9

[obj 1] type: commit
[obj 2] type: commit
[obj 3] type: commit
[obj 4] type: blob
[obj 5] type: ofs-delta
[obj 6] type: ofs-delta
[obj 7] type: tree
[obj 8] type: ofs-delta
[obj 9] type: ofs-delta

Checksum OK.
EOF

cat >expect-64 <<-\EOF
Header: encrypt (40), version: c0617202
Number of objects: 9

[obj 1] type: commit
[obj 2] type: commit
[obj 3] type: commit
[obj 4] type: blob
[obj 5] type: ofs-delta
[obj 6] type: ofs-delta
[obj 7] type: tree
[obj 8] type: ofs-delta
[obj 9] type: ofs-delta

Checksum OK.
EOF

cat >expect-65 <<-\EOF
Header: encrypt (41), version: c1617202
Number of objects: 9

[obj 1] type: commit
[obj 2] type: commit
[obj 3] type: commit
[obj 4] type: blob
[obj 5] type: ofs-delta
[obj 6] type: ofs-delta
[obj 7] type: tree
[obj 8] type: ofs-delta
[obj 9] type: ofs-delta

Checksum OK.
EOF

test_expect_success 'inspect pack3' '
	test-tool agit-inspect \
		--no-show-size --no-show-crc --no-show-offset --show-version \
		pack ".git/objects/pack/pack-${PK3}.pack" >actual &&
	test_cmp expect-${GIT_TEST_CRYPTO_ALGORITHM_TYPE} actual
'

test_expect_success 'git-fsck' '
	git fsck
'

test_expect_success 'create one packfile' '
	git repack -Ad &&
	git prune --expire=now &&
	PK4=$(ls .git/objects/pack/*pack) &&
	PK4=${PK4#*pack-} &&
	PK4=${PK4%.pack}
'

cat >expect-1 <<-\EOF
Header: encrypt (1), version: 81000002
Number of objects: 21

[obj 1] type: commit
[obj 2] type: commit
[obj 3] type: commit
[obj 4] type: commit
[obj 5] type: commit
[obj 6] type: commit
[obj 7] type: commit
[obj 8] type: blob
[obj 9] type: ofs-delta
[obj 10] type: ofs-delta
[obj 11] type: ofs-delta
[obj 12] type: ofs-delta
[obj 13] type: ofs-delta
[obj 14] type: ofs-delta
[obj 15] type: tree
[obj 16] type: ofs-delta
[obj 17] type: ofs-delta
[obj 18] type: ofs-delta
[obj 19] type: ofs-delta
[obj 20] type: tree
[obj 21] type: tree

Checksum OK.
EOF

cat >expect-2 <<-\EOF
Header: encrypt (2), version: 82000002
Number of objects: 21

[obj 1] type: commit
[obj 2] type: commit
[obj 3] type: commit
[obj 4] type: commit
[obj 5] type: commit
[obj 6] type: commit
[obj 7] type: commit
[obj 8] type: blob
[obj 9] type: ofs-delta
[obj 10] type: ofs-delta
[obj 11] type: ofs-delta
[obj 12] type: ofs-delta
[obj 13] type: ofs-delta
[obj 14] type: ofs-delta
[obj 15] type: tree
[obj 16] type: ofs-delta
[obj 17] type: ofs-delta
[obj 18] type: ofs-delta
[obj 19] type: ofs-delta
[obj 20] type: tree
[obj 21] type: tree

Checksum OK.
EOF

cat >expect-64 <<-\EOF
Header: encrypt (40), version: c0617202
Number of objects: 21

[obj 1] type: commit
[obj 2] type: commit
[obj 3] type: commit
[obj 4] type: commit
[obj 5] type: commit
[obj 6] type: commit
[obj 7] type: commit
[obj 8] type: blob
[obj 9] type: ofs-delta
[obj 10] type: ofs-delta
[obj 11] type: ofs-delta
[obj 12] type: ofs-delta
[obj 13] type: ofs-delta
[obj 14] type: ofs-delta
[obj 15] type: tree
[obj 16] type: ofs-delta
[obj 17] type: ofs-delta
[obj 18] type: ofs-delta
[obj 19] type: ofs-delta
[obj 20] type: tree
[obj 21] type: tree

Checksum OK.
EOF

cat >expect-65 <<-\EOF
Header: encrypt (41), version: c1617202
Number of objects: 21

[obj 1] type: commit
[obj 2] type: commit
[obj 3] type: commit
[obj 4] type: commit
[obj 5] type: commit
[obj 6] type: commit
[obj 7] type: commit
[obj 8] type: blob
[obj 9] type: ofs-delta
[obj 10] type: ofs-delta
[obj 11] type: ofs-delta
[obj 12] type: ofs-delta
[obj 13] type: ofs-delta
[obj 14] type: ofs-delta
[obj 15] type: tree
[obj 16] type: ofs-delta
[obj 17] type: ofs-delta
[obj 18] type: ofs-delta
[obj 19] type: ofs-delta
[obj 20] type: tree
[obj 21] type: tree

Checksum OK.
EOF

test_expect_success 'inspect pack4' '
	test-tool agit-inspect \
		--no-show-size --no-show-crc --no-show-offset --show-version \
		pack ".git/objects/pack/pack-${PK4}.pack" >actual &&
	test_cmp expect-${GIT_TEST_CRYPTO_ALGORITHM_TYPE} actual
'

test_expect_success 'git-fsck' '
	git fsck
'

test_expect_success NEED_GNU_DD 'create small binary file: blob-2m' '
	cat >blob-2m <<-\EOF &&
	blob-2m, which is smaller than 10MB (GIT_CRYPTO_ENCRYPT_LO_MAX_SIZE), will save to
	encrypted loose object.
	EOF
	if type openssl
	then
		openssl enc -aes-256-ctr \
			-pass pass:"$($DD if=/dev/urandom bs=128 count=1 2>/dev/null | base64)" \
			-nosalt < /dev/zero | $DD bs=1024 count=2050 >>blob-2m
	else
		$DD if=/dev/random bs=1024 count=2050 >>blob-2m
	fi
'

test_expect_success NEED_GNU_DD 'create commit with blob-2m' '
	git add blob-2m &&
	test_tick &&
	git commit -m blob-2m
'

test_expect_success NEED_GNU_DD 'create blob-5m, which larger than bigfilethreshold' '
	cat >blob-5m <<-\EOF &&
	blob-5m, which larger than core.bigfilethreshold, and will be streamed
	directly to packfile.
	EOF
	if type openssl
	then
		openssl enc -aes-256-ctr \
			-pass pass:"$($DD if=/dev/urandom bs=128 count=1 2>/dev/null | base64)" \
			-nosalt < /dev/zero | $DD bs=1024 count=5000 >>blob-5m
	else
		$DD if=/dev/random bs=1024 count=5000 >>blob-5m
	fi
'

test_expect_success NEED_GNU_DD 'create commit for blob-5m' '
	git add blob-5m &&
	test_tick &&
	git commit -m blob-5m
'

test_expect_success NEED_GNU_DD 'create one packfile with binary files' '
	git repack -Ad &&
	git prune --expire=now &&
	PK5=$(ls .git/objects/pack/*pack) &&
	PK5=${PK5#*pack-} &&
	PK5=${PK5%.pack}
'

cat >expect-1 <<-\EOF
Header: encrypt (1), version: 81000002
Number of objects: 27

[obj 1] type: commit
[obj 2] type: commit
[obj 3] type: commit
[obj 4] type: commit
[obj 5] type: commit
[obj 6] type: commit
[obj 7] type: commit
[obj 8] type: commit
[obj 9] type: commit
[obj 10] type: blob
[obj 11] type: ofs-delta
[obj 12] type: ofs-delta
[obj 13] type: ofs-delta
[obj 14] type: ofs-delta
[obj 15] type: ofs-delta
[obj 16] type: ofs-delta
[obj 17] type: blob
[obj 18] type: blob
[obj 19] type: tree
[obj 20] type: ofs-delta
[obj 21] type: ofs-delta
[obj 22] type: ofs-delta
[obj 23] type: ofs-delta
[obj 24] type: ofs-delta
[obj 25] type: ofs-delta
[obj 26] type: tree
[obj 27] type: tree

Checksum OK.
EOF

cat >expect-2 <<-\EOF
Header: encrypt (2), version: 82000002
Number of objects: 27

[obj 1] type: commit
[obj 2] type: commit
[obj 3] type: commit
[obj 4] type: commit
[obj 5] type: commit
[obj 6] type: commit
[obj 7] type: commit
[obj 8] type: commit
[obj 9] type: commit
[obj 10] type: blob
[obj 11] type: ofs-delta
[obj 12] type: ofs-delta
[obj 13] type: ofs-delta
[obj 14] type: ofs-delta
[obj 15] type: ofs-delta
[obj 16] type: ofs-delta
[obj 17] type: blob
[obj 18] type: blob
[obj 19] type: tree
[obj 20] type: ofs-delta
[obj 21] type: ofs-delta
[obj 22] type: ofs-delta
[obj 23] type: ofs-delta
[obj 24] type: ofs-delta
[obj 25] type: ofs-delta
[obj 26] type: tree
[obj 27] type: tree

Checksum OK.
EOF

cat >expect-64 <<-\EOF
Header: encrypt (40), version: c0617202
Number of objects: 27

[obj 1] type: commit
[obj 2] type: commit
[obj 3] type: commit
[obj 4] type: commit
[obj 5] type: commit
[obj 6] type: commit
[obj 7] type: commit
[obj 8] type: commit
[obj 9] type: commit
[obj 10] type: blob
[obj 11] type: ofs-delta
[obj 12] type: ofs-delta
[obj 13] type: ofs-delta
[obj 14] type: ofs-delta
[obj 15] type: ofs-delta
[obj 16] type: ofs-delta
[obj 17] type: blob
[obj 18] type: blob
[obj 19] type: tree
[obj 20] type: ofs-delta
[obj 21] type: ofs-delta
[obj 22] type: ofs-delta
[obj 23] type: ofs-delta
[obj 24] type: ofs-delta
[obj 25] type: ofs-delta
[obj 26] type: tree
[obj 27] type: tree

Checksum OK.
EOF

cat >expect-65 <<-\EOF
Header: encrypt (41), version: c1617202
Number of objects: 27

[obj 1] type: commit
[obj 2] type: commit
[obj 3] type: commit
[obj 4] type: commit
[obj 5] type: commit
[obj 6] type: commit
[obj 7] type: commit
[obj 8] type: commit
[obj 9] type: commit
[obj 10] type: blob
[obj 11] type: ofs-delta
[obj 12] type: ofs-delta
[obj 13] type: ofs-delta
[obj 14] type: ofs-delta
[obj 15] type: ofs-delta
[obj 16] type: ofs-delta
[obj 17] type: blob
[obj 18] type: blob
[obj 19] type: tree
[obj 20] type: ofs-delta
[obj 21] type: ofs-delta
[obj 22] type: ofs-delta
[obj 23] type: ofs-delta
[obj 24] type: ofs-delta
[obj 25] type: ofs-delta
[obj 26] type: tree
[obj 27] type: tree

Checksum OK.
EOF

test_expect_success NEED_GNU_DD 'inspect pack5' '
	test-tool agit-inspect \
		--no-show-size --no-show-crc --no-show-offset --show-version \
		pack ".git/objects/pack/pack-${PK5}.pack" >actual &&
	test_cmp expect-${GIT_TEST_CRYPTO_ALGORITHM_TYPE} actual
'

test_expect_success NEED_GNU_DD 'git-fsck' '
	git fsck
'
