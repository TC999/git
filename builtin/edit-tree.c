/*
 * GIT - the stupid content tracker
 *
 * Copyright (c) Jiang Xin, 2023
 */
#include "builtin.h"
#include "config.h"
#include "parse-options.h"

static const char *edit_tree_usage[] = {
	"git edit-tree [-z] [-f <input-file>] <tree-id>", NULL
};

int cmd_edit_tree(int argc, const char **argv, const char *prefix)
{
	const char *input = NULL;
	FILE *reader;
	struct strbuf sb = STRBUF_INIT;
	struct object_id oid;
	int nul_term_line = 0;
	strbuf_getline_fn getline_fn;

	const struct option edit_tree_options[] = {
		OPT_BOOL('z', NULL, &nul_term_line,
			 N_("input is NUL terminated")),
		OPT_FILENAME('f', "filename", &input, "read input from file"),
		OPT_END()
	};

	git_config(git_default_config, NULL);

	argc = parse_options(argc, argv, prefix, edit_tree_options,
			     edit_tree_usage, 0);
	getline_fn = nul_term_line ? strbuf_getline_nul : strbuf_getline_lf;

	if (argc < 1)
		usage_with_options(edit_tree_usage, edit_tree_options);

	if (get_oid(argv[0], &oid))
		die("Not a valid object name %s", argv[0]);

	if (input) {
		reader = fopen(input, "r");
		if (!reader)
			die_errno("fail to open %s", input);
	} else {
		reader = stdin;
	}

	while (getline_fn(&sb, reader) != EOF)
		printf("%s\n", sb.buf);

	if (reader != stdin)
		fclose(reader);

	strbuf_release(&sb);
	return 0;
}
